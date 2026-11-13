// ================================================================
// PASTE THESE WIDGETS into your technician home/job screen
// These add: cancel order button + rate client bottom sheet
// ================================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';

/// Cancel button shown on active technician jobs (non-planned only).
/// Shows a reason dialog before cancelling.
class TechCancelButton extends StatefulWidget {
  const TechCancelButton({
    super.key,
    required this.requestId,
    required this.techId,
    required this.status,
  });

  final String requestId;
  final String techId;
  final String status;

  @override
  State<TechCancelButton> createState() => _TechCancelButtonState();
}

class _TechCancelButtonState extends State<TechCancelButton> {
  bool _cancelling = false;
  final _fs = FirestoreService();

  Future<void> _cancel() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le client sera notifié de votre annulation.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Raison (urgence personnelle, panne…)',
                labelText: 'Raison *',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Retour')),
          TextButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirmer',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) return;

    setState(() => _cancelling = true);
    try {
      await _fs.techCancelRequest(
        requestId: widget.requestId,
        techId: widget.techId,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commande annulée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _cancelling = false);
      }
    }
  }

  // Only show on non-started orders
  bool get _canCancel =>
      ['accepted', 'pending'].contains(widget.status);

  @override
  Widget build(BuildContext context) {
    if (!_canCancel) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _cancelling ? null : _cancel,
        icon: _cancelling
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.cancel_outlined, size: 17),
        label:
            Text(_cancelling ? 'Annulation…' : 'Annuler la commande'),
        style:
            OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
      ),
    );
  }
}

/// Bottom sheet that lets the technician rate the client after
/// the job is completed.
class RateClientSheet extends StatefulWidget {
  const RateClientSheet({
    super.key,
    required this.requestId,
    required this.clientId,
    required this.clientName,
  });

  final String requestId;
  final String clientId;
  final String clientName;

  @override
  State<RateClientSheet> createState() => _RateClientSheetState();
}

class _RateClientSheetState extends State<RateClientSheet> {
  int _stars = 5;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  final _fs = FirestoreService();

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await _fs.rateTechnicianRatesClient(
        requestId: widget.requestId,
        clientId: widget.clientId,
        stars: _stars,
        comment: _commentCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Merci pour votre évaluation ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Évaluez le client',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Comment s\'est passée votre collaboration avec ${widget.clientName} ?',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // Star rating
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final filled = i < _stars;
                return GestureDetector(
                  onTap: () => setState(() => _stars = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 40,
                      color: filled ? AppColors.gold : AppColors.border,
                    ),
                  ),
                );
              }),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                ['', 'Très mauvais', 'Mauvais', 'Correct',
                 'Bien', 'Excellent'][_stars],
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _stars >= 4
                        ? AppColors.success
                        : _stars >= 3
                            ? AppColors.gold
                            : AppColors.danger),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Comment (optional)
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText:
                  'Client ponctuel, bien communiqué… (optionnel)',
              labelText: 'Commentaire',
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Envoyer mon évaluation'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper — call this when a job is completed to show the rate sheet.
void showRateClientSheet(BuildContext context,
    {required String requestId,
    required String clientId,
    required String clientName}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (_) => RateClientSheet(
      requestId: requestId,
      clientId: clientId,
      clientName: clientName,
    ),
  );
}