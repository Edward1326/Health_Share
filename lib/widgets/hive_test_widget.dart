import 'package:flutter/material.dart';
import 'package:your_app/services/hive_audit_service.dart';

class HiveTestWidget extends StatefulWidget {
  @override
  _HiveTestWidgetState createState() => _HiveTestWidgetState();
}

class _HiveTestWidgetState extends State<HiveTestWidget> {
  String _status = 'Ready to test';
  bool _testing = false;

  Future<void> _testHiveConnection() async {
    setState(() {
      _testing = true;
      _status = 'Testing connection...';
    });

    try {
      final connected = await HiveAuditService.testConnection();
      
      if (connected) {
        setState(() {
          _status = 'Connection successful! Testing upload log...';
        });

        final result = await HiveAuditService.logFileUpload(
          fileHash: 'test_hash_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'test_user_123',
          ipfsCid: 'QmTestCID123',
          fileType: 'test',
          recipientsCount: 1,
        );

        setState(() {
          _status = result['success'] 
            ? 'Test successful! Transaction: ${result['transactionId']}'
            : 'Test failed: ${result['error']}';
        });
      } else {
        setState(() {
          _status = 'Connection failed. Check backend server.';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_status, textAlign: TextAlign.center),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: _testing ? null : _testHiveConnection,
          child: Text(_testing ? 'Testing...' : 'Test Hive Integration'),
        ),
      ],
    );
  }
}