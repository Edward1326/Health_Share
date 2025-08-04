import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

class AESHelper {
  final Key key;
  final IV iv;

  // Fix: Accept hex strings and convert them properly
  AESHelper(String keyHex, String ivHex)
    : key = Key.fromBase16(keyHex), // Use fromBase16 for hex strings
      iv = IV.fromBase16(ivHex); // Use fromBase16 for hex strings

  Uint8List encryptData(Uint8List data) {
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    return encrypted.bytes;
  }

  Uint8List decryptData(Uint8List encryptedData) {
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(Encrypted(encryptedData), iv: iv);
    return Uint8List.fromList(decrypted);
  }
}
