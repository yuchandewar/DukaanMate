import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> shareReceipt({
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String storeGstn,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double gstPercentage,
    required double gstAmount,
    required double total,
    required double paidAmount,
    required String paymentMethod,
    required String billNumber,
  }) async {
    final pdf = pw.Document();

    // Load the logo from assets
    pw.MemoryImage? logoImage;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.jpg');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      // Ignore if logo not found
    }

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(storeName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      if (storeAddress.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      ],
                      if (storePhone.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('Phone: $storePhone', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      ],
                      if (storeGstn.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('GSTIN: $storeGstn', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      ],
                    ],
                  ),
                  if (logoImage != null)
                    pw.Container(
                      width: 60,
                      height: 60,
                      child: pw.Image(logoImage),
                    ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 20),
              
              // INVOICE DETAILS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      pw.SizedBox(height: 4),
                      pw.Text('Bill No: $billNumber', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Payment Method: $paymentMethod', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Amount Paid: Rs. ${paidAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  )
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // ITEMS TABLE
              pw.TableHelper.fromTextArray(
                context: context,
                border: const pw.TableBorder(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.indigo50,
                ),
                headerHeight: 35,
                cellHeight: 30,
                headerStyle: pw.TextStyle(
                  color: PdfColors.indigo900,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 11),
                headerAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
                headers: ['Item Description', 'Qty', 'Price', 'Total'],
                data: items.map((item) {
                  return [
                    item['name'],
                    '${item['qty']} ${item['unit']}',
                    '${item['price'].toStringAsFixed(2)}',
                    '${(item['qty'] * item['price']).toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
              
              pw.SizedBox(height: 20),
              
              // TOTALS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _buildTotalRow('Subtotal', subtotal),
                        if (discount > 0) _buildTotalRow('Discount', discount, isNegative: true),
                        if (gstAmount > 0) _buildTotalRow('GST ($gstPercentage%)', gstAmount),
                        pw.SizedBox(height: 8),
                        pw.Divider(color: PdfColors.indigo900),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                            pw.Text('Rs. ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Divider(color: PdfColors.indigo900),
                      ],
                    ),
                  )
                ],
              ),
              
              pw.Spacer(),
              
              // FOOTER
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'This is an authenticated computer generated invoice.',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save and Share the PDF
    final Uint8List pdfBytes = await pdf.save();
    await Printing.sharePdf(bytes: pdfBytes, filename: 'Invoice_$billNumber.pdf');
  }

  static pw.Widget _buildTotalRow(String label, double amount, {bool isNegative = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
          pw.Text(
            isNegative ? '- Rs. ${amount.toStringAsFixed(2)}' : 'Rs. ${amount.toStringAsFixed(2)}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }
}
