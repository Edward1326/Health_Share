import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

class AESHelper {
  final Key key;
  final IV nonce; // In GCM mode, nonce is used as IV

  // Accept hex strings and convert them properly
  AESHelper(String keyHex, String nonceHex)
    : key = Key.fromBase16(keyHex),
      nonce = IV.fromBase16(nonceHex) {
    print('AESHelper initialized:');
    print('  Key hex length: ${keyHex.length}');
    print('  Nonce hex length: ${nonceHex.length}');
    print('  Key bytes length: ${key.bytes.length}');
    print('  Nonce bytes length: ${nonce.bytes.length}');
  }

  Uint8List encryptData(Uint8List data) {
    try {
      print('Encrypting data:');
      print('  Input size: ${data.length} bytes');

      final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
      final encrypted = encrypter.encryptBytes(data, iv: nonce);

      print('  Encrypted size: ${encrypted.bytes.length} bytes');
      return encrypted.bytes;
    } catch (e) {
      print('Encryption error: $e');
      rethrow;
    }
  }

  Uint8List decryptData(Uint8List encryptedData) {
    try {
      print('Decrypting data:');
      print('  Encrypted size: ${encryptedData.length} bytes');

      final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
      final decrypted = encrypter.decryptBytes(
        Encrypted(encryptedData),
        iv: nonce,
      );

      final result = Uint8List.fromList(decrypted);
      print('  Decrypted size: ${result.length} bytes');

      // Check if result looks valid (not all zeros)
      final nonZeroBytes = result.where((b) => b != 0).length;
      print('  Non-zero bytes: $nonZeroBytes/${result.length}');

      // Sample first few bytes for debugging
      if (result.length > 0) {
        final sample = result
            .take(20)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        print('  First 20 bytes (hex): $sample');
      }

      return result;
    } catch (e) {
      print('Decryption error: $e');
      rethrow;
    }
  }
}
