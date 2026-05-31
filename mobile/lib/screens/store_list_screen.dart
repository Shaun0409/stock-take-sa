import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/store.dart';
import 'store_dashboard_screen.dart';
import 'add_store_screen.dart';
import 'sync_screen.dart';

class StoreListScreen extends StatefulWidget {
  const StoreListScreen({super.key});

  @override
  State<StoreListScreen> createState() => _StoreListScreenState();
}

class _StoreListScreenState extends State<StoreListScreen> {
  final DatabaseService _db = DatabaseService();
  List<Store> _stores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoading = true);
    try {
      final stores = await _db.getStores();
      setState(() {
        _stores = stores;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading stores: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stores'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SyncScreen()),
              );
            },
            tooltip: 'Sync to Cloud',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStores,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No stores found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap the + button to add your first store',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStores,
                  child: ListView.builder(
                    itemCount: _stores.length,
                    itemBuilder: (context, index) {
                      final store = _stores[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            radius: 25,
                            child: const Icon(
                              Icons.store,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            store.storeName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (store.ownerName != null)
                                Text(
                                  'Owner: ${store.ownerName}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              if (store.suburb != null)
                                Text(
                                  store.suburb!,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                          trailing: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StoreDashboardScreen(store: store),
                                ),
                              );
                            },
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: const Text('Open'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          isThreeLine: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddStoreScreen()),
          );
          if (result == true) {
            _loadStores();
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Add New Store',
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}