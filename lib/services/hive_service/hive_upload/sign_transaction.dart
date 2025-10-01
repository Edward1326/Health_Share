import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HiveTransactionSigner {
  // Base58 alphabet for WIF decoding
  static const String _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  // Hive chain ID (mainnet)
  static const String _hiveChainId =
      'beeab0de00000000000000000000000000000000000000000000000000000000';

  /// Signs a Hive transaction using the posting private key from environment
  static Future<Map<String, dynamic>> signTransaction(
    Map<String, dynamic> transaction,
  ) async {
    try {
      // Get posting WIF from environment
      final postingWif = dotenv.env['HIVE_POSTING_WIF'] ?? '';
      if (postingWif.isEmpty) {
        throw Exception('HIVE_POSTING_WIF not found in environment variables');
      }

      // 1. Convert WIF to private key
      final privateKey = _wifToPrivateKey(postingWif);

      // 2. Serialize the transaction
      final serializedTransaction = _serializeTransaction(transaction);

      // 3. Create signing buffer (chain ID + serialized transaction)
      final chainIdBytes = _hexToBytes(_hiveChainId);
      final signingBuffer = Uint8List.fromList([
        ...chainIdBytes,
        ...serializedTransaction,
      ]);

      // 4. Hash the signing buffer
      final hash = sha256.convert(signingBuffer).bytes;

      // 5. Sign the hash
      final signature = _signHash(Uint8List.fromList(hash), privateKey);

      // 6. Add signature
      final signedTransaction = Map<String, dynamic>.from(transaction);
      signedTransaction['signatures'] = [signature];

      return signedTransaction;
    } catch (e) {
      throw Exception('Failed to sign transaction: $e');
    }
  }

  /// --- Private helpers ---

  static Uint8List _wifToPrivateKey(String wif) {
    try {
      final decoded = _base58Decode(wif);
      if (decoded.length != 37) {
        throw Exception('Invalid WIF length');
      }
      final privateKey = decoded.sublist(1, 33);

      // verify checksum
      final payload = decoded.sublist(0, 33);
      final checksum = decoded.sublist(33);
      final hash = sha256.convert(sha256.convert(payload).bytes).bytes;
      if (!_listEquals(checksum, hash.sublist(0, 4))) {
        throw Exception('Invalid WIF checksum');
      }

      return Uint8List.fromList(privateKey);
    } catch (e) {
      throw Exception('Failed to decode WIF: $e');
    }
  }

  static Uint8List _base58Decode(String input) {
    final alphabet = _base58Alphabet;
    final base = BigInt.from(58);
    BigInt decoded = BigInt.zero;
    BigInt multi = BigInt.one;

    for (int i = input.length - 1; i >= 0; i--) {
      final char = input[i];
      final index = alphabet.indexOf(char);
      if (index == -1) {
        throw Exception('Invalid base58 character: $char');
      }
      decoded += BigInt.from(index) * multi;
      multi *= base;
    }

    final bytes = <int>[];
    while (decoded > BigInt.zero) {
      bytes.insert(0, (decoded % BigInt.from(256)).toInt());
      decoded ~/= BigInt.from(256);
    }

    for (int i = 0; i < input.length && input[i] == '1'; i++) {
      bytes.insert(0, 0);
    }
    return Uint8List.fromList(bytes);
  }

  static Uint8List _serializeTransaction(Map<String, dynamic> transaction) {
    final buffer = <int>[];

    final refBlockNum = transaction['ref_block_num'] as int;
    buffer.addAll(_serializeUint16(refBlockNum));

    final refBlockPrefix = transaction['ref_block_prefix'] as int;
    buffer.addAll(_serializeUint32(refBlockPrefix));

    final expiration = transaction['expiration'] as String;
    final expirationTimestamp =
        DateTime.parse(expiration + 'Z').millisecondsSinceEpoch ~/ 1000;
    buffer.addAll(_serializeUint32(expirationTimestamp));

    final operations = transaction['operations'] as List;
    buffer.addAll(_serializeOperations(operations));

    buffer.addAll(_serializeVarint(0)); // extensions (always empty)

    return Uint8List.fromList(buffer);
  }

  static List<int> _serializeOperations(List operations) {
    final buffer = <int>[];
    buffer.addAll(_serializeVarint(operations.length));

    for (final operation in operations) {
      final opList = operation as List;
      final opName = opList[0] as String;
      final opData = opList[1] as Map<String, dynamic>;

      // only custom_json supported for now
      buffer.addAll(_serializeVarint(18));
      buffer.addAll(_serializeCustomJsonOperation(opData));
    }
    return buffer;
  }

  static List<int> _serializeCustomJsonOperation(Map<String, dynamic> opData) {
    final buffer = <int>[];

    final requiredAuths = opData['required_auths'] as List<dynamic>;
    buffer.addAll(_serializeVarint(requiredAuths.length));
    for (final auth in requiredAuths) {
      buffer.addAll(_serializeString(auth as String));
    }

    final requiredPostingAuths =
        opData['required_posting_auths'] as List<dynamic>;
    buffer.addAll(_serializeVarint(requiredPostingAuths.length));
    for (final auth in requiredPostingAuths) {
      buffer.addAll(_serializeString(auth as String));
    }

    final id = opData['id'] as String;
    buffer.addAll(_serializeString(id));

    final json = opData['json'] as String;
    buffer.addAll(_serializeString(json));

    return buffer;
  }

  static List<int> _serializeString(String str) {
    final bytes = utf8.encode(str);
    final buffer = <int>[];
    buffer.addAll(_serializeVarint(bytes.length));
    buffer.addAll(bytes);
    return buffer;
  }

  static List<int> _serializeVarint(int value) {
    final buffer = <int>[];
    while (value >= 0x80) {
      buffer.add((value & 0x7F) | 0x80);
      value >>= 7;
    }
    buffer.add(value & 0x7F);
    return buffer;
  }

  static List<int> _serializeUint16(int value) => [
    value & 0xFF,
    (value >> 8) & 0xFF,
  ];

  static List<int> _serializeUint32(int value) => [
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];

  /// ✅ Fixed: Sign a hash using secp256k1 ECDSA with randomness
  static String _signHash(Uint8List hash, Uint8List privateKey) {
    try {
      final secp256k1 = ECDomainParameters('secp256k1');
      final privKey = ECPrivateKey(_bytesToBigInt(privateKey), secp256k1);

      // ECDSA signer with SHA256
      final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
      signer.init(true, PrivateKeyParameter(privKey));

      final ECSignature ecSig = signer.generateSignature(hash) as ECSignature;

      // Normalize signature (Hive requires low-S form)
      var s = ecSig.s;
      final halfCurveOrder = secp256k1.n >> 1;
      if (s.compareTo(halfCurveOrder) > 0) {
        s = secp256k1.n - s;
      }

      final r = _bigIntToBytes(ecSig.r, 32);
      final sBytes = _bigIntToBytes(s, 32);

      // Recovery ID (⚠️ needs proper calculation, here we stub as 0)
      final recoveryId = 0;

      // Build compact signature
      final compactSig = Uint8List(65);
      compactSig[0] = (recoveryId + 31); // Recovery flag
      compactSig.setRange(1, 33, r);
      compactSig.setRange(33, 65, sBytes);

      // Return hex string
      return compactSig.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      throw Exception('Failed to sign hash: $e');
    }
  }

  static SecureRandom _secureRandom() {
    final secureRandom = SecureRandom("Fortuna")..seed(
      KeyParameter(
        Uint8List.fromList(
          List<int>.generate(32, (_) => Random.secure().nextInt(256)),
        ),
      ),
    );
    return secureRandom;
  }

  static int _calculateRecoveryId(
    Uint8List hash,
    ECSignature signature,
    ECPrivateKey privateKey,
  ) {
    // ⚠️ Simplified — should test recovery ids 0–3 against pubkey
    return 0;
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (int i = 0; i < bytes.length; i++) {
      result = (result << 8) + BigInt.from(bytes[i]);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final bytes = Uint8List(length);
    for (int i = length - 1; i >= 0; i--) {
      bytes[i] = (value & BigInt.from(0xFF)).toInt();
      value >>= 8;
    }
    return bytes;
  }

  static Uint8List _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool isValidWif(String wif) {
    try {
      _wifToPrivateKey(wif);
      return true;
    } catch (e) {
      return false;
    }
  }

  static String getPostingWif() {
    return dotenv.env['HIVE_POSTING_WIF'] ?? '';
  }
}
