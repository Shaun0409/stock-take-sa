import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/store.dart';

class EditStoreScreen extends StatefulWidget {
  final Store store;
  
  const EditStoreScreen({super.key, required this.store});

  @override
  State<EditStoreScreen> createState() => _EditStoreScreenState();
}

class _EditStoreScreenState extends State<EditStoreScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _ownerController;
  late TextEditingController _phoneController;
  late TextEditingController _suburbController;
  late TextEditingController _cityController;
  late TextEditingController _provinceController;
  late TextEditingController _addressController;
  
  String _selectedType = 'spaza';
  bool _isLoading = false;
  
  final List<String> _storeTypes = ['spaza', 'tuckshop', 'superette', 'cafe', 'petrol', 'garage', 'other'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store.storeName);
    _ownerController = TextEditingController(text: widget.store.ownerName ?? '');
    _phoneController = TextEditingController(text: widget.store.ownerPhone ?? '');
    _suburbController = TextEditingController(text: widget.store.suburb ?? '');
    _cityController = TextEditingController(text: widget.store.city ?? '');
    _provinceController = TextEditingController(text: widget.store.province ?? '');
    _addressController = TextEditingController(text: widget.store.address ?? '');
    _selectedType = widget.store.storeType ?? 'spaza';
  }

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
    
    final updatedStore = Store(
      id: widget.store.id,
      companyId: widget.store.companyId,
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
    
    await _db.updateStore(updatedStore);
    
    setState(() => _isLoading = false);
    
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Store updated!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _deleteStore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Store'),
        content: Text('Delete "${widget.store.storeName}"? This cannot be undone.'),
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
      await _db.deleteStore(widget.store.id!);
      if (mounted) {
        Navigator.pop(context, true); // Go back to store list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.store.storeName} deleted'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Settings'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: _deleteStore,
            tooltip: 'Delete Store',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Store Name *',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ownerController,
                decoration: const InputDecoration(
                  labelText: 'Owner / Manager Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
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
                  return DropdownMenuItem(value: type, child: Text(type.toUpperCase()));
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedType = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _suburbController,
                decoration: const InputDecoration(
                  labelText: 'Suburb',
                  prefixIcon: Icon(Icons.location_city),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _provinceController,
                decoration: const InputDecoration(
                  labelText: 'Province',
                  prefixIcon: Icon(Icons.map),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.home),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveStore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}