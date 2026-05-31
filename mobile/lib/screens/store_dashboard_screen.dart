import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/store.dart';
import '../services/database_service.dart';
import '../services/company_service.dart';
import 'stock_take_screen.dart';
import 'stock_take_history_screen.dart';
import 'inventory_screen.dart';
import 'calculations/calculations_dashboard.dart';
import 'reports/reports_screen.dart';
import 'invoices/invoice_list_screen.dart';
import 'edit_store_screen.dart';

class StoreDashboardScreen extends StatefulWidget {
  final Store store;
  
  const StoreDashboardScreen({super.key, required this.store});

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  int _selectedIndex = 0;
  String _companyName = '';
  String _companyLogo = '';
  Color _primaryColor = const Color(0xFF667eea);
  
  late List<Widget> _screens;
  
  final List<String> _titles = [
    'Stock Take',
    'Calculations',
    'Reports',
    'Invoices',
  ];
  
  final List<IconData> _icons = [
    Icons.inventory,
    Icons.calculate,
    Icons.insert_chart,
    Icons.receipt,
  ];

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
    
    // Initialize screens with the selected store
    _screens = [
      StockTakeScreen(store: widget.store),
      CalculationsDashboard(store: widget.store),
      ReportsScreen(store: widget.store),
      InvoiceListScreen(store: widget.store),
    ];
  }

  Future<void> _loadCompanyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyName = prefs.getString('company_name') ?? 'Stock Take SA';
      _companyLogo = prefs.getString('company_logo') ?? '';
    });
    
    final companyService = CompanyService();
    final result = await companyService.getCompanyProfile();
    if (result['success'] && result['data']['primary_color'] != null) {
      final colorHex = result['data']['primary_color'];
      setState(() {
        _primaryColor = Color(int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000);
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
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.store, size: 20),
                        )
                      : const Icon(Icons.store, size: 20),
                ),
              ),
            if (_companyLogo.isNotEmpty) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.store.storeName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _titles[_selectedIndex],
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Inventory Button
          IconButton(
            icon: const Icon(Icons.inventory),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InventoryScreen()),
              );
            },
            tooltip: 'View Inventory',
          ),
          // Stock Take History Button
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StockTakeHistoryScreen(store: widget.store),
                ),
              );
            },
            tooltip: 'Stock Take History',
          ),
          // Store Settings Button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditStoreScreen(store: widget.store),
                ),
              );
              if (result == true && mounted) {
                // Store was updated or deleted, go back to store list
                Navigator.pop(context, true);
              }
            },
            tooltip: 'Store Settings',
          ),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        items: List.generate(4, (index) {
          return BottomNavigationBarItem(
            icon: Icon(_icons[index]),
            label: _titles[index],
          );
        }),
      ),
    );
  }
}