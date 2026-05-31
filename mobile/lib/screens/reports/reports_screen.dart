import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/store.dart';
import '../../services/database_service.dart';
import '../../services/pdf_report_service.dart';

class ReportsScreen extends StatefulWidget {
  final Store store;
  
  const ReportsScreen({super.key, required this.store});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isGenerating = false;
  String _selectedPeriod = '30days';
  String? _errorMessage;

  Future<void> _generateShrinkageReport() async {
    setState(() {
      _isGenerating = true;
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
      
      if (shrinkage.containsKey('error')) {
        setState(() {
          _errorMessage = shrinkage['error'];
          _isGenerating = false;
        });
        return;
      }
      
      final pdfBytes = await PdfReportService.generateShrinkageReport(
        companyName: 'Stock Take SA',
        storeName: widget.store.storeName,
        data: shrinkage,
        startDate: startDate,
        endDate: endDate,
      );
      
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
      );
      
      setState(() => _isGenerating = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating report: $e';
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Store header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.store, size: 48, color: Colors.green),
                    const SizedBox(height: 8),
                    Text(
                      widget.store.storeName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Reports & Analytics',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Period Selector
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Period:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
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
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Report Buttons
              if (_isGenerating)
                const Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton.icon(
                  onPressed: _generateShrinkageReport,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Shrinkage Report'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stock Take Summary Report - Coming Soon!')),
                    );
                  },
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Stock Take Summary'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profit & Loss Report - Coming Soon!')),
                    );
                  },
                  icon: const Icon(Icons.attach_money),
                  label: const Text('Profit & Loss'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Excel Export - Coming Soon!')),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Export All (Excel)'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}