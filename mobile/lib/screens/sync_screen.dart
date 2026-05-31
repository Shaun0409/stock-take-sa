import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isSyncing = false;
  String _syncStatus = 'Ready to sync';
  int _syncedCount = 0;
  int _totalCount = 0;

  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Checking for unsynced data...';
    });

    try {
      // Simulate sync for now
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _syncStatus = 'Sync complete! All data is up to date.';
        _isSyncing = false;
        _syncedCount = 1;
        _totalCount = 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync completed successfully!')),
      );
    } catch (e) {
      setState(() {
        _syncStatus = 'Sync failed: $e';
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Data'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSyncing ? Icons.sync : Icons.cloud_upload,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              _isSyncing ? 'Syncing...' : 'Sync to Cloud',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              _syncStatus,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_isSyncing && _totalCount > 0) ...[
              const SizedBox(height: 24),
              LinearProgressIndicator(value: _syncedCount / _totalCount),
              const SizedBox(height: 8),
              Text('$_syncedCount / $_totalCount'),
            ],
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _syncData,
                icon: Icon(
                    _isSyncing ? Icons.hourglass_empty : Icons.cloud_upload),
                label: Text(_isSyncing ? 'Syncing...' : 'Start Sync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Stores'),
            ),
          ],
        ),
      ),
    );
  }
}
