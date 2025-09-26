import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pointycastle/export.dart';
import 'package:bs58/bs58.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Derive Hive public key (STM...) from private WIF
String deriveHivePublicKey(String wif) {
  // Step 1: Base58Check decode WIF
  final decoded = base58.decode(wif);

  // First byte is version (0x80 for Bitcoin-style WIF)
  // Last 4 bytes are checksum
  final keyBytes = decoded.sublist(1, decoded.length - 4);

  // Remove compression flag if present (0x01 at end)
  late Uint8List privKeyBytes;
  if (keyBytes.length == 33 && keyBytes.last == 0x01) {
    privKeyBytes = Uint8List.fromList(keyBytes.sublist(0, 32));
  } else {
    privKeyBytes = Uint8List.fromList(keyBytes);
  }

  // Step 2: Derive public key point (secp256k1)
  final privNum = BigInt.parse(
    privKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );

  final domain = ECDomainParameters('secp256k1');
  final pubPoint = domain.G * privNum;

  // Encode compressed pubkey (33 bytes)
  final x = pubPoint!.x!.toBigInteger()!;
  final y = pubPoint.y!.toBigInteger()!;
  final prefix = (y.isEven ? 0x02 : 0x03);
  final xBytes = x.toRadixString(16).padLeft(64, '0');
  final pubKeyBytes = Uint8List.fromList([
    prefix,
    ...List<int>.generate(
      32,
      (i) => int.parse(xBytes.substring(i * 2, i * 2 + 2), radix: 16),
    ),
  ]);

  // Step 3: Hive public key encoding
  // -> ripemd160 checksum, take first 4 bytes
  final ripemd160 = RIPEMD160Digest();
  final hash = ripemd160.process(pubKeyBytes);
  final checksum = hash.sublist(0, 4);

  final hiveKey = base58.encode(
    Uint8List.fromList([...pubKeyBytes, ...checksum]),
  );

  return "STM$hiveKey";
}

/// Example Flutter widget with button
class HiveKeyChecker extends StatelessWidget {
  const HiveKeyChecker({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hive Key Checker")),
      body: Center(
        child: ElevatedButton(
          child: const Text("Check Public Key"),
          onPressed: () {
            try {
              // Get WIF posting key from environment variables
              final wifPostingKey = dotenv.env['HIVE_POSTING_WIF'];

              if (wifPostingKey == null || wifPostingKey.isEmpty) {
                throw Exception('HIVE_POSTING_WIF not found in .env file');
              }

              final pubKey = deriveHivePublicKey(wifPostingKey);

              // Print to console
              print("Public Key: $pubKey");
              print("Account Name: ${dotenv.env['HIVE_ACCOUNT_NAME']}");
              print("Node URL: ${dotenv.env['HIVE_NODE_URL']}");

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Public Key: $pubKey"),
                  duration: const Duration(seconds: 3),
                ),
              );
            } catch (e) {
              print("Error: $e");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Error: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
