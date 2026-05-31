import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/company_service.dart';
import 'store_list_screen.dart';
import 'calculations/calculations_dashboard.dart';
import 'reports/reports_screen.dart';
import 'invoices/invoice_list_screen.dart';
import 'profile/company_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _companyName = '';
  String _companyLogo = '';
  Color _primaryColor = const Color(0xFF667eea);

  final List<Widget> _screens = [
    const StoreListScreen(),
    const CalculationsDashboard(),
    const ReportsScreen(),
    const InvoiceListScreen(),
    const CompanyProfileScreen(),
  ];

  final List<String> _titles = [
    'Stores',
    'Calculations',
    'Reports',
    'Invoices',
    'Profile',
  ];

  final List<IconData> _icons = [
    Icons.store,
    Icons.calculate,
    Icons.insert_chart,
    Icons.receipt,
    Icons.business,
  ];

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
  }

  Future<void> _loadCompanyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyName = prefs.getString('company_name') ?? 'Stock Take SA';
      _companyLogo = prefs.getString('company_logo') ?? '';
    });

    // Load company colors
    final companyService = CompanyService();
    final result = await companyService.getCompanyProfile();
    if (result['success'] && result['data']['primary_color'] != null) {
      final colorHex = result['data']['primary_color'];
      setState(() {
        _primaryColor =
            Color(int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000);
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_companyLogo.isNotEmpty)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _companyLogo.isNotEmpty
                      ? Image.memory(
                          base64Decode(_companyLogo),
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.store, size: 20),
                        )
                      : const Icon(Icons.store, size: 20),
                ),
              ),
            if (_companyLogo.isNotEmpty) const SizedBox(width: 12),
            Text(_titles[_selectedIndex]),
          ],
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            icon: CircleAvatar(
              backgroundColor: Colors.white24,
              radius: 20,
              child: Text(
                _companyName.isNotEmpty ? _companyName[0].toUpperCase() : 'U',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey,
        items: List.generate(5, (index) {
          return BottomNavigationBarItem(
            icon: Icon(_icons[index]),
            label: _titles[index],
          );
        }),
      ),
    );
  }
}
