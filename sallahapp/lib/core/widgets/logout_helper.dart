import 'package:flutter/material.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_theme.dart';

/// كيتحقق من active order قبل logout
/// استعملو فـ profile client وtechnician
Future<void> signOutWithCheck({
  required BuildContext context,
  required String uid,
  required String userType, // 'client' or 'technician'
  required FirestoreService fs,
  required String Function(String) t,
}) async {
  // 1. Check active order
  bool hasActive = false;
  try {
    if (userType == 'technician') {
      final job = await fs.streamActiveJobForTechnician(uid).first;
      hasActive = job != null;
    } else {
      final order = await fs.getActiveRequestForClient(uid);
      hasActive = order != null;
    }
  } catch (_) {}

  if (!context.mounted) return;

  if (hasActive) {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_rounded, color: AppColors.danger, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              t('logout_active_order_title'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ]),
        content: Text(
          t('logout_active_order_body'),
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('ok')),
          ),
        ],
      ),
    );
    return;
  }

  // 2. Confirm logout
  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('logout_confirm_title')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t('logout_confirm_no')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t('logout_confirm_yes')),
        ),
      ],
    ),
  );
  if (confirmed == true) await AuthService().signOut();
}