import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../../../services/company_service.dart';

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final CompanyService _companyService = CompanyService();

  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _logoBase64;
  Color _primaryColor = const Color(0xFF667eea);

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _vatController = TextEditingController();
  final _regController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final result = await _companyService.getCompanyProfile();

    if (result['success']) {
      setState(() {
        _profile = result['data'];
        _nameController.text = _profile['company_name'] ?? '';
        _emailController.text = _profile['contact_email'] ?? '';
        _phoneController.text = _profile['phone'] ?? '';
        _websiteController.text = _profile['website'] ?? '';
        _addressController.text = _profile['address'] ?? '';
        _vatController.text = _profile['vat_number'] ?? '';
        _regController.text = _profile['registration_number'] ?? '';
        _logoBase64 = _profile['company_logo'];
        if (_profile['primary_color'] != null) {
          _primaryColor = Color(
              int.parse(_profile['primary_color'].substring(1, 7), radix: 16) +
                  0xFF000000);
        }
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${result['error']}')),
      );
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 500);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _logoBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final profileData = {
      'company_name': _nameController.text,
      'contact_email': _emailController.text,
      'phone': _phoneController.text,
      'website': _websiteController.text,
      'address': _addressController.text,
      'vat_number': _vatController.text,
      'registration_number': _regController.text,
      'company_logo': _logoBase64,
      'primary_color':
          '#${_primaryColor.value.toRadixString(16).substring(2, 8)}',
    };

    final result = await _companyService.updateCompanyProfile(profileData);

    setState(() => _isSaving = false);

    if (result['success']) {
      // Update shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('company_name', _nameController.text);
      if (_logoBase64 != null) {
        await prefs.setString('company_logo', _logoBase64!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${result['error']}'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Company Profile'),
            pinned: true,
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _isSaving ? null : _saveProfile,
                tooltip: 'Save Profile',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo Section
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(60),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipOval(
                              child: _logoBase64 != null
                                  ? Image.memory(base64Decode(_logoBase64!),
                                      fit: BoxFit.cover)
                                  : Icon(Icons.business,
                                      size: 60, color: Colors.grey.shade400),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _pickLogo,
                            icon: const Icon(Icons.upload),
                            label: const Text('Upload Logo'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Company Details
                    const Text('Company Information',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Company Name *',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
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

                    TextFormField(
                      controller: _websiteController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Website',
                        prefixIcon: Icon(Icons.language),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Registration Details
                    const Text('Registration Details',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _regController,
                      decoration: const InputDecoration(
                        labelText: 'Registration Number',
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _vatController,
                      decoration: const InputDecoration(
                        labelText: 'VAT Number',
                        prefixIcon: Icon(Icons.receipt),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Theme Settings
                    const Text('Branding',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    ListTile(
                      leading: const Icon(Icons.color_lens),
                      title: const Text('Primary Color'),
                      trailing: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      onTap: () async {
                        final color = await showDialog<Color>(
                          context: context,
                          builder: (context) =>
                              ColorPickerDialog(initialColor: _primaryColor),
                        );
                        if (color != null) {
                          setState(() => _primaryColor = color);
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Save Profile',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple Color Picker Dialog
class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const ColorPickerDialog({super.key, required this.initialColor});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Primary Color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _selectedColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              Colors.blue,
              Colors.green,
              Colors.red,
              Colors.purple,
              Colors.orange,
              Colors.teal,
              Colors.pink,
              Colors.indigo,
            ]
                .map((color) => GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _selectedColor == color
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 2),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, _selectedColor),
            child: const Text('Select')),
      ],
    );
  }
}
