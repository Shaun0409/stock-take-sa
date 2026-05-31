import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/product.dart';
import 'barcode_scanner_screen.dart';
import 'product_management_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final DatabaseService _db = DatabaseService();
  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCategories();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _db.getProducts(
      category: _selectedCategory == 'All' ? null : _selectedCategory,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  Future<void> _loadCategories() async {
    final cats = await _db.getCategories();
    setState(() {
      _categories = ['All', ...cats];
    });
  }

  double _getTotalInventoryValue() {
    return _products.fold(0, (sum, p) => sum + p.defaultCostPrice);
  }

  double _getTotalSellingValue() {
    return _products.fold(0, (sum, p) => sum + p.defaultSellingPrice);
  }

  double _getTotalPotentialProfit() {
    return _getTotalSellingValue() - _getTotalInventoryValue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BarcodeScannerScreen(
                    onProductScanned: (product) {
                      _loadProducts();
                      _loadCategories();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ ${product.name} added to inventory'), backgroundColor: Colors.green),
                      );
                    },
                  ),
                ),
              );
            },
            tooltip: 'Scan Barcode',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadProducts();
              _loadCategories();
            },
          ),
        ],
      ),
      body: Column(
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
          
          // Summary Cards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text('Total Products', style: TextStyle(fontSize: 12)),
                          Text(
                            '${_products.length}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text('Inventory Value', style: TextStyle(fontSize: 12)),
                          Text(
                            'R${_getTotalInventoryValue().toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text('Potential Profit', style: TextStyle(fontSize: 12)),
                          Text(
                            'R${_getTotalPotentialProfit().toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Products Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No products in inventory'),
                            SizedBox(height: 8),
                            Text('Scan or add products to get started'),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 12,
                          columns: const [
                            DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Barcode', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Cost', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Sell', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Profit', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Margin', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _products.map((product) {
                            final profit = product.defaultSellingPrice - product.defaultCostPrice;
                            final margin = product.defaultSellingPrice > 0 
                                ? (profit / product.defaultSellingPrice) * 100 
                                : 0;
                            return DataRow(cells: [
                              DataCell(Text(product.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Text(product.barcode ?? '-', style: const TextStyle(fontSize: 11))),
                              DataCell(Text(product.category)),
                              DataCell(Text('R${product.defaultCostPrice.toStringAsFixed(2)}')),
                              DataCell(Text('R${product.defaultSellingPrice.toStringAsFixed(2)}')),
                              DataCell(Text('R${profit.toStringAsFixed(2)}', style: TextStyle(color: profit > 0 ? Colors.green : Colors.red))),
                              DataCell(Text('${margin.toStringAsFixed(1)}%', style: TextStyle(color: margin > 20 ? Colors.green : Colors.orange))),
                            ]);
                          }).toList(),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProductManagementScreen()),
          ).then((_) {
            _loadProducts();
            _loadCategories();
          });
        },
        child: const Icon(Icons.add),
        tooltip: 'Add Product',
      ),
    );
  }
}