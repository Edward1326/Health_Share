import 'dart:convert';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart' as basic;
import 'package:pointycastle/export.dart';

class MyCryptoUtils {
  /// Convert PEM public key to RSAPublicKey
  static RSAPublicKey rsaPublicKeyFromPem(String pem) {
    return basic.CryptoUtils.rsaPublicKeyFromPem(pem);
  }

  /// Convert PEM private key to RSAPrivateKey
  static RSAPrivateKey rsaPrivateKeyFromPem(String pem) {
    return basic.CryptoUtils.rsaPrivateKeyFromPem(pem);
  }

  /// Encrypts [plaintext] using RSA public key.
  /// Returns a Base64-encoded string.
  static String rsaEncrypt(String plaintext, RSAPublicKey publicKey) {
    final engine =
        RSAEngine()..init(
          true, // true = encryption
          PublicKeyParameter<RSAPublicKey>(publicKey),
        );

    final Uint8List input = Uint8List.fromList(utf8.encode(plaintext));
    final Uint8List encrypted = _processInBlocks(engine, input);

    return base64Encode(encrypted);
  }

  /// Decrypts a Base64-encoded string using RSA private key.
  /// Returns the original plaintext string.
  static String rsaDecrypt(String base64Ciphertext, RSAPrivateKey privateKey) {
    final engine =
        RSAEngine()..init(
          false, // false = decryption
          PrivateKeyParameter<RSAPrivateKey>(privateKey),
        );

    final Uint8List encrypted = base64Decode(base64Ciphertext);
    final Uint8List decrypted = _processInBlocks(engine, encrypted);

    return utf8.decode(decrypted);
  }

  /// Helper to handle RSA encryption/decryption in chunks
  static Uint8List _processInBlocks(RSAEngine engine, Uint8List input) {
    final numBlocks = (input.length / engine.inputBlockSize).ceil();
    final output = <int>[];

    for (var i = 0; i < numBlocks; i++) {
      final start = i * engine.inputBlockSize;
      final end =
          (start + engine.inputBlockSize < input.length)
              ? start + engine.inputBlockSize
              : input.length;
      final block = input.sublist(start, end);

      final processed = engine.process(block);
      output.addAll(processed);
    }

    return Uint8List.fromList(output);
  }
}
