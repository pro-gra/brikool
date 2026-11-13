import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../client/presentation/bloc/language_cubit.dart';

class WalletDepositScreen extends StatefulWidget {
  const WalletDepositScreen({super.key, required this.currentBalance});
  final double currentBalance;

  @override
  State<WalletDepositScreen> createState() => _WalletDepositScreenState();
}

class _WalletDepositScreenState extends State<WalletDepositScreen> {
  int _selectedAmount = 100;
  final _customCtrl = TextEditingController();
  bool _showCustom = false;

  static const _quickAmounts = [50, 100, 200, 500];

  String get _refCode {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.length < 8) return 'BRK-${uid.toUpperCase()}';
    return 'BRK-${uid.substring(0, 8).toUpperCase()}';
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('wallet_deposit_title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('technicians')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snap) {
          final balance = (snap.data?.get('walletBalance') as num?)?.toDouble() ?? widget.currentBalance;
          final minimumBalance = FirestoreService.minBalanceToGoOnline;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Balance card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('current_balance'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('${balance.toStringAsFixed(2)} MAD',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      balance < minimumBalance ? t('insufficient_balance_online') : t('sufficient_balance_online'),
                      style: TextStyle(
                        color: balance < minimumBalance ? Colors.orangeAccent : Colors.greenAccent,
                        fontSize: 12, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // ── Amount picker ──
              Text(t('amount_to_deposit'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [
                  ..._quickAmounts.map((amount) {
                    final selected = _selectedAmount == amount && !_showCustom;
                    return GestureDetector(
                      onTap: () => setState(() { _selectedAmount = amount; _showCustom = false; }),
                      child: Container(
                        width: (MediaQuery.of(context).size.width - 60) / 2,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                        ),
                        child: Text('$amount MAD',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                                color: selected ? Colors.white : AppColors.textPrimary)),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () => setState(() => _showCustom = true),
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 60) / 2,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _showCustom ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _showCustom ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(t('other_amount'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                              color: _showCustom ? Colors.white : AppColors.textPrimary)),
                    ),
                  ),
                ],
              ),
              if (_showCustom) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) setState(() => _selectedAmount = n);
                  },
                  decoration: InputDecoration(
                    labelText: t('amount_mad'),
                    suffixText: 'MAD',
                    hintText: t('amount_example'),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              // ── Reference code ──
              Text(t('your_reference_code'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(t('reference_code_instruction'),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('reference_code'),
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(_refCode,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                                  letterSpacing: 2.5, color: AppColors.primary)),
                          const SizedBox(height: 4),
                          Text('${t('amount_label')}: $_selectedAmount MAD',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: '$_refCode — $_selectedAmount MAD'));
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t('code_amount_copied')),
                                duration: const Duration(seconds: 2)));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Stripe Pay Button ──
              _StripePayButton(amount: _selectedAmount, refCode: _refCode),
              const SizedBox(height: 20),
              // ── Manual methods ──
              Text(t('how_to_pay'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _InstructionCard(
                emoji: '🟠', name: 'WafaCash',
                subtitle: t('wafacash_subtitle'), color: const Color(0xFFFF6B00),
                steps: [t('wafacash_step_1'), t('wafacash_step_2'), t('payment_step_reference'), t('payment_step_cash'), t('payment_step_30_minutes')],
              ),
              const SizedBox(height: 10),
              _InstructionCard(
                emoji: '🔵', name: 'CashPlus',
                subtitle: t('cashplus_subtitle'), color: const Color(0xFF0055A4),
                steps: [t('cashplus_step_1'), t('cashplus_step_2'), t('payment_step_reference'), t('payment_step_cash'), t('payment_step_30_minutes')],
              ),
              const SizedBox(height: 10),
              _InstructionCard(
                emoji: '🏦', name: t('bank_transfer'),
                subtitle: t('bank_transfer_subtitle'), color: AppColors.textSecondary,
                steps: [t('bank_step_1'), t('bank_step_2'), t('bank_step_3'), t('bank_step_4')],
              ),
              const SizedBox(height: 20),
              _WhatsAppSupportCard(amount: _selectedAmount, refCode: _refCode),
              const SizedBox(height: 28),
              Text(t('transaction_history'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const _WalletHistory(),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STRIPE PAY BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _StripePayButton extends StatefulWidget {
  const _StripePayButton({required this.amount, required this.refCode});
  final int amount;
  final String refCode;

  @override
  State<_StripePayButton> createState() => _StripePayButtonState();
}

class _StripePayButtonState extends State<_StripePayButton> {
  bool _loading = false;

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('Non authentifié');

      final response = await http.post(
        Uri.parse('https://europe-west1-sallahapp-63361.cloudfunctions.net/stripeCheckout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amountMAD': widget.amount,
          'refCode': widget.refCode,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur serveur: ${response.body}');
      }

      final body = jsonDecode(response.body);
      final url = body['url'] as String;
await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF635BFF),
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
          shadowColor: const Color(0xFF635BFF).withOpacity(0.4),
        ),
        onPressed: _loading ? null : _pay,
        icon: _loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.credit_card_rounded, color: Colors.white, size: 20),
        label: Text(
          _loading ? 'Traitement…' : '💳 Payer ${widget.amount} MAD par carte',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WhatsApp support card
// ─────────────────────────────────────────────────────────────────────────────
class _WhatsAppSupportCard extends StatelessWidget {
  const _WhatsAppSupportCard({required this.amount, required this.refCode});
  final int amount;
  final String refCode;

  static const _phone = '8615736503627';

  Future<void> _openWhatsApp(BuildContext context, String techName, String uid) async {
    final t = context.read<LanguageCubit>().state.t;
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${t('at_time')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final message =
        '🔔 *${t('whatsapp_recharge_request')}*\n\n'
        '👤 *${t('name_label')}:* $techName\n'
        '🆔 *${t('id_label')}:* $uid\n'
        '🔑 *${t('reference_label')}:* $refCode\n'
        '💰 *${t('amount_label')}:* $amount MAD\n'
        '📅 *${t('date_label')}:* $dateStr\n\n'
        '✅ ${t('payment_completed_message')}\n'
        '${t('confirm_recharge_message')}';
    final url = Uri.parse('https://wa.me/$_phone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('whatsapp_unavailable'))));
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('whatsapp_open_error'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('technicians')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snap) {
        final techName = (snap.data?.data() as Map?)?['fullName'] as String? ?? t('technician');
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        return GestureDetector(
          onTap: () => _openWhatsApp(context, techName, uid),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF25D366).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.chat_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('confirm_recharge'),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800,
                              color: Color(0xFF1B5E20))),
                      const SizedBox(height: 2),
                      Text(
                        '${t('amount_label')}: $amount MAD · ${t('code_label')}: $refCode\n${t('send_receipt_instruction')}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(20)),
                        child: Text(t('open_whatsapp'),
                            style: const TextStyle(color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable instruction card
// ─────────────────────────────────────────────────────────────────────────────
class _InstructionCard extends StatefulWidget {
  const _InstructionCard({
    required this.emoji, required this.name, required this.subtitle,
    required this.color, required this.steps,
  });
  final String emoji, name, subtitle;
  final Color color;
  final List<String> steps;

  @override
  State<_InstructionCard> createState() => _InstructionCardState();
}

class _InstructionCardState extends State<_InstructionCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _open ? widget.color.withOpacity(0.4) : AppColors.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(widget.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        Text(widget.subtitle,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          if (_open) ...[
            Divider(height: 1, color: widget.color.withOpacity(0.2)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: widget.steps.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.12), shape: BoxShape.circle),
                          child: Center(
                            child: Text('${e.key + 1}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                                    color: widget.color)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(e.value,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transaction history
// ─────────────────────────────────────────────────────────────────────────────
class _WalletHistory extends StatelessWidget {
  const _WalletHistory();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wallet_transactions')
          .where('techId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(15)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
            child: Center(child: Text(t('no_transactions'),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          );
        }
        return Column(
          children: snap.data!.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final amount = (d['amountMAD'] as num?)?.toDouble() ?? 0;
            final note = d['note'] as String? ?? '';
            final ts = d['createdAt'] as Timestamp?;
            final isCredit = amount > 0;
            final isStripe = d['method'] == 'stripe';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isStripe
                        ? const Color(0xFF635BFF).withOpacity(0.3)
                        : AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isCredit ? AppColors.successLight : AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isStripe ? Icons.credit_card_rounded
                          : (isCredit ? Icons.add_rounded : Icons.remove_rounded),
                      color: isCredit ? AppColors.success : AppColors.danger, size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.isEmpty
                              ? (isCredit ? t('wallet_recharge') : t('commission_deducted'))
                              : note,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        if (ts != null)
                          Text(_fmt(ts.toDate()),
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text(
                    '${isCredit ? '+' : ''}${amount.toStringAsFixed(0)} MAD',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: isCredit ? AppColors.success : AppColors.danger),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}