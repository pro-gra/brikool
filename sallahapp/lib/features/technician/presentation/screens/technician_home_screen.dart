import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/widgets/qr_scanner_screen.dart';
import '../../../../models/technician_profile.dart';
import '../../../../models/technician_skill.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/storage_service.dart';
import '../../../client/presentation/screens/chat_screen.dart';
import '../../../client/presentation/screens/orders_screen.dart' show CallSupportButton;
import '../../../client/presentation/screens/ai_assistant_bubble.dart';
import '../../../client/presentation/bloc/language_cubit.dart';

class TechnicianHomeScreen extends StatefulWidget {
  const TechnicianHomeScreen({super.key, required this.profile});
  final TechnicianProfile profile;
  @override
  State<TechnicianHomeScreen> createState() => _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen> {
  final _firestoreService = FirestoreService();
  bool _busy = false;

  Future<void> _toggleOnline(TechnicianProfile profile, bool value) async {
    final t = context.read<LanguageCubit>().state.t;
    if (value && profile.isSuspended) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('tech_suspended_title')),
          content: Text(t('tech_suspended_body'), style: const TextStyle(fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('ok'))),
          ],
        ),
      );
      return;
    }
    setState(() => _busy = true);
    await _firestoreService.setTechnicianOnline(profile.techId, value);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: StreamBuilder<TechnicianProfile?>(
              stream: _firestoreService.streamTechnicianProfile(widget.profile.techId),
              builder: (context, snapshot) {
                final profile = snapshot.data ?? widget.profile;
                return Column(
                  children: [
                    _Header(profile: profile, busy: _busy, onToggle: (v) => _toggleOnline(profile, v)),
                    Expanded(
                      child: StreamBuilder<Map<String, dynamic>?>(
                        stream: _firestoreService.streamActiveJobForTechnician(profile.techId),
                        builder: (context, jobSnap) {
                          final activeJob = jobSnap.data;
                          if (activeJob != null) {
                            return _ActiveJobPanel(
                              job: activeJob,
                              profile: profile,
                              firestoreService: _firestoreService,
                            );
                          }
                          if (!profile.isOnline) return const _OfflineState();
                          return _JobFeed(profile: profile, firestoreService: _firestoreService);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          AiAssistantBubble(label: t('tech_ai_label')),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.busy, required this.onToggle});
  final TechnicianProfile profile;
  final bool busy;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: profile.isOnline ? const Color(0xFF7CF2C0) : Colors.white38,
                      width: 2),
                ),
                child: CircleAvatar(
                  radius: 21,
                  backgroundColor: Colors.white,
                  backgroundImage: profile.profilePhotoUrl != null
                      ? NetworkImage(profile.profilePhotoUrl!)
                      : null,
                  child: profile.profilePhotoUrl == null
                      ? Text(profile.fullName.isNotEmpty ? profile.fullName[0] : '?',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName.isEmpty ? t('chat_default_technician') : profile.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Colors.white)),
                    Text(
                        profile.isOnline ? t('tech_online_status') : t('tech_offline_status'),
                        style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                  ],
                ),
              ),
              busy
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Switch(
                      value: profile.isOnline,
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF7CF2C0),
                      onChanged: onToggle,
                    ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeaderStat(value: '${profile.jobsDone}', label: t('tech_stat_jobs')),
              _HeaderStat(value: profile.rating.toStringAsFixed(1), label: t('tech_stat_rating')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ── Offline state ─────────────────────────────────────────────────
class _OfflineState extends StatelessWidget {
  const _OfflineState();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.power_settings_new_rounded, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(t('tech_offline_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(t('tech_offline_sub'), textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Job feed ──────────────────────────────────────────────────────
class _JobFeed extends StatefulWidget {
  const _JobFeed({required this.profile, required this.firestoreService});
  final TechnicianProfile profile;
  final FirestoreService firestoreService;
  @override
  State<_JobFeed> createState() => _JobFeedState();
}

class _JobFeedState extends State<_JobFeed> {
  String? _skillFilter;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final mySkills = TechnicianSkill.all.where((s) => widget.profile.skills.contains(s.id)).toList();
    return Column(
      children: [
        if (mySkills.length > 1)
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              children: [
                _SkillChip(
                  label: t('orders_filter_all'),
                  icon: Icons.all_inclusive_rounded,
                  selected: _skillFilter == null,
                  onTap: () => setState(() => _skillFilter = null),
                ),
                ...mySkills.map((s) => _SkillChip(
                      label: s.label,
                      icon: s.icon,
                      selected: _skillFilter == s.id,
                      onTap: () => setState(() => _skillFilter = _skillFilter == s.id ? null : s.id),
                    )),
              ],
            ),
          ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.firestoreService.streamOpenRequestsForSkills(widget.profile.skills),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('${t('error')}: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))));
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var jobs = snapshot.data!;
              if (_skillFilter != null) {
                jobs = jobs.where((j) => (j['serviceType'] as String? ?? '') == 'sos_$_skillFilter').toList();
              }
              final myId = widget.profile.techId;
              final preferred = jobs.where((j) => j['preferredTechId'] == myId).toList();
              final others = jobs.where((j) => j['preferredTechId'] != myId).toList();
              jobs = [...preferred, ...others];
              if (jobs.isEmpty) return const _EmptyFeed();
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: jobs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 320 + i * 70),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
                  ),
                  child: _JobCard(job: jobs[i], profile: widget.profile, firestoreService: widget.firestoreService),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(t('tech_feed_empty_title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(t('tech_feed_empty_sub'), textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

double _deg2rad(double deg) => deg * pi / 180;
double _distanceKm(dynamic from, dynamic to) {
  if (from == null || to == null) return 0;
  const r = 6371.0;
  final dLat = _deg2rad(to.latitude - from.latitude);
  final dLng = _deg2rad(to.longitude - from.longitude);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(from.latitude * pi / 180) * cos(to.latitude * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

String _timeAgo(dynamic ts, String Function(String) t) {
  if (ts is! Timestamp) return '';
  final diff = DateTime.now().difference(ts.toDate());
  if (diff.inMinutes < 1) return t('tech_time_now');
  if (diff.inMinutes < 60) return t('tech_time_minutes').replaceAll('{n}', '${diff.inMinutes}');
  if (diff.inHours < 24) return t('tech_time_hours').replaceAll('{n}', '${diff.inHours}');
  return t('tech_time_days').replaceAll('{n}', '${diff.inDays}');
}

// ── Job card ─────────────────────────────────────────────────────
class _JobCard extends StatefulWidget {
  const _JobCard({required this.job, required this.profile, required this.firestoreService});
  final Map<String, dynamic> job;
  final TechnicianProfile profile;
  final FirestoreService firestoreService;
  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _accepting = false;

  Future<void> _accept(String requestId, double budget) async {
    setState(() => _accepting = true);
    try {
      await widget.firestoreService.techAcceptAtBudget(requestId: requestId, techId: widget.profile.techId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _counterOfferDialog(BuildContext context, String requestId, double budget) async {
    final t = context.read<LanguageCubit>().state.t;
    final priceController = TextEditingController(text: (budget + 20).toStringAsFixed(0));
    final transportController = TextEditingController(text: '0');
    final result = await showDialog<(double, double)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('tech_offer_title'), style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('tech_offer_price_label'), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(suffixText: 'MAD'),
            ),
            const SizedBox(height: 14),
            Text(t('tech_offer_transport_label'), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            TextField(
              controller: transportController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(suffixText: 'MAD'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
          TextButton(
            onPressed: () {
              final price = double.tryParse(priceController.text.trim());
              final transport = double.tryParse(transportController.text.trim()) ?? 0;
              if (price == null || price <= 0) return;
              Navigator.pop(ctx, (price, transport.clamp(0, FirestoreService.maxTransportFeeMad)));
            },
            child: Text(t('tech_offer_send')),
          ),
        ],
      ),
    );
    if (result == null) return;
    final (price, transportFee) = result;
    try {
      await widget.firestoreService.makeOffer(
        requestId: requestId,
        techId: widget.profile.techId,
        techName: widget.profile.fullName,
        techRating: widget.profile.rating,
        priceMad: price,
        transportFeeMad: transportFee,
      );
      if (mounted) {
        final total = price + transportFee;
        final t2 = context.read<LanguageCubit>().state.t;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(transportFee > 0
                ? t2('tech_offer_sent_transport').replaceAll('{price}', price.toStringAsFixed(0))
                    .replaceAll('{transport}', transportFee.toStringAsFixed(0))
                    .replaceAll('{total}', total.toStringAsFixed(0))
                : t2('tech_offer_sent').replaceAll('{price}', price.toStringAsFixed(0)))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 6),
            content: Text('${context.read<LanguageCubit>().state.t('failed')}${e.toString().replaceFirst('Exception: ', '')}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final job = widget.job;
    final requestId = job['requestId'] as String;
    final label = job['serviceLabel'] as String? ?? t('chat_default_service');
    final description = job['description'] as String? ?? '';
    final clientName = job['clientName'] as String? ?? '';
    final budget = (job['budgetMAD'] as num?)?.toDouble() ?? 0;
    final skillId = (job['serviceType'] as String? ?? '').replaceFirst('sos_', '');
    final skill = TechnicianSkill.all.where((s) => s.id == skillId).toList();
    final icon = skill.isNotEmpty ? skill.first.icon : Icons.build_rounded;
    final skillLabel = skill.isNotEmpty ? skill.first.label : t('chat_default_service');
    final ago = _timeAgo(job['createdAt'], t);
    final km = _distanceKm(widget.profile.location, job['clientLocation']);
    final isChosen = job['preferredTechId'] == widget.profile.techId;
    final scheduledAt = job['scheduledAt'];
    final mediaUrls = (job['mediaUrls'] as List?)?.cast<String>() ?? [];
    final isFresh = job['createdAt'] is Timestamp &&
        DateTime.now().difference((job['createdAt'] as Timestamp).toDate()).inMinutes < 3;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isFresh ? AppColors.primary : AppColors.border, width: isFresh ? 1.4 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: AppColors.danger, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
                        if (isChosen) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(8)),
                            child: Text(t('tech_chosen_badge'), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF7B4EC9))),
                          ),
                        ],
                        if (isFresh) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(8)),
                            child: Text(t('tech_new_badge'), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.danger)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Text('${clientName.isEmpty ? t('chat_default_service') : clientName}${ago.isEmpty ? '' : ' · $ago'}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${budget.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                    Text(t('tech_budget_label'), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          if (mediaUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: mediaUrls.map((url) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => showDialog(context: context,
                              builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(url)))),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(url, width: 64, height: 64, fit: BoxFit.cover,
                                errorBuilder: (a, b, c) => const SizedBox(width: 64)),
                          ),
                        ),
                      )).toList(),
                ),
              ),
            ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Text('« $description »', maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary, height: 1.35)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 8, runSpacing: 6,
              children: [
                _InfoPill(icon: Icons.category_rounded, text: skillLabel, color: AppColors.primary, bg: AppColors.primaryLight),
                if (km > 0)
                  _InfoPill(
                      icon: Icons.location_on_rounded,
                      text: km < 1 ? '${(km * 1000).toStringAsFixed(0)} m' : '${km.toStringAsFixed(1)} km',
                      color: AppColors.textSecondary, bg: AppColors.background),
                if (scheduledAt != null)
                  _InfoPill(
                      icon: Icons.event_rounded,
                      text: DateFormat('dd/MM HH:mm').format((scheduledAt as Timestamp).toDate()),
                      color: const Color(0xFF2B4EAE), bg: const Color(0xFFE8EDFB)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _accepting ? null : () => _counterOfferDialog(context, requestId, budget),
                    child: Text(t('tech_make_offer'), style: const TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _accepting ? null : () => _accept(requestId, budget),
                    child: _accepting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            '${t('tech_accept')} (${(budget - budget * FirestoreService.commissionRate).toStringAsFixed(0)} MAD)',
                            style: const TextStyle(fontSize: 11.5)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text, required this.color, required this.bg});
  final IconData icon;
  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ── Active job panel ──────────────────────────────────────────────
class _ActiveJobPanel extends StatefulWidget {
  const _ActiveJobPanel({required this.job, required this.profile, required this.firestoreService});
  final Map<String, dynamic> job;
  final TechnicianProfile profile;
  final FirestoreService firestoreService;
  @override
  State<_ActiveJobPanel> createState() => _ActiveJobPanelState();
}

class _ActiveJobPanelState extends State<_ActiveJobPanel> {
  final _otpController = TextEditingController();
  final _picker = ImagePicker();
  final _storageService = StorageService();
  bool _working = false;
  bool _uploadingJournal = false;
  bool _cancelling = false;

  Future<void> _addJournalPhoto(String requestId, String label) async {
    final t = context.read<LanguageCubit>().state.t;
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (file == null) return;
      setState(() => _uploadingJournal = true);
      final Uint8List bytes = await file.readAsBytes();
      final url = await _storageService.upload(
        path: 'requests/$requestId/journal_${DateTime.now().millisecondsSinceEpoch}.jpg',
        localPathOrIgnoredOnWeb: file.path, bytes: bytes, contentType: 'image/jpeg',
      ).timeout(const Duration(seconds: 15));
      await widget.firestoreService.addJournalEntry(requestId: requestId, url: url, label: label);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('tech_journal_added').replaceAll('{label}', label))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t('failed')}$e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingJournal = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancelOrder(String requestId) async {
    final t = context.read<LanguageCubit>().state.t;
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('order_cancel_confirm_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('tech_cancel_body'), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, autofocus: true, maxLines: 2,
                decoration: InputDecoration(hintText: t('tech_cancel_hint'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('back'))),
          TextButton(
            onPressed: () { if (reasonCtrl.text.trim().isEmpty) return; Navigator.pop(ctx, true); },
            child: Text(t('tech_cancel_confirm'), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) return;
    setState(() => _cancelling = true);
    try {
      await widget.firestoreService.techCancelRequest(requestId: requestId, techId: widget.profile.techId, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('order_cancelled_snack'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
        setState(() => _cancelling = false);
      }
    }
  }

  Future<void> _rateClient(String requestId, String clientId, String clientName) async {
    final t = context.read<LanguageCubit>().state.t;
    int stars = 5;
    final commentCtrl = TextEditingController();
    bool submitting = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('tech_rate_client_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(t('tech_rate_client_sub').replaceAll('{name}', clientName),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final filled = i < stars;
                    return GestureDetector(
                      onTap: () => setSheet(() => stars = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 40, color: filled ? AppColors.gold : AppColors.border),
                      ),
                    );
                  }),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    [t('tech_rate_1'), t('tech_rate_2'), t('tech_rate_3'), t('tech_rate_4'), t('tech_rate_5')][stars - 1],
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: stars >= 4 ? AppColors.success : stars >= 3 ? AppColors.gold : AppColors.danger),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(controller: commentCtrl, maxLines: 3,
                  decoration: InputDecoration(hintText: t('tech_rate_comment_hint'), labelText: t('rating_comment_hint'))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitting ? null : () async {
                    setSheet(() => submitting = true);
                    try {
                      await widget.firestoreService.rateTechnicianRatesClient(
                          requestId: requestId, clientId: clientId, stars: stars, comment: commentCtrl.text.trim());
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('tech_rate_thanks'))));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        setSheet(() => submitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                      }
                    }
                  },
                  child: submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(t('tech_rate_submit')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final job = widget.job;
    final requestId = job['requestId'] as String;
    final status = job['status'] as String? ?? 'accepted';
    final label = job['serviceLabel'] as String? ?? t('chat_default_service');
    final clientName = job['clientName'] as String? ?? t('chat_default_service');
    final clientId = job['clientId'] as String? ?? '';
    final price = (job['priceQuoteMAD'] as num?)?.toDouble() ?? 0;
    final commission = (job['commissionMAD'] as num?)?.toDouble() ?? 0;
    final lat = (job['clientLocation'] as dynamic)?.latitude;
    final lng = (job['clientLocation'] as dynamic)?.longitude;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  Text('${price.toStringAsFixed(0)} MAD', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 4),
              Text(t('tech_active_job_sub').replaceAll('{client}', clientName).replaceAll('{earn}', (price - commission).toStringAsFixed(0)),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ChatScreen(requestId: requestId, title: clientName))),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                      label: Text(t('tech_chat')),
                    ),
                  ),
                  if (lat != null && lng != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.navigation_rounded, size: 16),
                        label: Text(t('tech_itinerary')),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (status == 'en_route' || status == 'in_progress') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('tech_journal_title'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                      onPressed: _uploadingJournal ? null : () => _addJournalPhoto(requestId, t('tech_journal_arrival')),
                      child: Text(t('tech_journal_arrival'), style: const TextStyle(fontSize: 11.5)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                      onPressed: _uploadingJournal ? null : () => _addJournalPhoto(requestId, t('tech_journal_work')),
                      child: Text(t('tech_journal_work'), style: const TextStyle(fontSize: 11.5)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                      onPressed: _uploadingJournal ? null : () => _addJournalPhoto(requestId, t('tech_journal_done')),
                      child: Text(t('tech_journal_done'), style: const TextStyle(fontSize: 11.5)),
                    )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (status == 'accepted')
          ElevatedButton.icon(
            onPressed: _working ? null : () => _run(() => widget.firestoreService.techGoEnRoute(requestId: requestId, techId: widget.profile.techId)),
            icon: const Icon(Icons.directions_car_rounded),
            label: Text(_working ? '…' : t('tech_en_route').replaceAll('{commission}', commission.toStringAsFixed(0))),
          ),
        if (status == 'en_route') ...[
          Text(t('tech_otp_prompt'), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(counterText: ''),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final scanned = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => QrScannerScreen(expectedRequestId: requestId)));
              if (scanned != null) {
                setState(() => _otpController.text = scanned);
                _run(() => widget.firestoreService.startJobWithOtp(requestId, scanned));
              }
            },
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
            label: Text(t('tech_scan_qr'), style: const TextStyle(fontSize: 12.5)),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _working ? null : () => _run(() => widget.firestoreService.startJobWithOtp(requestId, _otpController.text.trim())),
            child: Text(t('tech_start_work')),
          ),
        ],
        if (status == 'in_progress')
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: _working ? null : () => _run(() async {
              await widget.firestoreService.completeJob(requestId, widget.profile.techId);
              if (mounted && clientId.isNotEmpty) {
                await Future.delayed(const Duration(milliseconds: 500));
                if (mounted) await _rateClient(requestId, clientId, clientName);
              }
            }),
            icon: const Icon(Icons.flag_rounded),
            label: Text(t('tech_complete_work')),
          ),
        const SizedBox(height: 14),
        if (status == 'accepted')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancelling ? null : () => _cancelOrder(requestId),
                icon: _cancelling
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cancel_outlined, size: 17),
                label: Text(_cancelling ? t('tech_cancelling') : t('order_cancel')),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ),
          ),
        _TechEmergencyButton(requestId: requestId, clientId: clientId, techId: widget.profile.techId, firestoreService: widget.firestoreService),
        const SizedBox(height: 10),
        CallSupportButton(t: context.watch<LanguageCubit>().state.t),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ── Emergency button ──────────────────────────────────────────────
