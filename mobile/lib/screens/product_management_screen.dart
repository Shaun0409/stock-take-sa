import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/product.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final DatabaseService _db = DatabaseService();
  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _db.getProducts(searchQuery: _searchQuery);
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  Future<void> _addProduct() async {
    final result = await showDialog<Product>(
      context: context,
      builder: (context) => ProductFormDialog(
        title: 'Add Product',
        product: null,
      ),
    );

    if (result != null) {
      await _db.insertProduct(result);
      await _loadProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ ${result.name} added')),
      );
    }
  }

  Future<void> _editProduct(Product product) async {
    final result = await showDialog<Product>(
      context: context,
      builder: (context) => ProductFormDialog(
        title: 'Edit Product',
        product: product,
      ),
    );

    if (result != null) {
      await _db.updateProduct(result);
      await _loadProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✏️ ${result.name} updated')),
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteProduct(product.id!);
      await _loadProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🗑️ ${product.name} deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addProduct,
            tooltip: 'Add Product',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
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
          ),

          // Products list
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
                            Text('No products found'),
                            SizedBox(height: 8),
                            Text('Tap + to add products'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  product.name.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Category: ${product.category}'),
                                  Text(
                                    'Cost: R${product.defaultCostPrice.toStringAsFixed(2)} | Sell: R${product.defaultSellingPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (product.barcode != null)
                                    Text(
                                      'Barcode: ${product.barcode}',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => _editProduct(product),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _deleteProduct(product),
                                    tooltip: 'Delete',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        child: const Icon(Icons.add),
        tooltip: 'Add Product',
      ),
    );
  }
}

// Product Form Dialog
class ProductFormDialog extends StatefulWidget {
  final String title;
  final Product? product;

  const ProductFormDialog({
    super.key,
    required this.title,
    this.product,
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _categoryController;
  late TextEditingController _costController;
  late TextEditingController _priceController;
  late TextEditingController _unitController;

  final List<String> _categories = [
    'Bakery',
    'Dairy',
    'Beverages',
    'Snacks',
    'Breakfast',
    'Pantry',
    'Airtime',
    'General'
  ];
  String _selectedCategory = 'General';
  String _selectedUnit = 'each';

  final List<String> _units = ['each', 'kg', 'g', 'L', 'mL'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _barcodeController =
        TextEditingController(text: widget.product?.barcode ?? '');
    _categoryController =
        TextEditingController(text: widget.product?.category ?? 'General');
    _costController = TextEditingController(
        text: widget.product?.defaultCostPrice.toString() ?? '');
    _priceController = TextEditingController(
        text: widget.product?.defaultSellingPrice.toString() ?? '');
    _unitController =
        TextEditingController(text: widget.product?.unit ?? 'each');
    _selectedCategory = widget.product?.category ?? 'General';
    _selectedUnit = widget.product?.unit ?? 'each';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  border: OutlineInputBorder(),
                  hintText: 'Scan or enter barcode',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: const InputDecoration(
                  labelText: 'Unit *',
                  border: OutlineInputBorder(),
                ),
                items: _units.map((unit) {
                  return DropdownMenuItem(value: unit, child: Text(unit));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedUnit = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cost Price (R) *',
                  border: OutlineInputBorder(),
                  prefixText: 'R ',
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Selling Price (R) *',
                  border: OutlineInputBorder(),
                  prefixText: 'R ',
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final product = Product(
                id: widget.product?.id,
                companyId: 'company_1',
                barcode: _barcodeController.text.isEmpty
                    ? null
                    : _barcodeController.text,
                name: _nameController.text,
                category: _selectedCategory,
                unit: _selectedUnit,
                defaultCostPrice: double.parse(_costController.text),
                defaultSellingPrice: double.parse(_priceController.text),
                isActive: true,
              );
              Navigator.pop(context, product);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
