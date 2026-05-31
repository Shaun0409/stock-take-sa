import 'package:flutter/material.dart';
import '../../models/store.dart';

class InvoiceListScreen extends StatelessWidget {
  final Store store;
  
  const InvoiceListScreen({super.key, required this.store});

  void _showInvoiceDialog(BuildContext context, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action Invoice'),
        content: Text('$action invoice for ${store.storeName}...\n\nThis feature is coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.store, size: 48, color: Colors.purple),
                    const SizedBox(height: 8),
                    Text(
                      store.storeName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Invoices & Billing',
                      style: TextStyle(color: Colors.purple.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Icon(Icons.receipt, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Invoices',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showInvoiceDialog(context, 'Create New'),
                icon: const Icon(Icons.add),
                label: const Text('Create New Invoice'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showInvoiceDialog(context, 'View'),
                icon: const Icon(Icons.history),
                label: const Text('View Invoice History'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showInvoiceDialog(context, 'Email'),
                icon: const Icon(Icons.email),
                label: const Text('Email Invoice'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}