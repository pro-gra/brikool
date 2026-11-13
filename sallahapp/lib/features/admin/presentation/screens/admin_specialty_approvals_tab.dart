import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../models/technician_profile.dart';
import '../../../../models/technician_specialty.dart';
import '../../../../models/technician_skill.dart';

// ---------------------------------------------------------------------------
// AdminSpecialtyApprovalsTab
//
// Drop-in tab for AdminShell. Shows every pending specialty request across
// all technicians: technician name, specialty name, description, details,
// and diploma image (if provided). Admin can approve or reject (with reason).
//
// HOW TO INTEGRATE INTO admin_shell.dart:
//   1. Import this file.
//   2. Add 'Spécialités' to the _sections list:
//        (Icons.workspace_premium_rounded, 'Spécialités'),
//   3. Add a case to the body switch:
//        8 => AdminSpecialtyApprovalsTab(fs: _fs),
//      (shift the 'Clients' case from _ to 9)
// ---------------------------------------------------------------------------

class AdminSpecialtyApprovalsTab extends StatelessWidget {
  const AdminSpecialtyApprovalsTab({super.key, required this.fs});

  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TechnicianProfile>>(
      stream: fs.streamPendingSpecialtyRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Error(message: snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final techsWithPending = snapshot.data!;
        final totalPending = techsWithPending.fold<int>(
          0,
          (sum, t) => sum + t.specialties.where((s) => s.isPending).length,
        );

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Spécialités en attente ($totalPending)',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chaque spécialité doit être approuvée avant d\'être visible '
              'aux clients. Vérifiez la description, les détails et le diplôme.',
              style:
                  TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            if (totalPending == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 40, color: AppColors.success),
                      SizedBox(height: 10),
                      Text('✅ Aucune spécialité en attente',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              ...techsWithPending.expand((tech) => tech.specialties
                  .where((s) => s.isPending)
                  .map((s) => _SpecialtyApprovalCard(
                        tech: tech,
                        specialty: s,
                        fs: fs,
                      ))),
            // Also show recently reviewed for context
            _ReviewedSection(fs: fs),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Card for one pending specialty
// ---------------------------------------------------------------------------

class _SpecialtyApprovalCard extends StatefulWidget {
  const _SpecialtyApprovalCard({
    required this.tech,
    required this.specialty,
    required this.fs,
  });

  final TechnicianProfile tech;
  final TechnicianSpecialty specialty;
  final FirestoreService fs;

  @override
  State<_SpecialtyApprovalCard> createState() => _SpecialtyApprovalCardState();
}

class _SpecialtyApprovalCardState extends State<_SpecialtyApprovalCard> {
  bool _working = false;

  Future<void> _approve() async {
    setState(() => _working = true);
    try {
      await widget.fs.adminApproveSpecialtyV2(
        techId: widget.tech.techId,
        skillId: widget.specialty.skillId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${widget.specialty.skillLabel} approuvée pour ${widget.tech.fullName} ✓'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _working = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Refuser ${widget.specialty.skillLabel} pour ${widget.tech.fullName} ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le technicien verra cette raison dans son profil '
              'et pourra re-soumettre après correction.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Raison du refus *',
                hintText:
                    'Ex: Description trop vague, diplôme illisible, spécialité '
                    'non reconnue sur notre plateforme…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Refuser',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) return;

    setState(() => _working = true);
    try {
      await widget.fs.adminRejectSpecialtyV2(
        techId: widget.tech.techId,
        skillId: widget.specialty.skillId,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spécialité refusée')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _working = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  IconData _skillIcon(String skillId) {
    return TechnicianSkill.all
            .where((s) => s.id == skillId)
            .map((s) => s.icon)
            .firstOrNull ??
        Icons.build_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final specialty = widget.specialty;
    final tech = widget.tech;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.35), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Technician identity row ──
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: tech.profilePhotoUrl != null
                    ? NetworkImage(tech.profilePhotoUrl!)
                    : null,
                child: tech.profilePhotoUrl == null
                    ? Text(
                        tech.fullName.isNotEmpty ? tech.fullName[0] : '?',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tech.fullName,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800)),
                    Text(
                        '${tech.city} · ${tech.yearsExperience} ans d\'exp. · '
                        '${tech.jobsDone} travaux',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              // CIN indicator
              if (tech.cinPhotoUrl != null)
                GestureDetector(
                  onTap: () => _showImage(context, tech.cinPhotoUrl!, 'CIN'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.credit_card_rounded,
                            size: 12, color: AppColors.primary),
                        SizedBox(width: 3),
                        Text('CIN',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // ── Specialty details ──
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_skillIcon(specialty.skillId),
                    size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(specialty.skillLabel,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFFBF1DD),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('EN ATTENTE',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF9A6A00))),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          _SectionLabel('Description'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(specialty.description,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
          const SizedBox(height: 10),

          // Details
          _SectionLabel('Détails'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(specialty.details,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),

          // Diploma photo
          if (specialty.diplomaImageUrl != null) ...[
            const SizedBox(height: 10),
            _SectionLabel('Diplôme / Attestation'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _showImage(
                  context, specialty.diplomaImageUrl!, 'Diplôme'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  specialty.diplomaImageUrl!,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: double.infinity,
                    height: 80,
                    color: AppColors.background,
                    child: const Center(
                        child: Text('Image indisponible',
                            style: TextStyle(
                                color: AppColors.textMuted))),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.info_rounded, size: 13, color: AppColors.textMuted),
                SizedBox(width: 4),
                Text('Aucun diplôme joint',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // ── Action buttons ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: AppColors.danger),
                  onPressed: _working ? null : _reject,
                  child: const Text('Refuser'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _working ? null : _approve,
                  child: _working
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Approuver ✓'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showImage(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            InteractiveViewer(child: Image.network(url)),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recently reviewed section (approved + rejected — last 10)
// ---------------------------------------------------------------------------

class _ReviewedSection extends StatelessWidget {
  const _ReviewedSection({required this.fs});
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TechnicianProfile>>(
      stream: fs.streamAllTechnicians(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];

        // Collect all non-pending specialties across all technicians.
        final reviewed = <(TechnicianProfile, TechnicianSpecialty)>[];
        for (final t in all) {
          for (final s in t.specialties) {
            if (!s.isPending) reviewed.add((t, s));
          }
        }

        if (reviewed.isEmpty) return const SizedBox.shrink();

        // Sort newest first (by reviewedAt).
        reviewed.sort((a, b) {
          final ta = a.$2.reviewedAt;
          final tb = b.$2.reviewedAt;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

        final toShow = reviewed.take(10).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),
            Text('Récemment examinées (${reviewed.length})',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...toShow.map((pair) {
              final (tech, specialty) = pair;
              final isApproved = specialty.isApproved;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      isApproved
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 20,
                      color: isApproved ? AppColors.success : AppColors.danger,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${tech.fullName} — ${specialty.skillLabel}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          if (!isApproved &&
                              specialty.rejectionReason != null)
                            Text(
                              'Raison: ${specialty.rejectionReason}',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? AppColors.successLight
                            : AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isApproved ? 'Approuvée' : 'Refusée',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isApproved
                                ? AppColors.success
                                : AppColors.danger),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 0.3));
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Erreur: $message',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Extension helper
// ---------------------------------------------------------------------------
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iter = iterator;
    return iter.moveNext() ? iter.current : null;
  }
}