import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/widgets/qr_scanner_screen.dart';
import '../../../../models/big_service_category.dart';
import '../../../company/presentation/screens/company_chat_screen.dart';

/// The client's own submitted "Grands Services" project requests 鈥?
/// live status from quote to completed invoice. This is also embedded
/// directly (as ProjectRequestsList) inside the regular Orders screen
/// as a second tab, so both kinds of orders live in one history.
class MyProjectRequestsScreen extends StatelessWidget {
  const MyProjectRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Mes demandes de devis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: const SafeArea(child: ProjectRequestsList()),
    );
  }
}

/// Reusable list body (no Scaffold/AppBar) 鈥?the client's big-project
/// requests, newest first. Used standalone above and as a tab inside
/// OrdersScreen.
class ProjectRequestsList extends StatelessWidget {
  const ProjectRequestsList({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final fs = FirestoreService();
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.streamMyQuoteRequests(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.request_quote_rounded,
                      size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  const Text('Aucune demande pour le moment',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(
                      'Vos demandes de devis pour les grands projets\nappara卯tront ici.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          itemCount: requests.length,
          itemBuilder: (context, i) => _RequestCard(request: requests[i], fs: fs),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.fs});
  final Map<String, dynamic> request;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    final status = request['status'] as String? ?? 'new';
    final companyName = request['companyName'] as String? ?? 'Entreprise';
    final categoryId = request['categoryId'] as String?;
    final category = categoryId != null ? BigServiceCategory.byId(categoryId) : null;
    final createdAt = request['createdAt'];
    final date = createdAt is Timestamp ? DateFormat('dd/MM/yyyy').format(createdAt.toDate()) : '';
    final quotedPrice = (request['quotedPriceMAD'] as num?)?.toDouble();

    final (statusColor, statusBg, statusLabel) = switch (status) {
      'quoted' => (const Color(0xFF2B4EAE), const Color(0xFFE8EDFB), 'Devis re莽u'),
      'confirmed' => (AppColors.gold, AppColors.gold.withOpacity(0.14), 'Confirm茅'),
      'in_progress' => (const Color(0xFFB3541E), const Color(0xFFFBEADD), 'En cours'),
      'completed' => (AppColors.primary, AppColors.primaryLight, 'Termin茅'),
      'declined' => (AppColors.textMuted, AppColors.background, 'Refus茅'),
      _ => (AppColors.danger, AppColors.dangerLight, 'En attente'),
    };

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProjectRequestDetailScreen(requestId: request['_id'] as String))),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: status == 'quoted' ? const Color(0xFF2B4EAE).withOpacity(0.4) : AppColors.border,
                width: status == 'quoted' ? 1.4 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration:
                        BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                  ),
                  const Spacer(),
                  Text(date, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 8),
              Text(companyName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              if (category != null)
                Text(category.label,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (quotedPrice != null) ...[
                const SizedBox(height: 8),
                Text('${quotedPrice.toStringAsFixed(0)} MAD',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
              if (status == 'quoted') ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF2B4EAE)),
                    SizedBox(width: 5),
                    Text('Touchez pour accepter ou refuser',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2B4EAE))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================================
// DETAIL 鈥?status tracker, quote confirm/decline, OTP, invoice
// =================================================================
class ProjectRequestDetailScreen extends StatelessWidget {
  const ProjectRequestDetailScreen({super.key, required this.requestId});
  final String requestId;

  static const _steps = [
    ('new', 'Envoy茅e'),
    ('quoted', 'Devis re莽u'),
    ('confirmed', 'Confirm茅'),
    ('in_progress', 'En cours'),
    ('completed', 'Termin茅'),
  ];

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Ma demande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Discuter',
            onPressed: () async {
              final request = await fs.streamQuoteRequest(requestId).first;
              final companyName = request?['companyName'] as String? ?? 'Entreprise';
              if (context.mounted) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        CompanyChatScreen(requestId: requestId, title: companyName)));
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: fs.streamQuoteRequest(requestId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final request = snapshot.data;
          if (request == null) {
            return const Center(child: Text('Demande introuvable.'));
          }
          final status = request['status'] as String? ?? 'new';

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Text('R茅f. ${requestId.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.6)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D3576).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('PROJET PROFESSIONNEL',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1D3576),
                              letterSpacing: 0.4)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (status != 'declined') _StatusTimeline(status: status, steps: _steps),
                if (status == 'declined')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                    child: const Row(
                      children: [
                        Icon(Icons.cancel_rounded, color: AppColors.textMuted),
                        SizedBox(width: 10),
                        Text('Devis refus茅', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                _DetailsCard(request: request),
                if (status == 'quoted') ...[
                  const SizedBox(height: 16),
                  _QuoteDecisionCard(requestId: requestId, request: request, fs: fs),
                ],
                if (status == 'confirmed' || status == 'in_progress') ...[
                  const SizedBox(height: 16),
                  _OtpCard(
                      otp: request['otpCode'] as String? ?? '----',
                      status: status,
                      requestId: requestId),
                ],
                if (status == 'completed') ...[
                  const SizedBox(height: 16),
                  _InvoiceCard(request: request),
                  if (request['clientRated'] != true) ...[
                    const SizedBox(height: 16),
                    _RateCompanyCard(requestId: requestId, request: request, fs: fs),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status, required this.steps});
  final String status;
  final List<(String, String)> steps;

  static const _navy = Color(0xFF1D3576);

  @override
  Widget build(BuildContext context) {
    final currentIndex = steps.indexWhere((s) => s.$1 == status);
    return Column(
      children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              final passed = (i - 1) ~/ 2 < currentIndex;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 3,
                  color: passed ? _navy : AppColors.border,
                ),
              );
            }
            final stepIndex = i ~/ 2;
            final done = stepIndex < currentIndex;
            final active = stepIndex == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active ? _navy : AppColors.surface,
                border: Border.all(color: done || active ? _navy : AppColors.border, width: 1.8),
                boxShadow: active
                    ? [BoxShadow(color: _navy.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)]
                    : null,
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : active
                      ? const Center(
                          child: SizedBox(
                              width: 9,
                              height: 9,
                              child: DecoratedBox(
                                  decoration:
                                      BoxDecoration(color: Colors.white, shape: BoxShape.circle))))
                      : null,
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(steps.length, (i) {
            final done = i < currentIndex;
            final active = i == currentIndex;
            return Expanded(
              child: Text(
                steps[i].$2,
                textAlign: i == 0
                    ? TextAlign.left
                    : (i == steps.length - 1 ? TextAlign.right : TextAlign.center),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: done || active ? _navy : AppColors.textMuted,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.request});
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final companyName = request['companyName'] as String? ?? '';
    final categoryId = request['categoryId'] as String?;
    final category = categoryId != null ? BigServiceCategory.byId(categoryId) : null;
    final description = request['description'] as String? ?? '';
    final address = request['address'] as String? ?? request['city'] as String? ?? '';
    final preferredDate = request['preferredDate'];
    final preferredTime = request['preferredTime'] as String? ?? '';
    final scheduleLabel = preferredDate is Timestamp
        ? '${DateFormat('dd/MM/yyyy').format(preferredDate.toDate())}${preferredTime.isNotEmpty ? ' 脿 $preferredTime' : ''}'
        : '';
    final mediaUrls = (request['mediaUrls'] as List?)?.cast<String>() ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(companyName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (category != null)
            Text(category.label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          if (scheduleLabel.isNotEmpty) _InfoRow(icon: Icons.event_rounded, text: scheduleLabel),
          if (address.isNotEmpty) _InfoRow(icon: Icons.location_on_rounded, text: address),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 12.5, height: 1.4)),
          ],
          if (mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mediaUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(mediaUrls[i], width: 64, height: 64, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}

class _QuoteDecisionCard extends StatefulWidget {
  const _QuoteDecisionCard({required this.requestId, required this.request, required this.fs});
  final String requestId;
  final Map<String, dynamic> request;
  final FirestoreService fs;

  @override
  State<_QuoteDecisionCard> createState() => _QuoteDecisionCardState();
}

class _QuoteDecisionCardState extends State<_QuoteDecisionCard> {
  bool _loading = false;

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await widget.fs.clientConfirmQuote(widget.requestId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('脡chec: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _decline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser ce devis ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, refuser')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await widget.fs.clientDeclineQuote(widget.requestId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('脡chec: $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = (widget.request['quotedPriceMAD'] as num?)?.toDouble() ?? 0;
    final notes = widget.request['quotedNotes'] as String? ?? '';
    final materialsIncluded = widget.request['materialsIncluded'] as bool? ?? true;
    final durationValue = (widget.request['durationValue'] as num?)?.toDouble();
    final durationUnit = widget.request['durationUnit'] as String? ?? '';
    final teamSize = (widget.request['teamSize'] as num?)?.toInt() ?? 0;
    final depositPercent = (widget.request['depositPercent'] as num?)?.toDouble() ?? 0;
    final warrantyMonths = (widget.request['warrantyMonths'] as num?)?.toInt() ?? 0;
    final validityDays = (widget.request['validityDays'] as num?)?.toInt() ?? 7;
    final lineItems = (widget.request['lineItems'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
    final quotedAt = widget.request['quotedAt'];
    final daysLeft = quotedAt is Timestamp
        ? validityDays -
            DateTime.now().difference(quotedAt.toDate()).inDays
        : validityDays;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B4EAE), Color(0xFF1D3576)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Devis re莽u',
                  style: TextStyle(
                      fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w600)),
              if (daysLeft <= 3)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(
                      daysLeft <= 0 ? 'Expire aujourd\'hui' : 'Expire dans $daysLeft j',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${price.toStringAsFixed(0)} MAD',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 14),

          // ---- Key facts grid ----
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuoteFactChip(
                icon: materialsIncluded ? Icons.check_circle_rounded : Icons.cancel_rounded,
                label: materialsIncluded ? 'Mat茅riaux inclus' : 'Mat茅riaux non inclus',
              ),
              if (durationValue != null && durationValue > 0)
                _QuoteFactChip(
                  icon: Icons.schedule_rounded,
                  label:
                      '${durationValue % 1 == 0 ? durationValue.toStringAsFixed(0) : durationValue.toStringAsFixed(1)} $durationUnit',
                ),
              if (teamSize > 0)
                _QuoteFactChip(
                    icon: Icons.groups_rounded, label: '$teamSize technicien${teamSize > 1 ? 's' : ''}'),
              if (warrantyMonths > 0)
                _QuoteFactChip(
                    icon: Icons.verified_user_rounded, label: 'Garantie $warrantyMonths mois'),
              if (depositPercent > 0)
                _QuoteFactChip(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Acompte ${depositPercent.toStringAsFixed(0)}%'),
            ],
          ),

          if (lineItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('D茅tail des co没ts',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 8),
                  ...lineItems.map((item) {
                    final label = item['label'] as String? ?? '';
                    final amount = (item['amountMAD'] as num?)?.toDouble() ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(label,
                              style: const TextStyle(fontSize: 12.5, color: Colors.white)),
                          Text('${amount.toStringAsFixed(0)} MAD',
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(notes, style: const TextStyle(fontSize: 12.5, color: Colors.white, height: 1.4)),
          ],
          const SizedBox(height: 8),
          const Text('Prix fixe 鈥?sans n茅gociation.',
              style: TextStyle(fontSize: 11, color: Colors.white60)),
          if (widget.request['quoteDocumentUrl'] != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => launchUrl(Uri.parse(widget.request['quoteDocumentUrl'] as String)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('T茅l茅charger le devis (PDF)',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withOpacity(0.6))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      side: const BorderSide(color: Colors.white54),
                      foregroundColor: Colors.white),
                  onPressed: _loading ? null : _decline,
                  child: const Text('Refuser'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1D3576)),
                  onPressed: _loading ? null : _confirm,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Confirmer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteFactChip extends StatelessWidget {
  const _QuoteFactChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

class _OtpCard extends StatelessWidget {
  const _OtpCard({required this.otp, required this.status, required this.requestId});
  final String otp;
  final String status;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    final started = status == 'in_progress';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.4),
      ),
      child: Column(
        children: [
          Icon(started ? Icons.construction_rounded : Icons.qr_code_rounded,
              size: 28, color: AppColors.gold),
          const SizedBox(height: 10),
          Text(
              started
                  ? 'L\'entreprise a d茅marr茅 le chantier'
                  : 'Donnez ce code 脿 l\'entreprise sur place',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          if (!started) ...[
            const SizedBox(height: 14),
            Text(otp,
                style: const TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 10)),
            const SizedBox(height: 14),
            QrImageView(data: buildOtpQrData(requestId, otp), size: 140, backgroundColor: Colors.white),
            const SizedBox(height: 8),
            const Text('Ou faites scanner ce QR code',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _RateCompanyCard extends StatefulWidget {
  const _RateCompanyCard({required this.requestId, required this.request, required this.fs});
  final String requestId;
  final Map<String, dynamic> request;
  final FirestoreService fs;

  @override
  State<_RateCompanyCard> createState() => _RateCompanyCardState();
}

class _RateCompanyCardState extends State<_RateCompanyCard> {
  int _stars = 5;
  final _reviewController = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _submitting = true);
    try {
      await widget.fs.submitCompanyReview(
        companyId: widget.request['companyId'] as String,
        requestId: widget.requestId,
        clientId: user.uid,
        clientName: widget.request['clientName'] as String? ?? 'Client',
        stars: _stars,
        reviewText: _reviewController.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('脡chec: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyName = widget.request['companyName'] as String? ?? 'l\'entreprise';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comment s\'est pass茅 le projet avec $companyName ?',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) {
              final filled = i < _stars;
              return GestureDetector(
                onTap: () => setState(() => _stars = i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 32,
                    color: AppColors.gold,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reviewController,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Un commentaire pour les futurs clients ? (optionnel)'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Envoyer mon avis'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.request});
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final invoiceId = request['invoiceId'] as String? ?? '';
    final invoiceUrl = request['invoiceUrl'] as String?;
    final price = (request['quotedPriceMAD'] as num?)?.toDouble() ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.task_alt_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Projet termin茅', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Facture N掳 $invoiceId', style: const TextStyle(fontSize: 12.5)),
          Text('${price.toStringAsFixed(0)} MAD',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (invoiceUrl != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse(invoiceUrl)),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                label: const Text('T茅l茅charger la facture (PDF)'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}