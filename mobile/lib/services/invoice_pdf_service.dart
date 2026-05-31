import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/store.dart';
import 'dart:typed_data';
import 'dart:convert';

class InvoicePdfService {
  static Future<Uint8List> generateInvoice({
    required Store store,
    required String invoiceNumber,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double vat,
    required double total,
    String? logoBase64,
    String? companyName,
    String? companyAddress,
    String? companyVat,
  }) async {
    final pdf = pw.Document();

    final logoImage =
        logoBase64 != null ? pw.MemoryImage(base64Decode(logoBase64)) : null;

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 80,
                      height: 80,
                      child: pw.Image(logoImage),
                    ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          companyName ?? 'Stock Take SA',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (companyAddress != null)
                          pw.Text(companyAddress,
                              style: const pw.TextStyle(fontSize: 10)),
                        if (companyVat != null)
                          pw.Text('VAT: $companyVat',
                              style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                      pw.Text('No: $invoiceNumber'),
                      pw.Text(
                          'Date: ${date.toLocal().toString().split(' ')[0]}'),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Bill To
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill To:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(store.storeName),
                    if (store.ownerName != null) pw.Text(store.ownerName!),
                    if (store.suburb != null) pw.Text(store.suburb!),
                    if (store.city != null) pw.Text(store.city!),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Items table
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Description',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Qty',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Unit Price',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Total',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...items.map((item) => pw.TableRow(
                        children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(item['description'])),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(item['quantity'].toString())),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                  'R${item['unitPrice'].toStringAsFixed(2)}')),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                  'R${item['total'].toStringAsFixed(2)}')),
                        ],
                      )),
                ],
              ),

              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Subtotal: R${subtotal.toStringAsFixed(2)}'),
                      pw.Text('VAT (15%): R${vat.toStringAsFixed(2)}'),
                      pw.Text('Total: R${total.toStringAsFixed(2)}',
                          style: const pw.TextStyle(
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 40),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Thank you for your business!',
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Payment due within 30 days',
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printInvoice(Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      onLayout: (_) => pdfBytes,
    );
  }
}
