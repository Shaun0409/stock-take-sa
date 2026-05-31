import 'package:flutter/material.dart';
import '../models/store.dart';
import '../models/stock_take.dart';
import '../services/database_service.dart';

class StockTakeHistoryScreen extends StatefulWidget {
  final Store store;
  
  const StockTakeHistoryScreen({super.key, required this.store});

  @override
  State<StockTakeHistoryScreen> createState() => _StockTakeHistoryScreenState();
}

class _StockTakeHistoryScreenState extends State<StockTakeHistoryScreen> {
  final DatabaseService _db = DatabaseService();
  List<StockTake> _stockTakes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final stockTakes = await _db.getStockTakes(storeId: widget.store.id);
    setState(() {
      _stockTakes = stockTakes.where((st) => st.status == 'completed').toList();
      _isLoading = false;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stock Take History - ${widget.store.storeName}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stockTakes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No stock take history yet'),
                      SizedBox(height: 8),
                      Text('Complete a stock take to see it here'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _stockTakes.length,
                  itemBuilder: (context, index) {
                    final st = _stockTakes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: const Icon(Icons.inventory, color: Colors.green),
                        ),
                        title: Text('Stock Take on ${_formatDate(st.stockTakeDate)}'),
                        subtitle: Text('Completed • ${st.notes ?? 'No notes'}'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
    );
  }
}