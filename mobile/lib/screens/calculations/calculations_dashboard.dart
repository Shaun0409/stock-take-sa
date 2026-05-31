import 'package:flutter/material.dart';
import '../../models/store.dart';
import '../../services/database_service.dart';

class CalculationsDashboard extends StatefulWidget {
  final Store store;
  
  const CalculationsDashboard({super.key, required this.store});

  @override
  State<CalculationsDashboard> createState() => _CalculationsDashboardState();
}

class _CalculationsDashboardState extends State<CalculationsDashboard> {
  final DatabaseService _db = DatabaseService();
  bool _isCalculating = false;
  Map<String, dynamic> _results = {};
  String _selectedPeriod = '30days';
  String? _errorMessage;

  Future<void> _calculate(String type) async {
    setState(() {
      _isCalculating = true;
      _errorMessage = null;
      _results = {};
    });

    try {
      final endDate = DateTime.now();
      DateTime startDate;
      
      switch (_selectedPeriod) {
        case '7days':
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case '30days':
          startDate = endDate.subtract(const Duration(days: 30));
          break;
        case '90days':
          startDate = endDate.subtract(const Duration(days: 90));
          break;
        default:
          startDate = endDate.subtract(const Duration(days: 30));
      }
      
      final shrinkage = await _db.calculateShrinkage(widget.store.id!, startDate, endDate);
      
      setState(() {
        _results = shrinkage;
        _isCalculating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error calculating: $e';
        _isCalculating = false;
      });
    }
  }

  Future<void> _calculateMaster() async {
    setState(() {
      _isCalculating = true;
      _errorMessage = null;
    });

    try {
      final endDate = DateTime.now();
      DateTime startDate;
      
      switch (_selectedPeriod) {
        case '7days':
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case '30days':
          startDate = endDate.subtract(const Duration(days: 30));
          break;
        case '90days':
          startDate = endDate.subtract(const Duration(days: 90));
          break;
        default:
          startDate = endDate.subtract(const Duration(days: 30));
      }
      
      final shrinkage = await _db.calculateShrinkage(widget.store.id!, startDate, endDate);
      
      // Get additional calculations here (profit, turnover)
      
      setState(() {
        _results = {
          ...shrinkage,
          'calculation_type': 'master',
          'profit_estimate': (shrinkage['sales_value'] ?? 0) * 0.25,
        };
        _isCalculating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error calculating master: $e';
        _isCalculating = false;
      });
    }
  }

  Widget _buildResultCard() {
    if (_results.isEmpty) return const SizedBox.shrink();
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildResultRow('Opening Stock Value', 'R${_results['opening_stock_value']?.toStringAsFixed(2) ?? '0.00'}'),
            _buildResultRow('Purchases', 'R${_results['purchases_value']?.toStringAsFixed(2) ?? '0.00'}'),
            _buildResultRow('Sales', 'R${_results['sales_value']?.toStringAsFixed(2) ?? '0.00'}'),
            _buildResultRow('Expected Closing', 'R${_results['expected_closing_value']?.toStringAsFixed(2) ?? '0.00'}'),
            _buildResultRow('Actual Closing', 'R${_results['actual_closing_value']?.toStringAsFixed(2) ?? '0.00'}'),
            const Divider(),
            _buildResultRow(
              'Shrinkage', 
              'R${_results['shrinkage_value']?.toStringAsFixed(2) ?? '0.00'}',
              color: (_results['shrinkage_value'] ?? 0) > 0 ? Colors.red : Colors.green,
            ),
            _buildResultRow(
              'Shrinkage %', 
              '${_results['shrinkage_percentage']?.toStringAsFixed(2) ?? '0.00'}%',
              color: (_results['shrinkage_percentage'] ?? 0) > 2 ? Colors.red : Colors.green,
            ),
            if (_results['profit_estimate'] != null)
              _buildResultRow(
                'Estimated Profit', 
                'R${_results['profit_estimate']?.toStringAsFixed(2) ?? '0.00'}',
                color: Colors.blue,
              ),
            if (_results['meets_target'] == true)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('✓ Target met (<2%)', style: TextStyle(color: Colors.green)),
              )
            else if (_results['meets_target'] == false)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('⚠ Target not met (>2%) - Action required', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Store header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.store, size: 40, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    widget.store.storeName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    widget.store.suburb ?? 'No address',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            
            // Period selector
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Period: '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: '7days', label: Text('7 days')),
                        ButtonSegment(value: '30days', label: Text('30 days')),
                        ButtonSegment(value: '90days', label: Text('90 days')),
                      ],
                      selected: {_selectedPeriod},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() {
                          _selectedPeriod = selection.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Calculation buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isCalculating ? null : () => _calculate('profit'),
                    icon: const Icon(Icons.attach_money),
                    label: const Text('Profit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isCalculating ? null : () => _calculate('shrinkage'),
                    icon: const Icon(Icons.trending_down),
                    label: const Text('Shrinkage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isCalculating ? null : () => _calculate('turnover'),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Turnover'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isCalculating ? null : () => _calculateMaster(),
                    icon: const Icon(Icons.calculate),
                    label: const Text('Master'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            if (_isCalculating) 
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)),
                ),
              ),
            
            _buildResultCard(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}