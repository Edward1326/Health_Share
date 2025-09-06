import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cryptography/cryptography.dart' hide Hash;
import 'package:pointycastle/export.dart' hide Mac;
import 'package:asn1lib/asn1lib.dart';

class OrgFilesDecryptService {
  static final _supabase = Supabase.instance.client;
  static final _aesGcm = AesGcm.with256bits();

  /// Decrypt a file shared between doctor and patient using PointyCastle RSA
  static Future<Uint8List?> decryptSharedFile({
    required String fileId,
    required String ipfsCid,
    required String sharedBy,
    required String doctorId,
  }) async {
    try {
      print('=== ORG FILE DECRYPTION DEBUG ===');
      print('File ID: $fileId');
      print('IPFS CID: $ipfsCid');
      print('Shared by: $sharedBy');
      print('Doctor ID: $doctorId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No current user found');
      }

      // STEP 1: Download encrypted file from IPFS
      print('\n--- Step 1: Downloading from IPFS ---');
      final encryptedBytes = await _downloadFromIPFS(ipfsCid);
      if (encryptedBytes == null) {
        throw Exception('Failed to download file from IPFS');
      }
      print('✓ Downloaded ${encryptedBytes.length} bytes from IPFS');

      // STEP 2: Get current user's RSA private key
      print('\n--- Step 2: Getting user RSA key ---');
      final userData =
          await _supabase
              .from('User')
              .select('id, rsa_private_key, email')
              .eq('id', currentUser.id)
              .single();

      final rsaPrivateKeyPem = userData['rsa_private_key'] as String?;
      if (rsaPrivateKeyPem == null || rsaPrivateKeyPem.isEmpty) {
        throw Exception('User RSA private key is missing');
      }

      print('✓ Retrieved RSA private key for user: ${userData['email']}');

      // STEP 3: Get the encrypted AES key
      print('\n--- Step 3: Getting encrypted AES key ---');
      final fileKeyRecord =
          await _supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', currentUser.id)
              .maybeSingle();

      if (fileKeyRecord == null || fileKeyRecord['aes_key_encrypted'] == null) {
        throw Exception('No decryption key found for this file');
      }

      // STEP 4: Decrypt the file using PointyCastle RSA
      return _performDecryptionWithPointyCastle(
        encryptedBytes,
        fileKeyRecord['aes_key_encrypted'] as String,
        fileKeyRecord['nonce_hex'] as String?,
        rsaPrivateKeyPem,
      );
    } catch (e, stackTrace) {
      print('❌ Error in decryptSharedFile: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Alternative method that doesn't require knowing the sharing direction
  static Future<Uint8List?> decryptSharedFileSimple({
    required String fileId,
    required String ipfsCid,
  }) async {
    try {
      print('=== SIMPLE ORG FILE DECRYPTION ===');
      print('File ID: $fileId');
      print('IPFS CID: $ipfsCid');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No current user found');
      }

      // Download encrypted file
      final encryptedBytes = await _downloadFromIPFS(ipfsCid);
      if (encryptedBytes == null) {
        throw Exception('Failed to download file from IPFS');
      }

      // Get user's RSA private key
      final userData =
          await _supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', currentUser.id)
              .single();

      final rsaPrivateKeyPem = userData['rsa_private_key'] as String;

      // Try to get the encrypted AES key for current user
      final fileKeyRecords = await _supabase
          .from('File_Keys')
          .select('aes_key_encrypted, nonce_hex')
          .eq('file_id', fileId)
          .eq('recipient_type', 'user')
          .eq('recipient_id', currentUser.id);

      if (fileKeyRecords.isEmpty) {
        throw Exception('No decryption key found for this file');
      }

      // Use the first valid key found
      final fileKeyRecord = fileKeyRecords.first;

      return _performDecryptionWithPointyCastle(
        encryptedBytes,
        fileKeyRecord['aes_key_encrypted'] as String,
        fileKeyRecord['nonce_hex'] as String?,
        rsaPrivateKeyPem,
      );
    } catch (e, stackTrace) {
      print('❌ Error in decryptSharedFileSimple: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Perform the actual decryption using PointyCastle RSA and cryptography AES
  static Future<Uint8List?> _performDecryptionWithPointyCastle(
    Uint8List encryptedBytes,
    String encryptedKeyPackage,
    String? nonceHex,
    String rsaPrivateKeyPem,
  ) async {
    try {
      print('\n--- Performing decryption with PointyCastle RSA ---');

      // Parse the RSA private key using PointyCastle
      final rsaPrivateKey = _parseRSAPrivateKeyFromPem(rsaPrivateKeyPem);
      if (rsaPrivateKey == null) {
        throw Exception('Failed to parse RSA private key');
      }

      // Decrypt the AES key package using PointyCastle RSA-OAEP
      String? decryptedJson;
      try {
        // Try RSA-OAEP first (matching doctor's encryption method)
        decryptedJson = _decryptWithRSAOAEP(encryptedKeyPackage, rsaPrivateKey);
        print('✓ Successfully decrypted using PointyCastle RSA-OAEP');
      } catch (e) {
        print('PointyCastle RSA-OAEP decryption failed: $e');
        // Try PKCS1v15 as fallback
        try {
          decryptedJson = _decryptWithRSAPKCS1v15(
            encryptedKeyPackage,
            rsaPrivateKey,
          );
          print(
            '✓ Successfully decrypted using PointyCastle PKCS1v15 fallback',
          );
        } catch (fallbackError) {
          print(
            '❌ Both PointyCastle RSA decryption methods failed: $fallbackError',
          );
          return null;
        }
      }

      final keyData = jsonDecode(decryptedJson);
      final aesKeyBase64 = keyData['key'] as String;
      final nonceBase64 =
          keyData['nonce'] as String? ??
          (nonceHex != null
              ? base64Encode(
                List<int>.generate(
                  nonceHex.length ~/ 2,
                  (i) => int.parse(
                    nonceHex.substring(i * 2, i * 2 + 2),
                    radix: 16,
                  ),
                ),
              )
              : null);

      if (nonceBase64 == null) {
        throw Exception('Nonce not found in key data or database');
      }

      print('✓ Successfully decrypted AES key and nonce');

      // Convert from base64 to bytes
      final aesKeyBytes = base64Decode(aesKeyBase64);
      final nonceBytes = base64Decode(nonceBase64);

      print('AES key length: ${aesKeyBytes.length} bytes');
      print('Nonce length: ${nonceBytes.length} bytes');

      // Create SecretKey from bytes
      final aesKey = SecretKey(aesKeyBytes);

      // Decrypt file using AES-GCM with cryptography package
      final decryptedBytes = await _decryptFileData(
        encryptedBytes,
        nonceBytes,
        aesKey,
      );

      if (decryptedBytes == null) {
        print('❌ Failed to decrypt file data');
        return null;
      }

      print(
        '✓ Successfully decrypted file. Size: ${decryptedBytes.length} bytes',
      );
      return decryptedBytes;
    } catch (e) {
      print('Error in _performDecryptionWithPointyCastle: $e');
      return null;
    }
  }

  /// Parse RSA private key from PEM format using PointyCastle
  static RSAPrivateKey? _parseRSAPrivateKeyFromPem(String pem) {
    try {
      print('Parsing RSA private key from PEM using PointyCastle...');

      // Clean the PEM string
      final cleanPem = pem.trim();

      // Determine the format
      bool isPkcs1 = cleanPem.contains('-----BEGIN RSA PRIVATE KEY-----');
      bool isPkcs8 = cleanPem.contains('-----BEGIN PRIVATE KEY-----');

      if (!isPkcs1 && !isPkcs8) {
        throw FormatException('Invalid PEM format - missing proper headers');
      }

      String lines;
      if (isPkcs1) {
        print('Detected PKCS#1 format');
        lines =
            cleanPem
                .replaceAll('-----BEGIN RSA PRIVATE KEY-----', '')
                .replaceAll('-----END RSA PRIVATE KEY-----', '')
                .replaceAll('\n', '')
                .replaceAll('\r', '')
                .replaceAll(' ', '')
                .trim();
      } else {
        print('Detected PKCS#8 format');
        lines =
            cleanPem
                .replaceAll('-----BEGIN PRIVATE KEY-----', '')
                .replaceAll('-----END PRIVATE KEY-----', '')
                .replaceAll('\n', '')
                .replaceAll('\r', '')
                .replaceAll(' ', '')
                .trim();
      }

      if (lines.isEmpty) {
        throw FormatException('Empty key data after cleaning');
      }

      final keyBytes = base64Decode(lines);

      if (isPkcs1) {
        // PKCS#1 format - direct RSA key structure
        return _parseRSAPrivateKeyFromPKCS1(keyBytes);
      } else {
        // PKCS#8 format - wrapped in algorithm identifier
        return _parseRSAPrivateKeyFromPKCS8(keyBytes);
      }
    } catch (e) {
      print('Error parsing RSA private key from PEM: $e');
      return null;
    }
  }

  /// Parse PKCS#1 RSA private key
  static RSAPrivateKey _parseRSAPrivateKeyFromPKCS1(Uint8List keyBytes) {
    final asn1Parser = ASN1Parser(keyBytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    // PKCS#1 RSAPrivateKey structure:
    // RSAPrivateKey ::= SEQUENCE {
    //   version           Version,
    //   modulus           INTEGER,  -- n
    //   publicExponent    INTEGER,  -- e
    //   privateExponent   INTEGER,  -- d
    //   prime1            INTEGER,  -- p
    //   prime2            INTEGER,  -- q
    //   exponent1         INTEGER,  -- d mod (p-1)
    //   exponent2         INTEGER,  -- d mod (q-1)
    //   coefficient       INTEGER   -- (inverse of q) mod p
    // }

    final modulus = (topLevelSeq.elements[1] as ASN1Integer).valueAsBigInteger!;
    final publicExponent =
        (topLevelSeq.elements[2] as ASN1Integer).valueAsBigInteger!;
    final privateExponent =
        (topLevelSeq.elements[3] as ASN1Integer).valueAsBigInteger!;
    final p = (topLevelSeq.elements[4] as ASN1Integer).valueAsBigInteger!;
    final q = (topLevelSeq.elements[5] as ASN1Integer).valueAsBigInteger!;

    print('PKCS#1 RSA private key parsed - Modulus bits: ${modulus.bitLength}');
    return RSAPrivateKey(modulus, privateExponent, p, q);
  }

  /// Parse PKCS#8 RSA private key
  static RSAPrivateKey _parseRSAPrivateKeyFromPKCS8(Uint8List keyBytes) {
    final asn1Parser = ASN1Parser(keyBytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    // Extract the private key octet string
    final privateKeyOctetString = topLevelSeq.elements[2] as ASN1OctetString;
    final privateKeyBytes = privateKeyOctetString.contentBytes();

    // Parse the inner PKCS#1 structure
    return _parseRSAPrivateKeyFromPKCS1(privateKeyBytes);
  }

  /// Decrypt data using RSA-OAEP with PointyCastle
  static String _decryptWithRSAOAEP(
    String encryptedBase64,
    RSAPrivateKey privateKey,
  ) {
    try {
      print('Decrypting with PointyCastle RSA-OAEP...');

      final encryptedBytes = base64Decode(encryptedBase64);

      // Create OAEP decryptor with SHA-256 (matching doctor's encryption)
      final decryptor = OAEPEncoding(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      final decryptedBytes = decryptor.process(encryptedBytes);
      final decryptedString = utf8.decode(decryptedBytes);

      print('✓ RSA-OAEP decryption completed successfully');
      return decryptedString;
    } catch (e) {
      print('RSA-OAEP decryption error: $e');
      rethrow;
    }
  }

  /// Decrypt data using RSA PKCS1v15 with PointyCastle (fallback)
  static String _decryptWithRSAPKCS1v15(
    String encryptedBase64,
    RSAPrivateKey privateKey,
  ) {
    try {
      print('Decrypting with PointyCastle RSA PKCS1v15...');

      final encryptedBytes = base64Decode(encryptedBase64);

      // Create PKCS1v15 decryptor
      final decryptor = PKCS1Encoding(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      final decryptedBytes = decryptor.process(encryptedBytes);
      final decryptedString = utf8.decode(decryptedBytes);

      print('✓ RSA PKCS1v15 decryption completed successfully');
      return decryptedString;
    } catch (e) {
      print('RSA PKCS1v15 decryption error: $e');
      rethrow;
    }
  }

  /// Decrypt file data using AES-GCM with cryptography package
  static Future<Uint8List?> _decryptFileData(
    Uint8List combinedData, // Contains both ciphertext and MAC
    List<int> nonce,
    SecretKey aesKey,
  ) async {
    try {
      print(
        'Attempting to decrypt ${combinedData.length} bytes of combined data',
      );

      // Check if we have enough data (at least 16 bytes for MAC)
      if (combinedData.length < 16) {
        print(
          'Error: Combined data too short, must be at least 16 bytes for MAC',
        );
        return null;
      }

      // Separate ciphertext and MAC
      // Format from doctor's upload: [ciphertext][16-byte MAC]
      final cipherText = combinedData.sublist(0, combinedData.length - 16);
      final macBytes = combinedData.sublist(combinedData.length - 16);

      print(
        'Separated ciphertext: ${cipherText.length} bytes, MAC: ${macBytes.length} bytes',
      );

      // Create SecretBox with proper MAC
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

      final decryptedData = await _aesGcm.decrypt(secretBox, secretKey: aesKey);

      return Uint8List.fromList(decryptedData);
    } catch (e) {
      print('AES-GCM decryption failed: $e');

      // Try alternative approaches for backward compatibility
      return await _tryAlternativeDecryption(combinedData, nonce, aesKey);
    }
  }

  /// Try alternative decryption methods for backward compatibility
  static Future<Uint8List?> _tryAlternativeDecryption(
    Uint8List encryptedData,
    List<int> nonce,
    SecretKey aesKey,
  ) async {
    print('Trying alternative decryption methods...');

    // Method 1: Try with Mac.empty (for old data without proper MAC storage)
    try {
      print('Attempting decryption with Mac.empty');
      final secretBox = SecretBox(encryptedData, nonce: nonce, mac: Mac.empty);

      final decryptedData = await _aesGcm.decrypt(secretBox, secretKey: aesKey);
      print('✅ Success with Mac.empty method');
      return Uint8List.fromList(decryptedData);
    } catch (e) {
      print('Mac.empty method failed: $e');
    }

    // Method 2: Try assuming MAC is at the beginning (alternative format)
    try {
      if (encryptedData.length > 16) {
        print('Attempting decryption with MAC at beginning');
        final macBytes = encryptedData.sublist(0, 16);
        final cipherText = encryptedData.sublist(16);

        final secretBox = SecretBox(
          cipherText,
          nonce: nonce,
          mac: Mac(macBytes),
        );

        final decryptedData = await _aesGcm.decrypt(
          secretBox,
          secretKey: aesKey,
        );
        print('✅ Success with MAC-at-beginning method');
        return Uint8List.fromList(decryptedData);
      }
    } catch (e) {
      print('MAC-at-beginning method failed: $e');
    }

    print('❌ All decryption methods failed');
    return null;
  }

  /// Download file from IPFS
  static Future<Uint8List?> _downloadFromIPFS(String cid) async {
    try {
      print('Downloading from IPFS: https://gateway.pinata.cloud/ipfs/$cid');
      final response = await http.get(
        Uri.parse('https://gateway.pinata.cloud/ipfs/$cid'),
        headers: {'Accept': '*/*'},
      );

      if (response.statusCode == 200) {
        print('✓ Downloaded ${response.bodyBytes.length} bytes from IPFS');
        return response.bodyBytes;
      } else {
        print('Failed to fetch from IPFS: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading from IPFS: $e');
      return null;
    }
  }

  /// Verify if user has access to decrypt a file
  static Future<bool> canDecryptFile({
    required String fileId,
    required String userId,
  }) async {
    try {
      final keyCheck =
          await _supabase
              .from('File_Keys')
              .select('id')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', userId)
              .maybeSingle();

      return keyCheck != null;
    } catch (e) {
      print('Error checking file access: $e');
      return false;
    }
  }

  /// Get file metadata including IPFS CID
  static Future<Map<String, dynamic>?> getFileMetadata(String fileId) async {
    try {
      final fileData =
          await _supabase
              .from('Files')
              .select(
                'id, filename, file_type, file_size, ipfs_cid, sha256_hash',
              )
              .eq('id', fileId)
              .maybeSingle();

      return fileData;
    } catch (e) {
      print('Error fetching file metadata: $e');
      return null;
    }
  }
}