class _TechEmergencyButton extends StatelessWidget {
  const _TechEmergencyButton({required this.requestId, required this.clientId, required this.techId, required this.firestoreService});
  final String requestId;
  final String clientId;
  final String techId;
  final FirestoreService firestoreService;

  Future<void> _confirmAndSend(BuildContext context) async {
    final t = context.read<LanguageCubit>().state.t;
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(t('emergency_title'), style: const TextStyle(fontSize: 16))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('emergency_body'), style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(controller: commentController, maxLines: 3, autofocus: true,
                decoration: InputDecoration(hintText: t('emergency_hint'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('emergency_send'), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await firestoreService.submitReport(
        requestId: requestId, clientId: clientId, techId: techId,
        reason: 'Urgence en cours (technicien)', comment: commentController.text.trim(), urgent: true,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 5), content: Text(context.read<LanguageCubit>().state.t('emergency_snack'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.read<LanguageCubit>().state.t('failed')}$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return StreamBuilder<bool>(
      stream: firestoreService.streamTechHasReport(requestId, techId),
      builder: (context, snapshot) {
        final alreadySent = snapshot.data ?? false;
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: alreadySent ? AppColors.textMuted : AppColors.danger,
                minimumSize: const Size(0, 50)),
            onPressed: alreadySent ? null : () => _confirmAndSend(context),
            icon: Icon(alreadySent ? Icons.check_circle_rounded : Icons.warning_amber_rounded, size: 20),
            label: Text(alreadySent ? t('emergency_sent') : t('emergency_button'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        );
      },
    );
  }
}