import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfReportService {
  static Future<Uint8List> generateShrinkageReport({
    required String companyName,
    required String storeName,
    required Map<String, dynamic> data,
    required DateTime startDate,
    required DateTime endDate,
    String? logoBase64,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(base64Decode(logoBase64));
      } catch (e) {
        // Invalid logo, ignore
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with Logo
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 60,
                      height: 60,
                      child: pw.Image(logoImage),
                    ),
                  if (logoImage != null) pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          companyName,
                          style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue),
                        ),
                        pw.Text(
                          'Shrinkage Report',
                          style:
                              pw.TextStyle(fontSize: 14, color: PdfColors.grey),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Store and Period Information
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Store Information',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text('Store Name: $storeName'),
                    pw.Text(
                        'Period: ${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}'),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Shrinkage Summary
              pw.Text('Shrinkage Summary',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _buildSummaryRow('Opening Stock Value',
                        'R${(data['opening_stock_value'] ?? 0).toStringAsFixed(2)}'),
                    _buildSummaryRow('Purchases',
                        'R${(data['purchases_value'] ?? 0).toStringAsFixed(2)}'),
                    _buildSummaryRow('Sales',
                        'R${(data['sales_value'] ?? 0).toStringAsFixed(2)}'),
                    pw.Divider(),
                    _buildSummaryRow('Expected Closing',
                        'R${(data['expected_closing_value'] ?? 0).toStringAsFixed(2)}'),
                    _buildSummaryRow('Actual Closing',
                        'R${(data['actual_closing_value'] ?? 0).toStringAsFixed(2)}'),
                    pw.Divider(thickness: 2),
                    _buildSummaryRow(
                      'SHRINKAGE',
                      'R${(data['shrinkage_value'] ?? 0).toStringAsFixed(2)} (${(data['shrinkage_percentage'] ?? 0).toStringAsFixed(2)}%)',
                      isBold: true,
                      color: PdfColors.red,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Status
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: (data['meets_target'] ?? false)
                      ? PdfColors.green100
                      : PdfColors.red100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      (data['meets_target'] ?? false)
                          ? '✓ Target met (Shrinkage < 2%)'
                          : '⚠ Target not met (Shrinkage > 2%) - Action required',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: (data['meets_target'] ?? false)
                            ? PdfColors.green800
                            : PdfColors.red800,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Generated by Stock Take SA - Professional Stock Management System',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                '${DateTime.now().toLocal()}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}
