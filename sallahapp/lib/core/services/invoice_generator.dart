import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

/// Generates a simple, legal-looking invoice PDF for a completed big
/// project, and a short human-readable invoice ID to print on it.
class InvoiceGenerator {
  /// Format: FACT-YYYYMMDD-XXXX (XXXX = last 4 chars of the request id,
  /// uppercased) - short, unique enough, and traceable back to the order.
  static String generateInvoiceId(String requestId) {
    final now = DateTime.now();
    final datePart = DateFormat('yyyyMMdd').format(now);
    final suffix = requestId.length >= 4
        ? requestId.substring(requestId.length - 4).toUpperCase()
        : requestId.toUpperCase();
    return 'FACT-$datePart-$suffix';
  }

  /// The PDF package's base fonts (Helvetica) only support the
  /// WinAnsi/Latin-1 character range. Client/company names, addresses,
  /// and descriptions are free user input and can contain emoji, curly
  /// quotes, em-dashes, or other characters outside that range - any
  /// of which crashes PDF generation entirely. This strips/replaces
  /// anything unsafe before it ever reaches a pw.Text widget.
  static String _safe(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      switch (rune) {
        case 0x2014: // em dash —
        case 0x2013: // en dash –
          buffer.write('-');
          break;
        case 0x2018: // left single quote '
        case 0x2019: // right single quote '
          buffer.write("'");
          break;
        case 0x201C: // left double quote "
        case 0x201D: // right double quote "
          buffer.write('"');
          break;
        case 0x2026: // ellipsis …
          buffer.write('...');
          break;
        default:
          if (rune <= 0xFF) {
            buffer.writeCharCode(rune);
          }
        // else: silently drop (emoji, exotic symbols, etc.) - safer
        // than crashing the whole invoice.
      }
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? '-' : result;
  }

  static Future<Uint8List> build({
    required String invoiceId,
    required String companyName,
    required String companyCity,
    String companyPhone = '',
    required String clientName,
    required String clientAddress,
    required String categoryLabel,
    required String description,
    required double priceMAD,
    required DateTime serviceDate,
    required DateTime completedAt,
  }) async {
    final doc = pw.Document();
    final dateFmt = DateFormat('dd/MM/yyyy');

    // Sanitize every piece of dynamic/user-supplied text once, up front.
    final safeCompanyName = _safe(companyName);
    final safeCompanyCity = _safe(companyCity);
    final safeCompanyPhone = _safe(companyPhone);
    final safeClientName = _safe(clientName);
    final safeClientAddress = _safe(clientAddress);
    final safeCategoryLabel = _safe(categoryLabel);
    final safeDescription = _safe(description);
    final safeInvoiceId = _safe(invoiceId);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ---- Header ----
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CHI HAL',
                          style: pw.TextStyle(
                              fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Grands Services - plateforme de mise en relation',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FACTURE',
                          style: pw.TextStyle(
                              fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text('N° $safeInvoiceId', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1.2),
              pw.SizedBox(height: 18),

              // ---- Parties ----
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PRESTATAIRE',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(safeCompanyName,
                            style: pw.TextStyle(
                                fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text(safeCompanyCity, style: const pw.TextStyle(fontSize: 10)),
                        if (safeCompanyPhone.isNotEmpty && safeCompanyPhone != '-')
                          pw.Text(safeCompanyPhone, style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CLIENT',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(safeClientName,
                            style: pw.TextStyle(
                                fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text(safeClientAddress, style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // ---- Dates ----
              pw.Row(
                children: [
                  pw.Text('Date d\'intervention : ',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateFmt.format(serviceDate), style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(width: 24),
                  pw.Text('Date de facturation : ',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateFmt.format(completedAt), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 24),

              // ---- Line item table ----
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(5),
                  2: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('Catégorie', bold: true),
                      _cell('Description', bold: true),
                      _cell('Montant', bold: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell(safeCategoryLabel),
                      _cell(safeDescription),
                      _cell('${priceMAD.toStringAsFixed(0)} MAD'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 18),

              // ---- Total ----
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text('TOTAL : ',
                          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.Text('${priceMAD.toStringAsFixed(0)} MAD',
                          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 36),

              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 6),
              pw.Text(
                  'Facture générée automatiquement par CHI HAL suite à la confirmation '
                  'du client et à la réalisation du projet. Prix fixé sans négociation '
                  'après devis. Document à conserver.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}