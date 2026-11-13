import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart' as ul;

/// Generates a PDF invoice and uploads it to Firebase Storage.
class InvoiceService {
  static final _dateFormat = DateFormat('dd/MM/yyyy a HH:mm');
  static final _numberFormat =
      NumberFormat.currency(locale: 'fr_MA', symbol: 'MAD', decimalDigits: 2);

  /// Sanitizes text to prevent PDF rendering crashes caused by unsupported characters/WinAnsi encoding.
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
        // Drops emoji and non-Latin script (like Arabic) to prevent crash
      }
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? '-' : result;
  }

  static Future<String> generateAndUpload({
    required String requestId,
    required Map<String, dynamic> orderData,
    Map<String, dynamic>? technicianData,
    Map<String, dynamic>? clientData,
  }) async {
    final pdfBytes = await _generate(
      requestId: requestId,
      orderData: orderData,
      technicianData: technicianData,
      clientData: clientData,
    );

    final ref = FirebaseStorage.instance
        .ref()
        .child('invoices/$requestId.pdf');
    final task = await ref.putData(
        pdfBytes, SettableMetadata(contentType: 'application/pdf'));
    final url = await task.ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('requests')
        .doc(requestId)
        .update({'invoiceUrl': url});

    return url;
  }

  static Future<Uint8List> _generate({
    required String requestId,
    required Map<String, dynamic> orderData,
    Map<String, dynamic>? technicianData,
    Map<String, dynamic>? clientData,
  }) async {
    final pdf = pw.Document();

    final brandGreen = PdfColor.fromHex('#0e8050');
    final lightGreen = PdfColor.fromHex('#e6f4ed');
    final darkText = PdfColor.fromHex('#0c1c13');
    final mutedText = PdfColor.fromHex('#57685e');
    final gold = PdfColor.fromHex('#c9a44a');

    // Extract & Sanitize raw strings
    final rawServiceLabel = orderData['serviceLabel'] as String? ?? 'Service Brikol';
    final rawClientName = clientData?['fullName'] as String? ??
        orderData['clientName'] as String? ?? 'Client';
    final rawClientCity = clientData?['city'] as String? ?? '';
    final rawClientPhone = clientData?['phone'] as String? ?? '';

    final rawTechName = technicianData?['fullName'] as String? ?? 'Technicien Brikol';
    final rawTechCity = technicianData?['city'] as String? ?? '';
    final rawTechPhone = technicianData?['phone'] as String? ?? '';

    final serviceLabel = _safe(rawServiceLabel);
    final clientName = _safe(rawClientName);
    final clientCity = _safe(rawClientCity);
    final clientPhone = _safe(rawClientPhone);
    final techName = _safe(rawTechName);
    final techCity = _safe(rawTechCity);
    final techPhone = _safe(rawTechPhone);

    final price = (orderData['priceQuoteMAD'] as num?)?.toDouble() ?? 0;
    final commission = (orderData['commissionMAD'] as num?)?.toDouble() ?? 0;
    final transportFee = (orderData['transportFeeMAD'] as num?)?.toDouble() ?? 0;
    final techEarnings = price - commission;

    final completedAt = orderData['completedAt'] as Timestamp?;
    final createdAt = orderData['createdAt'] as Timestamp?;
    final invoiceDate = completedAt != null
        ? _dateFormat.format(completedAt.toDate())
        : _dateFormat.format(DateTime.now());
    final orderDate =
        createdAt != null ? _dateFormat.format(createdAt.toDate()) : '-';
    final invoiceNumber = 'BRK-${requestId.substring(0, requestId.length >= 8 ? 8 : requestId.length).toUpperCase()}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('brikol.ma',
                        style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: brandGreen)),
                    pw.SizedBox(height: 4),
                    pw.Text('Services a domicile au Maroc',
                        style: pw.TextStyle(fontSize: 11, color: gold)),
                    pw.SizedBox(height: 4),
                    pw.Text('sallahapp-63361.web.app',
                        style: pw.TextStyle(fontSize: 10, color: mutedText)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: brandGreen,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FACTURE',
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                      pw.Text(invoiceNumber,
                          style: pw.TextStyle(
                              fontSize: 11, color: PdfColors.white)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 32),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                    child: _infoBlock('CLIENT',
                        [clientName, clientCity, clientPhone], brandGreen)),
                pw.SizedBox(width: 24),
                pw.Expanded(
                    child: _infoBlock('TECHNICIEN',
                        [techName, techCity, techPhone], brandGreen)),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightGreen,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _dateRow('Date de la commande', orderDate, mutedText),
                  _dateRow('Date de completion', invoiceDate, brandGreen),
                ],
              ),
            ),
            pw.SizedBox(height: 28),
            pw.Text('DETAIL DES PRESTATIONS',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: mutedText,
                    letterSpacing: 1)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#e6ebe7'), width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: brandGreen),
                  children: [
                    _tableCell('Description', isHeader: true),
                    _tableCell('Montant',
                        isHeader: true,
                        align: pw.Alignment.centerRight),
                  ],
                ),
                pw.TableRow(children: [
                  _tableCell(serviceLabel),
                  _tableCell(_numberFormat.format(price),
                      align: pw.Alignment.centerRight),
                ]),
                if (transportFee > 0)
                  pw.TableRow(children: [
                    _tableCell('Frais de deplacement'),
                    _tableCell(_numberFormat.format(transportFee),
                        align: pw.Alignment.centerRight),
                  ]),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 240,
                child: pw.Column(
                  children: [
                    _totalRow('Sous-total', price + transportFee, mutedText),
                    _totalRow('Commission Brikol.ma', commission, mutedText),
                    pw.Divider(color: PdfColor.fromHex('#e6ebe7')),
                    _totalRow('TOTAL CLIENT', price + transportFee,
                        darkText, isBold: true, fontSize: 14),
                    pw.SizedBox(height: 4),
                    _totalRow('Net technicien', techEarnings, brandGreen,
                        isBold: true),
                  ],
                ),
              ),
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColor.fromHex('#e6ebe7')),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Ce document vaut recu de prestation.',
                    style: pw.TextStyle(fontSize: 9, color: mutedText)),
                pw.Text('Brikol.ma -- Maroc',
                    style: pw.TextStyle(fontSize: 9, color: mutedText)),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _infoBlock(
      String title, List<String> lines, PdfColor titleColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: titleColor,
                letterSpacing: 1)),
        pw.SizedBox(height: 6),
        ...lines
            .where((l) => l.isNotEmpty && l != '-')
            .map((l) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child:
                      pw.Text(l, style: const pw.TextStyle(fontSize: 11)),
                )),
      ],
    );
  }

  static pw.Widget _dateRow(
      String label, String value, PdfColor valueColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 9, color: PdfColor.fromHex('#57685e'))),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: valueColor)),
      ],
    );
  }

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColor.fromHex('#0c1c13'),
        ),
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    double amount,
    PdfColor color, {
    bool isBold = false,
    double fontSize = 11,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
          pw.Text(_numberFormat.format(amount),
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }
}

/// Download button widget — used in orders_screen.dart
class InvoiceDownloadButton extends StatefulWidget {
  const InvoiceDownloadButton({
    super.key,
    required this.requestId,
    required this.orderData,
  });

  final String requestId;
  final Map<String, dynamic> orderData;

  @override
  State<InvoiceDownloadButton> createState() => _InvoiceDownloadButtonState();
}

class _InvoiceDownloadButtonState extends State<InvoiceDownloadButton> {
  bool _loading = false;

  Future<void> _tap() async {
    setState(() => _loading = true);
    try {
      String? url = widget.orderData['invoiceUrl'] as String?;
      if (url == null || url.isEmpty) {
        url = await InvoiceService.generateAndUpload(
          requestId: widget.requestId,
          orderData: widget.orderData,
        );
      }
      if (url.isNotEmpty) {
        await ul.launchUrl(Uri.parse(url),
            mode: ul.LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur facture: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasInvoice = (widget.orderData['invoiceUrl'] as String?) != null;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _tap,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.picture_as_pdf_rounded, size: 18),
        label: Text(_loading
            ? 'Generation...'
            : hasInvoice
                ? 'Telecharger la facture PDF'
                : 'Generer la facture PDF'),
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48)),
      ),
    );
  }
}