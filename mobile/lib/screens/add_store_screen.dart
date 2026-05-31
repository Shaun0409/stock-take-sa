import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../models/store.dart';

class AddStoreScreen extends StatefulWidget {
  const AddStoreScreen({super.key});

  @override
  State<AddStoreScreen> createState() => _AddStoreScreenState();
}

class _AddStoreScreenState extends State<AddStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();
  
  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _phoneController = TextEditingController();
  final _suburbController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isLoading = false;
  String _selectedType = 'spaza';
  
  final List<String> _storeTypes = ['spaza', 'tuckshop', 'superette', 'cafe', 'petrol', 'garage', 'other'];

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _phoneController.dispose();
    _suburbController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveStore() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id') ?? 'company_1';
      
      final store = Store(
        companyId: companyId,
        storeName: _nameController.text.trim(),
        ownerName: _ownerController.text.trim().isEmpty ? null : _ownerController.text.trim(),
        ownerPhone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        suburb: _suburbController.text.trim().isEmpty ? null : _suburbController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        province: _provinceController.text.trim().isEmpty ? null : _provinceController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        storeType: _selectedType,
        isActive: true,
      );
      
      await _db.insertStore(store);
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Store added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving store: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Store'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Store Name *',
                  hintText: 'e.g., Engen Garage Cape Town',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter store name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _ownerController,
                decoration: const InputDecoration(
                  labelText: 'Owner / Manager Name',
                  hintText: 'e.g., John Smith',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'e.g., 082 123 4567',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Store Type',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: _storeTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedType = value);
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _suburbController,
                decoration: const InputDecoration(
                  labelText: 'Suburb / Area',
                  hintText: 'e.g., Century City',
                  prefixIcon: Icon(Icons.location_city),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'e.g., Cape Town',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _provinceController,
                decoration: const InputDecoration(
                  labelText: 'Province',
                  hintText: 'e.g., Western Cape',
                  prefixIcon: Icon(Icons.map),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Full Address',
                  hintText: 'Street address, building name, etc.',
                  prefixIcon: Icon(Icons.home),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveStore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'ADD STORE',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
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