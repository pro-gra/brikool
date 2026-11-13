import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

/// A shared camera scanner for the job-start OTP QR codes generated
/// on the client's side. Expects codes in the exact format written by
/// [buildOtpQrData]: "SALLAH-OTP|{requestId}|{otp}" — validates the
/// requestId matches the job actually being started (so scanning the
/// wrong client's screen by mistake is caught immediately), then pops
/// with just the 4-digit code so the caller can reuse its existing
/// manual-entry submit logic unchanged.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, required this.expectedRequestId});
  final String expectedRequestId;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

/// Builds the exact string encoded in the client's OTP QR code.
String buildOtpQrData(String requestId, String otp) => 'SALLAH-OTP|$requestId|$otp';

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _handled = false;
  String? _error;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final parts = raw.split('|');
    if (parts.length != 3 || parts[0] != 'SALLAH-OTP') {
      setState(() => _error = 'Ce QR code ne correspond pas à SALLAH.');
      return;
    }
    if (parts[1] != widget.expectedRequestId) {
      setState(() => _error = 'Ce QR code appartient à une autre commande.');
      return;
    }
    _handled = true;
    Navigator.of(context).pop(parts[2]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner le QR du client'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Column(
              children: [
                const Text(
                    'Cadrez le QR code affiché sur le téléphone du client',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13)),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}