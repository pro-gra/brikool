import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';

/// Company wallet top-up — same mechanics as the technician one, just
/// higher preset amounts since commission on a single big project can
/// be several hundred MAD (8% of a 10,000+ MAD job).
class CompanyWalletDepositScreen extends StatefulWidget {
  const CompanyWalletDepositScreen({super.key, required this.currentBalance});

  final double currentBalance;

  @override
  State<CompanyWalletDepositScreen> createState() => _CompanyWalletDepositScreenState();
}

class _CompanyWalletDepositScreenState extends State<CompanyWalletDepositScreen> {
  final _firestoreService = FirestoreService();
  double _selectedAmount = 500;
  String _method = 'in_app';
  bool _loading = false;
  String? _error;

  static const List<double> _presetAmounts = [500, 1000, 2500, 5000];

  Future<void> _deposit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Mock payment confirmation — same test-phase pattern as the
      // technician wallet, real gateway to be wired server-side later.
      await _firestoreService.companyDepositToWallet(
        companyId: user.uid,
        amountMad: _selectedAmount,
        method: _method,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Le dépôt a échoué. Réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Portefeuille entreprise')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Solde actuel', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${widget.currentBalance.toStringAsFixed(0)} MAD',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
                child: const Row(
                  children: [
                    Icon(Icons.info_rounded, color: AppColors.primaryDark, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'La commission (8% du devis) est débitée automatiquement quand vous démarrez un chantier avec le code du client. Un solde insuffisant bloque le démarrage.',
                          style: TextStyle(color: AppColors.primaryDark, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Montant à déposer',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presetAmounts.map((amount) {
                  final selected = _selectedAmount == amount;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAmount = amount),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                      ),
                      child: Text('${amount.toStringAsFixed(0)} MAD',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : AppColors.textPrimary,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text('Méthode de paiement',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              _MethodTile(
                  label: 'Paiement in-app (carte)',
                  value: 'in_app',
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v)),
              _MethodTile(
                  label: 'Virement bancaire',
                  value: 'bank_transfer',
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v)),
              _MethodTile(
                  label: 'Chèque',
                  value: 'cheque',
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v)),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: _loading ? null : _deposit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Déposer ${_selectedAmount.toStringAsFixed(0)} MAD'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile(
      {required this.label, required this.value, required this.groupValue, required this.onChanged});
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      groupValue: groupValue,
      activeColor: AppColors.primary,
      title: Text(label, style: const TextStyle(fontSize: 13.5)),
      onChanged: (v) => onChanged(v!),
    );
  }
}