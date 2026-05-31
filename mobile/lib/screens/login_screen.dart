import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _licenseController = TextEditingController();
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
  bool _isLoading = false;
  bool _obscureLicense = true;
  String? _errorMessage;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _licenseController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email and license key';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.post('/company/login', data: {
        'email': _emailController.text.trim(),
        'licenseKey': _licenseController.text.trim(),
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Save company info
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('company_id', response.data['company']['id']);
        await prefs.setString('company_name', response.data['company']['name']);
        await prefs.setString(
            'license_key', response.data['company']['license_key']);
        await prefs.setBool('is_logged_in', true);

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/store-list');
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        // Account suspended or expired
        final message = e.response?.data['message'] ?? 'Account issue';
        final supportEmail =
            e.response?.data['support_email'] ?? 'support@stocktake.co.za';

        setState(() {
          _errorMessage = message;
        });

        // Show detailed dialog for suspended accounts
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 32),
                SizedBox(width: 8),
                Text('Account Suspended'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text(message),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Contact Support',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        supportEmail,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _errorMessage = e.response?.data['message'] ??
              'Login failed. Please check your credentials.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please check your connection.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'Stock Take SA',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Professional Stock Management',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),

              // Email Field - Prevent browser save password
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [],
                enableIMEPersonalizedLearning: false,
                obscureText: false,
                decoration: const InputDecoration(
                  labelText: 'Company Email',
                  hintText: 'admin@yourcompany.co.za',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // License Key Field - Prevent browser save password
              TextField(
                controller: _licenseController,
                obscureText: _obscureLicense,
                autofillHints: const [],
                enableIMEPersonalizedLearning: false,
                decoration: InputDecoration(
                  labelText: 'License Key',
                  hintText: 'LIC-XXX-XXX-XXX',
                  prefixIcon: const Icon(Icons.vpn_key),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureLicense
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscureLicense = !_obscureLicense),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),

              // Help text
              Text(
                'Enter your company email and license key',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}