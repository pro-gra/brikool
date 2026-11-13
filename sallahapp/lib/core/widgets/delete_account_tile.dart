import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/auth_service.dart';

class DeleteAccountTile extends StatelessWidget {
  const DeleteAccountTile({
    super.key,
    required this.uid,
    required this.userType,
    required this.fs,
  });
  final String uid;
  final String userType;
  final FirestoreService fs;

  static const _reasons = [
    'Je n\'utilise plus l\'application',
    'J\'ai des problèmes avec le service',
    'Problème de confidentialité',
    'Je crée un nouveau compte',
    'Autre raison',
  ];

  Future<bool> _hasActiveOrder(BuildContext context) async {
    try {
      if (userType == 'technician') {
        final job = await fs.streamActiveJobForTechnician(uid).first;
        return job != null;
      } else {
        final order = await fs.getActiveRequestForClient(uid);
        return order != null;
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: fs.streamDeletionRequest(uid),
      builder: (context, snap) {
        final status = snap.data?['status'] as String?;

        if (status == 'pending') {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.hourglass_top_rounded, size: 20, color: Colors.orange),
            title: const Text('Suppression en attente',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.orange)),
            subtitle: const Text('Votre demande est en cours d\'examen par l\'admin.',
                style: TextStyle(fontSize: 11.5)),
            trailing: TextButton(
              onPressed: () async {
                try {
                  await fs.cancelDeletionRequest(uid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demande annulée ✓')));
                  }
                } catch (_) {}
              },
              child: const Text('Annuler', style: TextStyle(fontSize: 12, color: AppColors.danger)),
            ),
          );
        }

        if (status == 'approved') {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await AuthService().signOut();
          });
          return const SizedBox.shrink();
        }

        return ListTile(
          dense: true,
          leading: const Icon(Icons.delete_forever_rounded, size: 20, color: AppColors.danger),
          title: const Text('Supprimer mon compte',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
          subtitle: const Text('Demande soumise à l\'admin pour validation',
              style: TextStyle(fontSize: 11.5)),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          onTap: () => _onTap(context),
        );
      },
    );
  }

  Future<void> _onTap(BuildContext context) async {
    // ← check active order
    final hasActive = await _hasActiveOrder(context);
    if (!context.mounted) return;

    if (hasActive) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.warning_rounded, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Text('Commande en cours', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
          content: Text(
            userType == 'technician'
                ? 'Vous avez une commande en cours. Terminez ou annulez-la avant de supprimer votre compte.'
                : 'Vous avez une commande en cours. Terminez ou annulez-la avant de supprimer votre compte.',
            style: const TextStyle(fontSize: 13.5, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
      return;
    }

    _showDialog(context);
  }

  Future<void> _showDialog(BuildContext context) async {
    String selected = '';
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.warning_rounded, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Text('Supprimer le compte', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '⚠️ Action irréversible. Un administrateur devra approuver votre demande avant la suppression définitive.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.dangerDark, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Pourquoi souhaitez-vous partir ?',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ..._reasons.map((reason) => RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(reason, style: const TextStyle(fontSize: 12.5)),
                  value: reason,
                  groupValue: selected,
                  activeColor: AppColors.danger,
                  onChanged: (v) => setState(() => selected = v ?? ''),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text('Envoyer la demande'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selected.isNotEmpty) {
      try {
        await fs.requestAccountDeletion(uid: uid, reason: selected, userType: userType);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Demande envoyée ✓ — Traitement sous 24h par l\'admin'),
            backgroundColor: AppColors.primary,
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.danger,
          ));
        }
      }
    }
  }
}