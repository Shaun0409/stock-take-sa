import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(Product) onProductScanned;

  const BarcodeScannerScreen({
    super.key,
    required this.onProductScanned,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  final DatabaseService _db = DatabaseService();
  bool _isScanning = true;
  String _lastScannedBarcode = '';
  DateTime? _lastScanTime;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!_isScanning) return;
    
    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null) return;
    
    final scannedValue = barcode.rawValue!;
    
    // Prevent double-scanning the same barcode within 2 seconds
    if (_lastScannedBarcode == scannedValue && 
        _lastScanTime != null && 
        DateTime.now().difference(_lastScanTime!) < const Duration(seconds: 2)) {
      return;
    }
    
    _lastScannedBarcode = scannedValue;
    _lastScanTime = DateTime.now();
    
    _handleScannedBarcode(scannedValue);
  }

  Future<void> _handleScannedBarcode(String barcode) async {
    setState(() => _isScanning = false);
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Find product by barcode
      final product = await _db.getProductByBarcode(barcode);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      if (product != null) {
        // Product found - add to stock take
        widget.onProductScanned(product);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${product.name} added'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
          Navigator.pop(context); // Return to stock take screen
        }
      } else {
        // Product not found - ask user to add it
        if (mounted) {
          _showAddProductDialog(barcode);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isScanning = true);
      }
    }
  }

  void _showAddProductDialog(String barcode) {
    final nameController = TextEditingController();
    final costController = TextEditingController();
    final priceController = TextEditingController();
    String selectedCategory = 'General';
    
    final categories = [
      'Bakery', 'Dairy', 'Beverages', 'Snacks', 
      'Breakfast', 'Pantry', 'Airtime', 'General'
    ];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Product Not Found'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No product found with this barcode:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  barcode,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Add new product:'),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) {
                  if (value != null) selectedCategory = value;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cost Price (R)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Selling Price (R)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _isScanning = true);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter product name')),
                );
                return;
              }
              
              // Get company ID from shared preferences
              final prefs = await SharedPreferences.getInstance();
              final companyId = prefs.getString('company_id') ?? 'company_1';
              
              final newProduct = Product(
                companyId: companyId,
                barcode: barcode,
                name: nameController.text,
                category: selectedCategory,
                defaultCostPrice: double.tryParse(costController.text) ?? 0,
                defaultSellingPrice: double.tryParse(priceController.text) ?? 0,
                isActive: true,
              );
              
              await _db.insertProduct(newProduct);
              
              if (mounted) {
                Navigator.pop(context); // Close add dialog
                widget.onProductScanned(newProduct);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ ${newProduct.name} added and scanned'), backgroundColor: Colors.green),
                );
                Navigator.pop(context); // Close scanner
              }
            },
            child: const Text('Add & Scan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_controller.torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.switch_camera),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),
          
          // Scanning overlay guide
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(60),
            child: const Center(
              child: Text(
                'Align barcode here',
                style: TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          // Manual entry button
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: () {
                _showManualEntryDialog();
              },
              icon: const Icon(Icons.keyboard),
              label: const Text('Enter Barcode Manually'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final barcodeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: TextField(
          controller: barcodeController,
          decoration: const InputDecoration(
            labelText: 'Barcode Number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final barcode = barcodeController.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(context);
                _handleScannedBarcode(barcode);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}