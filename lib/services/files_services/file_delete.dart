import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/hive_service/hive_upload/broadcast_transaction.dart';
import 'package:health_share/services/hive_service/hive_upload/create_custom_json.dart';
import 'package:health_share/services/hive_service/hive_upload/create_transaction.dart';
import 'package:health_share/services/hive_service/hive_upload/sign_transaction.dart';

/// Service for handling file deletion with crypto-erasure and blockchain logging
///
/// This service implements a secure deletion strategy:
/// 1. Deletes the AES encryption key (crypto-erasure)
/// 2. Soft-deletes the file record (preserves audit trail)
/// 3. Logs the deletion to Hive blockchain
/// 4. Keeps encrypted data in IPFS (undecryptable without key)
class FileDeleteService {
  /// Deletes a file using crypto-erasure strategy
  ///
  /// This method:
  /// - Removes the AES key from File_Keys (making file undecryptable)
  /// - Marks the file as deleted in Files table (soft delete)
  /// - Logs the deletion to Hive blockchain for audit trail
  /// - Does NOT remove encrypted data from IPFS
  ///
  /// Returns true if successful, false otherwise
  static Future<bool> deleteFile({
    required String fileId,
    required String fileName,
    required String fileHash,
    required String userId,
    required BuildContext context,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final timestamp = DateTime.now();

      print('Starting file deletion process for fileId: $fileId');

      // 🔐 STEP 1: Delete AES key (crypto-erasure)
      // This makes the encrypted file in IPFS permanently undecryptable
      print('Deleting AES key from File_Keys...');
      await supabase.from('File_Keys').delete().eq('file_id', fileId);
      print('✓ AES key deleted (crypto-erasure complete)');
      // 🛑 STEP 1.5: Revoke all shares
      await supabase
          .from('File_Shares')
          .update({'revoked_at': timestamp.toIso8601String()})
          .eq('file_id', fileId);
      // 📝 STEP 2: Soft delete file record
      // We keep the record for audit purposes but mark it as deleted
      print('Marking file as deleted in Files table...');
      await supabase
          .from('Files')
          .update({'deleted_at': timestamp.toIso8601String()})
          .eq('id', fileId);
      print('✓ File marked as deleted');

      // 🔗 STEP 3: Log deletion to Hive blockchain
      print('Logging deletion to Hive blockchain...');
      final hiveResult = await _logDeletionToHiveBlockchain(
        fileName: fileName,
        fileHash: fileHash,
        fileId: fileId,
        userId: userId,
        timestamp: timestamp,
        context: context,
      );

      // Show appropriate success message
      if (context.mounted) {
        final message =
            hiveResult.success
                ? 'File deleted successfully and logged to blockchain!'
                : 'File deleted successfully! (Blockchain logging failed - check logs)';

        final backgroundColor =
            hiveResult.success ? Colors.green : Colors.orange;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      return true;
    } catch (e, stackTrace) {
      print('Error deleting file: $e');
      print('Stack trace: $stackTrace');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting file: $e'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      return false;
    }
  }

  /// 🔗 Logs file deletion to Hive blockchain
  ///
  /// This follows the same workflow as upload logging but with action='delete'
  /// Workflow: CustomJSON → Transaction → Sign → Broadcast → Database Log
  static Future<HiveLogResult> _logDeletionToHiveBlockchain({
    required String fileName,
    required String fileHash,
    required String fileId,
    required String userId,
    required DateTime timestamp,
    required BuildContext context,
  }) async {
    try {
      // Check if Hive is configured
      if (!HiveCustomJsonService.isHiveConfigured()) {
        print('Warning: Hive not configured (HIVE_ACCOUNT_NAME missing)');
        return HiveLogResult(success: false, error: 'Hive not configured');
      }

      print('Starting Hive blockchain logging for deletion...');

      // 🔗 STEP 1: Create custom JSON using HiveCustomJsonService
      final customJsonResult = HiveCustomJsonService.createMedicalLogCustomJson(
        fileName: fileName,
        fileHash: fileHash,
        timestamp: timestamp,
      );
      final customJsonOperation =
          customJsonResult['operation'] as List<dynamic>;
      print('✓ Custom JSON created for deletion');

      // 🔗 STEP 2: Create unsigned transaction using HiveTransactionService
      final unsignedTransaction =
          await HiveTransactionService.createCustomJsonTransaction(
            customJsonOperation: customJsonOperation,
            expirationMinutes: 30,
          );
      print('✓ Unsigned transaction created');

      // 🔗 STEP 3: Sign transaction using HiveTransactionSigner
      final signedTransaction = await HiveTransactionSigner.signTransaction(
        unsignedTransaction,
      );
      print('✓ Transaction signed');

      // 🔗 STEP 4: Broadcast transaction using HiveTransactionBroadcaster
      final broadcastResult =
          await HiveTransactionBroadcaster.broadcastTransaction(
            signedTransaction,
          );

      if (broadcastResult.success) {
        print('✓ Deletion transaction broadcasted successfully!');
        print('  Transaction ID: ${broadcastResult.getTxId()}');
        print('  Block Number: ${broadcastResult.getBlockNum()}');

        // 🔗 STEP 5: Insert into Hive_Logs table with action='delete'
        final logSuccess = await _insertHiveDeletionLog(
          transactionId: broadcastResult.getTxId() ?? '',
          action: 'delete',
          userId: userId,
          fileId: fileId,
          fileName: fileName,
          fileHash: fileHash,
          timestamp: timestamp,
        );

        if (logSuccess) {
          print('✓ Hive deletion log inserted into database');
          return HiveLogResult(
            success: true,
            transactionId: broadcastResult.getTxId(),
            blockNum: broadcastResult.getBlockNum(),
          );
        } else {
          print('✗ Failed to insert Hive log into database');
          return HiveLogResult(
            success: false,
            error:
                'Transaction broadcast succeeded but database logging failed',
          );
        }
      } else {
        print(
          '✗ Failed to broadcast transaction: ${broadcastResult.getError()}',
        );
        return HiveLogResult(success: false, error: broadcastResult.getError());
      }
    } catch (e, stackTrace) {
      print('Error logging deletion to Hive blockchain: $e');
      print('Stack trace: $stackTrace');
      return HiveLogResult(success: false, error: e.toString());
    }
  }

  /// Insert a deletion record into the Hive_Logs table
  static Future<bool> _insertHiveDeletionLog({
    required String transactionId,
    required String action,
    required String userId,
    required String fileId,
    required String fileName,
    required String fileHash,
    required DateTime timestamp,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      final insertData = {
        'trx_id': transactionId,
        'action': action, // 'delete'
        'user_id': userId,
        'file_id': fileId,
        'timestamp': timestamp.toIso8601String(),
        'file_name': fileName,
        'file_hash': fileHash,
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('Hive_Logs').insert(insertData);
      print('Hive deletion log inserted successfully');
      return true;
    } catch (e, stackTrace) {
      print('Error inserting Hive deletion log: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Delete multiple files at once
  ///
  /// Useful for batch deletions from the UI
  static Future<Map<String, dynamic>> deleteMultipleFiles({
    required List<Map<String, String>>
    files, // List of {fileId, fileName, fileHash}
    required String userId,
    required BuildContext context,
  }) async {
    int successCount = 0;
    int failureCount = 0;
    final List<String> failedFiles = [];

    for (final file in files) {
      final success = await deleteFile(
        fileId: file['fileId']!,
        fileName: file['fileName']!,
        fileHash: file['fileHash']!,
        userId: userId,
        context: context,
      );

      if (success) {
        successCount++;
      } else {
        failureCount++;
        failedFiles.add(file['fileName']!);
      }
    }

    return {
      'successCount': successCount,
      'failureCount': failureCount,
      'failedFiles': failedFiles,
    };
  }
}

/// Result class for Hive logging operations (reused from upload service)
class HiveLogResult {
  final bool success;
  final String? error;
  final String? transactionId;
  final int? blockNum;

  HiveLogResult({
    required this.success,
    this.error,
    this.transactionId,
    this.blockNum,
  });

  @override
  String toString() {
    if (success) {
      return 'HiveLogResult(success: true, txId: $transactionId, block: $blockNum)';
    } else {
      return 'HiveLogResult(success: false, error: $error)';
    }
  }
}
