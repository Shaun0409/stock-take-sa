import 'package:flutter/material.dart';
import '../models/store.dart';
import '../services/database_service.dart';
import '../models/product.dart';
import '../models/stock_take.dart';
import '../models/stock_take_item.dart';
import 'barcode_scanner_screen.dart';

class StockTakeScreen extends StatefulWidget {
  final Store store;

  const StockTakeScreen({super.key, required this.store});

  @override
  State<StockTakeScreen> createState() => _StockTakeScreenState();
}

class _StockTakeScreenState extends State<StockTakeScreen> {
  final DatabaseService _db = DatabaseService();
  late StockTake _currentStockTake;
  List<Product> _products = [];
  List<StockTakeItem> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _initializeStockTake();
  }

  Future<void> _initializeStockTake() async {
    setState(() => _isLoading = true);

    try {
      _currentStockTake = StockTake(
        storeId: widget.store.id!,
        stockTakeDate: DateTime.now(),
        startTime: DateTime.now(),
        status: 'in_progress',
        isOffline: true,
      );

      final id = await _db.createStockTake(_currentStockTake);
      _currentStockTake.id = id;

      await _loadCategories();
      await _loadProducts();

      _items = await _db.getStockTakeItems(_currentStockTake.id!);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing stock take: $e')),
      );
    }
  }

  Future<void> _loadCategories() async {
    final cats = await _db.getCategories();
    setState(() {
      _categories = ['All', ...cats];
    });
  }

  Future<void> _loadProducts() async {
    _products = await _db.getProducts(
      category: _selectedCategory == 'All' ? null : _selectedCategory,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );
    setState(() {});
  }

  Future<void> _addOrUpdateItem(Product product, double quantity) async {
    if (quantity < 0) quantity = 0;

    var existingItem = _items.firstWhere(
      (item) => item.productId == product.id,
      orElse: () => StockTakeItem(
        stockTakeId: _currentStockTake.id!,
        productId: product.id!,
        countedQuantity: 0,
        costPriceAtTime: product.defaultCostPrice,
        sellingPriceAtTime: product.defaultSellingPrice,
      ),
    );

    final updatedItem = StockTakeItem(
      id: existingItem.id,
      stockTakeId: _currentStockTake.id!,
      productId: product.id!,
      countedQuantity: quantity,
      costPriceAtTime: product.defaultCostPrice,
      sellingPriceAtTime: product.defaultSellingPrice,
      isSpoiled: existingItem.isSpoiled,
      notes: existingItem.notes,
    );

    await _db.saveStockTakeItem(updatedItem);
    _items = await _db.getStockTakeItems(_currentStockTake.id!);
    setState(() {});
  }

  Future<void> _completeStockTake() async {
    final summary = await _db.getStockTakeSummary(_currentStockTake.id!);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stock Take Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Store: ${widget.store.storeName}'),
            const Divider(),
            Text('Total Items Counted: ${summary['total_items']}'),
            const SizedBox(height: 8),
            Text('Unique Products: ${summary['unique_products']}'),
            const SizedBox(height: 8),
            Text(
                'Total Value (Cost): R${summary['total_cost_value'].toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(
                'Total Value (Selling): R${summary['total_selling_value'].toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(
                'Potential Profit: R${summary['potential_profit'].toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Counting'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _db.updateStockTakeStatus(
                  _currentStockTake.id!, 'completed',
                  endTime: DateTime.now());
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Stock take completed successfully!')),
                );
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showShrinkageReport() async {
    final endDate = DateTime.now();
    final startDate = DateTime(endDate.year, endDate.month - 1, endDate.day);

    final shrinkage =
        await _db.calculateShrinkage(widget.store.id!, startDate, endDate);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shrinkage Report'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shrinkage.containsKey('error'))
                Text(
                  shrinkage['error'],
                  style: const TextStyle(color: Colors.red),
                )
              else ...[
                Text(
                    'Period: ${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}'),
                const Divider(),
                Text(
                    'Opening Stock: R${shrinkage['opening_stock_value'].toStringAsFixed(2)}'),
                Text(
                    'Purchases: R${shrinkage['purchases_value'].toStringAsFixed(2)}'),
                Text('Sales: R${shrinkage['sales_value'].toStringAsFixed(2)}'),
                const Divider(),
                Text(
                    'Expected Closing: R${shrinkage['expected_closing_value'].toStringAsFixed(2)}'),
                Text(
                    'Actual Closing: R${shrinkage['actual_closing_value'].toStringAsFixed(2)}'),
                const Divider(),
                Text(
                  'Shrinkage: R${shrinkage['shrinkage_value'].toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: shrinkage['shrinkage_value'] > 0
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                Text(
                  'Shrinkage %: ${shrinkage['shrinkage_percentage'].toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        shrinkage['meets_target'] ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: shrinkage['meets_target']
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  child: Text(
                    shrinkage['meets_target']
                        ? '✓ Target met (<2%)'
                        : '⚠ Target not met (>2%) - Investigate',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: shrinkage['meets_target']
                          ? Colors.green.shade900
                          : Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
      appBar: AppBar(
        title: Text('Stock Take: ${widget.store.storeName}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: _showShrinkageReport,
            tooltip: 'Shrinkage Report',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BarcodeScannerScreen(
                    onProductScanned: (product) {
                      _addOrUpdateItem(product, 1);
                    },
                  ),
                ),
              );
            },
            tooltip: 'Scan Barcode',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _completeStockTake,
            tooltip: 'Complete',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _loadProducts();
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                            _loadProducts();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      // Category filter
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((category) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(category),
                                selected: _selectedCategory == category,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory = category;
                                    _loadProducts();
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Products list
                Expanded(
                  child: _products.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No products found',
                                style: TextStyle(fontSize: 18),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap the scanner icon to scan barcodes',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            final existingItem = _items.firstWhere(
                              (item) => item.productId == product.id,
                              orElse: () => StockTakeItem(
                                stockTakeId: _currentStockTake.id!,
                                productId: product.id!,
                                countedQuantity: 0,
                                costPriceAtTime: product.defaultCostPrice,
                                sellingPriceAtTime: product.defaultSellingPrice,
                              ),
                            );

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Cost: R${product.defaultCostPrice.toStringAsFixed(2)} | Sell: R${product.defaultSellingPrice.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (product.barcode != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '📷 ${product.barcode!.substring(product.barcode!.length - 8)}',
                                              style:
                                                  const TextStyle(fontSize: 10),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove,
                                              color: Colors.red),
                                          onPressed: () {
                                            _addOrUpdateItem(
                                                product,
                                                existingItem.countedQuantity -
                                                    1);
                                          },
                                        ),
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            initialValue: existingItem
                                                .countedQuantity
                                                .toInt()
                                                .toString(),
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8),
                                            ),
                                            onChanged: (value) {
                                              final qty =
                                                  int.tryParse(value) ?? 0;
                                              if (qty >= 0) {
                                                _addOrUpdateItem(
                                                    product, qty.toDouble());
                                              }
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add,
                                              color: Colors.green),
                                          onPressed: () {
                                            _addOrUpdateItem(
                                                product,
                                                existingItem.countedQuantity +
                                                    1);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
