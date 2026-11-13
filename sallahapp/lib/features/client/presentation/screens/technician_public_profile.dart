import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../models/technician_profile.dart';
import '../../../../models/technician_specialty.dart';
import '../../../../models/technician_skill.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point — call from anywhere to show the profile as a modal.
//
// allowDirectOrder: false → profile + reviews only (inside active order)
// allowDirectOrder: true  → profile + "Commander directement" CTA
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showTechnicianPublicProfile(
  BuildContext context,
  String techId, {
  bool allowDirectOrder = true,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TechnicianPublicProfileSheet(
      techId: techId,
      allowDirectOrder: allowDirectOrder,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-page version — push via Navigator if needed
// ─────────────────────────────────────────────────────────────────────────────
class TechnicianPublicProfileScreen extends StatelessWidget {
  const TechnicianPublicProfileScreen({
    super.key,
    required this.techId,
    this.allowDirectOrder = true,
  });

  final String techId;
  final bool allowDirectOrder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: TechnicianPublicProfileSheet(
        techId: techId,
        allowDirectOrder: allowDirectOrder,
        asFullPage: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Core widget — renders as bottom sheet OR full page
// ─────────────────────────────────────────────────────────────────────────────
class TechnicianPublicProfileSheet extends StatelessWidget {
  const TechnicianPublicProfileSheet({
    super.key,
    required this.techId,
    required this.allowDirectOrder,
    this.asFullPage = false,
  });

  final String techId;
  final bool allowDirectOrder;
  final bool asFullPage;

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    final body = StreamBuilder<TechnicianProfile?>(
      stream: fs.streamTechnicianProfile(techId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ProfileError(message: snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const _ProfileSkeleton();
        }
        final profile = snapshot.data;
        if (profile == null) {
          return const _ProfileError(message: 'Technicien introuvable.');
        }

        return _ProfileBody(
          profile: profile,
          fs: fs,
          allowDirectOrder: allowDirectOrder,
          asFullPage: asFullPage,
        );
      },
    );

    if (asFullPage) return SafeArea(child: body);

    // Bottom sheet wrapper
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: body,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main scrollable content
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.fs,
    required this.allowDirectOrder,
    required this.asFullPage,
  });

  final TechnicianProfile profile;
  final FirestoreService fs;
  final bool allowDirectOrder;
  final bool asFullPage;

  @override
  Widget build(BuildContext context) {
    final approvedSpecialties =
        profile.specialties.where((s) => s.isApproved).toList();

    return CustomScrollView(
      slivers: [
        // ── drag handle / back button ──────────────────────────────────────
        SliverToBoxAdapter(
          child: asFullPage
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                )
              : Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
        ),

        // ── hero header ───────────────────────────────────────────────────
        SliverToBoxAdapter(child: _HeroHeader(profile: profile)),

        // ── stats row ─────────────────────────────────────────────────────
        SliverToBoxAdapter(child: _StatsRow(profile: profile)),

        // ── approved specialties ──────────────────────────────────────────
        if (approvedSpecialties.isNotEmpty)
          SliverToBoxAdapter(
            child: _SpecialtiesSection(specialties: approvedSpecialties),
          ),

        // ── bio / about ───────────────────────────────────────────────────
        if (profile.bio.isNotEmpty)
          SliverToBoxAdapter(child: _AboutSection(bio: profile.bio)),

        // ── client reviews ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _ReviewsSection(techId: profile.techId, fs: fs),
        ),

        // ── CTA ───────────────────────────────────────────────────────────
        if (allowDirectOrder)
          SliverToBoxAdapter(
            child: _DirectOrderCTA(profile: profile),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero header: avatar, name, rating, city, verified, online status
// ─────────────────────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.profile});
  final TechnicianProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Avatar with verified badge
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: profile.profilePhotoUrl != null
                    ? NetworkImage(profile.profilePhotoUrl!)
                    : null,
                child: profile.profilePhotoUrl == null
                    ? Text(
                        profile.fullName.isNotEmpty
                            ? profile.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary),
                      )
                    : null,
              ),
              if (profile.isVerified)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B4EAE),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.verified_rounded,
                      size: 14, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            profile.fullName.isEmpty ? 'Technicien' : profile.fullName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // City + verified label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text(
                profile.city.isEmpty ? 'Maroc' : profile.city,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EDFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Vérifié',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2B4EAE)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (i) {
                final filled = i < profile.rating.round();
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 20,
                  color: filled ? AppColors.gold : AppColors.border,
                );
              }),
              const SizedBox(width: 6),
              Text(
                profile.rating.toStringAsFixed(1),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),

          // Online indicator
          if (profile.isOnline) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.success),
                  SizedBox(width: 5),
                  Text('Disponible maintenant',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats: jobs done, years experience, rating
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});
  final TechnicianProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _StatCard(
            value: '${profile.jobsDone}',
            label: 'Travaux',
            icon: Icons.build_rounded,
          ),
          const SizedBox(width: 10),
          _StatCard(
            value: profile.yearsExperience > 0
                ? '${profile.yearsExperience} ans'
                : '—',
            label: 'Expérience',
            icon: Icons.workspace_premium_rounded,
          ),
          const SizedBox(width: 10),
          _StatCard(
            value: profile.rating.toStringAsFixed(1),
            label: 'Note / 5',
            icon: Icons.star_rounded,
            iconColor: AppColors.gold,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.iconColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Approved specialties as chips
// ─────────────────────────────────────────────────────────────────────────────
class _SpecialtiesSection extends StatelessWidget {
  const _SpecialtiesSection({required this.specialties});
  final List<TechnicianSpecialty> specialties;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spécialités',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specialties.map((s) {
              final match = TechnicianSkill.all
                  .where((sk) => sk.id == s.skillId)
                  .toList();
              final icon =
                  match.isNotEmpty ? match.first.icon : Icons.build_rounded;

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(s.skillLabel,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bio / about section
// ─────────────────────────────────────────────────────────────────────────────
class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.bio});
  final String bio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('À propos',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(bio,
                style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reviews list — streams from technicians/{id}/reviews
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.techId, required this.fs});
  final String techId;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.streamTechnicianReviews(techId),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Avis clients (${reviews.length})',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (reviews.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.rate_review_outlined,
                          size: 32, color: AppColors.textMuted),
                      SizedBox(height: 8),
                      Text('Aucun avis pour l\'instant',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                )
              else
                ...reviews.take(10).map((r) => _ReviewTile(review: r)),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final stars = (review['stars'] as num?)?.toInt() ?? 5;
    final comment = review['comment'] as String? ?? '';
    final clientName = review['clientName'] as String? ?? 'Client';
    final createdAt = review['createdAt'];
    final date = createdAt is Timestamp
        ? DateFormat('dd/MM/yyyy').format(createdAt.toDate())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  clientName.isNotEmpty
                      ? clientName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clientName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text(date,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: i < stars ? AppColors.gold : AppColors.border,
                  );
                }),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '« $comment »',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Direct order CTA
// ─────────────────────────────────────────────────────────────────────────────
class _DirectOrderCTA extends StatelessWidget {
  const _DirectOrderCTA({required this.profile});
  final TechnicianProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppColors.primary,
          ),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
          label: Text(
            'Commander avec ${profile.fullName.split(' ').first}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading skeleton
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement du profil…',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_rounded,
                size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Profil indisponible',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper used by orders_screen.dart — do NOT remove
// ─────────────────────────────────────────────────────────────────────────────
