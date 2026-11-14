import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/notification_service.dart';
import 'technician_orders_history_screen.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../models/moroccan_cities.dart';
import '../../../../models/technician_profile.dart';
import '../../../../models/technician_skill.dart';
import 'technician_home_screen.dart';
import 'technician_specialty_manager.dart';
import 'planned_orders_screen.dart';
import '../../../client/presentation/screens/ai_support_chat_screen.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../client/presentation/bloc/language_cubit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/delete_account_tile.dart';

class TechnicianShell extends StatefulWidget {
  const TechnicianShell({super.key, required this.profile});
  final TechnicianProfile profile;
  @override
  State<TechnicianShell> createState() => _TechnicianShellState();
}

class _TechnicianShellState extends State<TechnicianShell> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    final uid = widget.profile.techId;
    NotificationService().registerRoute('new_request', (requestId) => TechnicianHomeScreen(profile: widget.profile));
    NotificationService().registerRoute('status_accepted', (requestId) => TechnicianHomeScreen(profile: widget.profile));
    NotificationService().registerRoute('specialty_approved', (requestId) => TechnicianHomeScreen(profile: widget.profile));
    NotificationService().registerRoute('specialty_rejected', (requestId) => TechnicianHomeScreen(profile: widget.profile));
    NotificationService().registerRoute('account_verified', (requestId) => TechnicianHomeScreen(profile: widget.profile));
    await NotificationService().init(uid: uid, collection: 'technicians');
  }

  int _index = 0;
  final _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                TechnicianHomeScreen(profile: widget.profile),
                TechnicianOrdersHistoryScreen(),
                PlannedOrdersScreen(),
                _DashboardTab(profile: widget.profile),
                _ProfileTab(profile: widget.profile, firestoreService: _firestoreService),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.work_rounded), label: t('tech_nav_requests')),
          NavigationDestination(icon: const Icon(Icons.history_rounded), label: t('tech_nav_history')),
          NavigationDestination(icon: const Icon(Icons.calendar_month_rounded), label: t('tech_nav_planned')),
          NavigationDestination(icon: const Icon(Icons.insights_rounded), label: t('tech_nav_dashboard')),
          NavigationDestination(icon: const Icon(Icons.person_rounded), label: t('tech_nav_profile')),
        ],
      ),
    );
  }
}

// =================================================================
// DASHBOARD
// =================================================================
class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.profile});
  final TechnicianProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final firestoreService = FirestoreService();
    final techId = profile.techId;
    return SafeArea(
      child: StreamBuilder<TechnicianProfile?>(
        stream: firestoreService.streamTechnicianProfile(techId),
        builder: (context, profileSnap) {
          final live = profileSnap.data ?? profile;
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: firestoreService.streamTechnicianRequests(techId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('${t('dash_error')}: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  ),
                );
              }
              final requests = snapshot.data ?? [];
              late final _TechStats stats;
              try {
                stats = _TechStats.compute(requests);
              } catch (e) {
                return Center(child: Text('${t('dash_calc_error')}: $e'));
              }
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _DashboardHeader(profile: live, stats: stats),
                  const SizedBox(height: 16),
                  _LevelCard(completed: stats.completed),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _StatTile(icon: Icons.payments_rounded, color: AppColors.success, bg: AppColors.successLight,
                        value: '${stats.earnings.toStringAsFixed(0)}', suffix: ' MAD', label: t('dash_net_earnings'))),
                    const SizedBox(width: 12),
                    Expanded(child: _StatTile(icon: Icons.check_circle_rounded, color: AppColors.primary, bg: AppColors.primaryLight,
                        value: '${stats.completed}', suffix: '', label: t('dash_completed_jobs'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _StatTile(icon: Icons.star_rounded, color: AppColors.gold, bg: const Color(0xFFFdf6E3),
                        value: stats.ratedCount == 0 ? '—' : stats.avgRating.toStringAsFixed(1),
                        suffix: stats.ratedCount == 0 ? '' : ' ★',
                        label: '${stats.ratedCount} ${t('dash_client_reviews')}')),
                    const SizedBox(width: 12),
                    Expanded(child: _StatTile(icon: Icons.timer_rounded, color: const Color(0xFF2B4EAE), bg: const Color(0xFFE8EDFB),
                        value: '${stats.active}', suffix: '', label: t('dash_in_progress'))),
                  ]),
                  const SizedBox(height: 16),
                  _AvailabilityCard(profile: live),
                  const SizedBox(height: 16),
                  _EarningsChartCard(requests: requests),
                  const SizedBox(height: 16),
                  _StreakAndRankCard(profile: live, requests: requests, firestoreService: firestoreService),
                  const SizedBox(height: 16),
                  _PerformanceCard(stats: stats),
                  const SizedBox(height: 16),
                  _RecentJobsCard(requests: requests.take(5).toList()),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TechStats {
  const _TechStats({required this.completed, required this.cancelled, required this.active,
      required this.earnings, required this.avgRating, required this.ratedCount});
  final int completed, cancelled, active, ratedCount;
  final double earnings, avgRating;

  static _TechStats compute(List<Map<String, dynamic>> requests) {
    int completed = 0, cancelled = 0, active = 0, ratedCount = 0;
    double earnings = 0, ratingSum = 0;
    for (final r in requests) {
      final status = r['status'] as String? ?? '';
      final price = (r['priceQuoteMAD'] as num?)?.toDouble() ?? 0;
      final commission = 0.0;
      switch (status) {
        case 'completed':
          completed++; earnings += price;
          final rating = (r['clientRating'] as num?)?.toInt();
          if (rating != null) { ratingSum += rating; ratedCount++; }
        case 'cancelled': cancelled++;
        case 'accepted' || 'en_route' || 'in_progress': active++;
      }
    }
    return _TechStats(completed: completed, cancelled: cancelled, active: active,
        earnings: earnings, avgRating: ratedCount == 0 ? 0 : ratingSum / ratedCount, ratedCount: ratedCount);
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.profile, required this.stats});
  final TechnicianProfile profile;
  final _TechStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.6), width: 2)),
          child: CircleAvatar(
            radius: 30, backgroundColor: Colors.white24,
            backgroundImage: profile.profilePhotoUrl != null ? NetworkImage(profile.profilePhotoUrl!) : null,
            child: profile.profilePhotoUrl == null
                ? Text(profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(profile.fullName.isEmpty ? t('chat_default_technician') : profile.fullName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            const SizedBox(width: 6),
            if (profile.isVerified) const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(color: profile.isOnline ? const Color(0xFF7CF2AE) : Colors.white38, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(profile.isOnline ? t('tech_online_status') : t('tech_offline_status'),
                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            const SizedBox(width: 10),
            const Icon(Icons.location_on_rounded, color: Colors.white54, size: 13),
            Flexible(child: Text(profile.city.isEmpty ? '—' : profile.city,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
          ]),
        ])),
      ]),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.completed});
  final int completed;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final levels = [
      (0, t('level_new'), const Color(0xFF8A8F98)),
      (5, t('level_bronze'), const Color(0xFFB0793C)),
      (20, t('level_silver'), const Color(0xFF7E8CA0)),
      (50, t('level_gold'), const Color(0xFFC99A2C)),
      (150, t('level_elite'), const Color(0xFF6C3FC5)),
    ];
    var levelIndex = 0;
    for (var i = 0; i < levels.length; i++) {
      if (completed >= levels[i].$1) levelIndex = i;
    }
    final current = levels[levelIndex];
    final next = levelIndex + 1 < levels.length ? levels[levelIndex + 1] : null;
    final progress = next == null ? 1.0 : ((completed - current.$1) / (next.$1 - current.$1)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: current.$3.withOpacity(0.14), borderRadius: BorderRadius.circular(13)),
              child: Icon(Icons.military_tech_rounded, color: current.$3, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('level_label').replaceAll('{name}', current.$2),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: current.$3)),
            Text(next == null ? t('level_max')
                : t('level_next').replaceAll('{n}', '${next.$1 - completed}').replaceAll('{next}', next.$2),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
        ]),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: AppColors.background, color: current.$3),
          ),
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.color, required this.bg,
      required this.value, required this.suffix, required this.label});
  final IconData icon;
  final Color color, bg;
  final String value, suffix, label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 34, height: 34,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: color)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          Text(suffix, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.profile});
  final TechnicianProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final online = profile.isOnline;
    final color = online ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 46, height: 46,
          decoration: BoxDecoration(color: online ? AppColors.successLight : AppColors.background, borderRadius: BorderRadius.circular(15)),
          child: Icon(online ? Icons.wifi_tethering_rounded : Icons.pause_circle_outline_rounded, color: color, size: 23)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(online ? t('tech_online_status') : t('tech_offline_status'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(online ? 'Vous pouvez recevoir des demandes.' : 'Activez votre disponibilité pour recevoir des demandes.',
              style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textSecondary)),
        ])),
        Container(width: 9, height: 9,
          decoration: BoxDecoration(color: online ? AppColors.success : AppColors.textMuted, shape: BoxShape.circle)),
      ]),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.stats});
  final _TechStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final total = stats.completed + stats.cancelled;
    final completionRate = total == 0 ? 1.0 : stats.completed / total;
    final good = completionRate >= 0.8;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('dash_performance'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _perfRow(icon: good ? Icons.thumb_up_rounded : Icons.warning_amber_rounded,
            color: good ? AppColors.success : AppColors.danger, label: t('dash_completion_rate'),
            value: total == 0 ? '—' : '${(completionRate * 100).toStringAsFixed(0)} %'),
        const SizedBox(height: 10),
        _perfRow(icon: Icons.cancel_rounded,
            color: stats.cancelled == 0 ? AppColors.textMuted : AppColors.danger,
            label: t('dash_cancelled_orders'), value: '${stats.cancelled}'),
        if (stats.cancelled > 2) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.info_rounded, size: 16, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(t('dash_too_many_cancellations'),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.dangerDark))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _perfRow({required IconData icon, required Color color, required String label, required String value}) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
      Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
    ]);
  }
}

class _RecentJobsCard extends StatelessWidget {
  const _RecentJobsCard({required this.requests});
  final List<Map<String, dynamic>> requests;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('dash_recent_orders'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (requests.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(t('dash_no_orders'), style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
        ...requests.map((r) {
          final status = r['status'] as String? ?? '';
          final price = (r['priceQuoteMAD'] as num?)?.toDouble() ?? 0;
          final rating = (r['clientRating'] as num?)?.toInt();
          final (color, icon) = switch (status) {
            'completed' => (AppColors.success, Icons.check_circle_rounded),
            'cancelled' => (AppColors.danger, Icons.cancel_rounded),
            _ => (AppColors.primary, Icons.timelapse_rounded),
          };
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(r['serviceLabel'] as String? ?? t('service'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              if (rating != null) ...[
                Text('$rating', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const Icon(Icons.star_rounded, size: 14, color: AppColors.gold),
                const SizedBox(width: 8),
              ],
              Text('${price.toStringAsFixed(0)} MAD', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            ]),
          );
        }),
      ]),
    );
  }
}

class _StreakAndRankCard extends StatelessWidget {
  const _StreakAndRankCard({required this.profile, required this.requests, required this.firestoreService});
  final TechnicianProfile profile;
  final List<Map<String, dynamic>> requests;
  final FirestoreService firestoreService;

  int get _streak {
    final days = <DateTime>{};
    for (final r in requests) {
      if (r['status'] != 'completed') continue;
      final ts = r['completedAt'] ?? r['createdAt'];
      if (ts is! Timestamp) continue;
      final d = ts.toDate();
      days.add(DateTime(d.year, d.month, d.day));
    }
    var streak = 0;
    var day = DateTime.now();
    day = DateTime(day.year, day.month, day.day);
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    while (days.contains(day)) { streak++; day = day.subtract(const Duration(days: 1)); }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t('dash_ranking_city'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFFBEAD8), borderRadius: BorderRadius.circular(18)),
            child: Text(t('dash_streak').replaceAll('{n}', '$_streak'),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFB3541E))),
          ),
        ]),
        const SizedBox(height: 10),
        StreamBuilder<List<TechnicianProfile>>(
          stream: firestoreService.streamTopTechnicians(profile.city, limit: 5),
          builder: (context, snapshot) {
            final top = snapshot.data ?? [];
            if (top.isEmpty) return Text(t('dash_ranking_empty'),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary));
            return Column(children: List.generate(top.length, (i) {
              final tech = top[i];
              final isMe = tech.techId == profile.techId;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: isMe ? AppColors.primaryLight : AppColors.background,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  SizedBox(width: 26, child: Text(i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}.',
                      style: const TextStyle(fontSize: 13))),
                  Expanded(child: Text(
                      isMe ? '${tech.fullName} ${t('dash_ranking_you')}'
                           : tech.fullName.isEmpty ? t('chat_default_technician') : tech.fullName,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: isMe ? FontWeight.w800 : FontWeight.w600))),
                  Text(t('dash_jobs_rating').replaceAll('{jobs}', '${tech.jobsDone}').replaceAll('{rating}', tech.rating.toStringAsFixed(1)),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ]),
              );
            }));
          },
        ),
      ]),
    );
  }
}

class _EarningsChartCard extends StatelessWidget {
  const _EarningsChartCard({required this.requests});
  final List<Map<String, dynamic>> requests;
  static const _dayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final totals = List<double>.filled(7, 0);
    for (final r in requests) {
      if (r['status'] != 'completed') continue;
      final ts = r['completedAt'] ?? r['createdAt'];
      if (ts is! Timestamp) continue;
      final d = ts.toDate();
      final day = DateTime(d.year, d.month, d.day);
      final diff = today.difference(day).inDays;
      if (diff < 0 || diff > 6) continue;
      final price = (r['priceQuoteMAD'] as num?)?.toDouble() ?? 0;
      final commission = (r['commissionMAD'] as num?)?.toDouble() ?? 0;
      totals[6 - diff] += price;
    }
    final maxValue = totals.fold<double>(0, (m, v) => v > m ? v : m);
    final weekTotal = totals.fold<double>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t('dash_earnings_7days'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
          Text('${weekTotal.toStringAsFixed(0)} MAD',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.success)),
        ]),
        const SizedBox(height: 14),
        SizedBox(height: 96, child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final value = totals[i];
            final heightFactor = maxValue == 0 ? 0.0 : value / maxValue;
            final isToday = i == 6;
            final weekdayIndex = today.subtract(Duration(days: 6 - i)).weekday - 1;
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (value > 0) Padding(padding: const EdgeInsets.only(bottom: 4),
                    child: Text(value.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: heightFactor),
                  duration: Duration(milliseconds: 500 + i * 80),
                  curve: Curves.easeOutCubic,
                  builder: (context, animated, _) => Container(
                    height: 8 + animated * 56,
                    decoration: BoxDecoration(
                      color: isToday ? AppColors.primary : value > 0 ? AppColors.primary.withOpacity(0.45) : AppColors.background,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_dayLetters[weekdayIndex], style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isToday ? AppColors.primary : AppColors.textMuted)),
              ]),
            ));
          }),
        )),
      ]),
    );
  }
}

// =================================================================
// PROFILE TAB
// =================================================================
class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.profile, required this.firestoreService});
  final TechnicianProfile profile;
  final FirestoreService firestoreService;
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _storageService = StorageService();
  final _picker = ImagePicker();
  bool _uploadingPhoto = false, _updatingPosition = false, _uploadingVideo = false, _uploadingCin = false;
  TechnicianProfile? _live;
  TechnicianProfile get profile => _live ?? widget.profile;
  FirestoreService get fs => widget.firestoreService;

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: Duration(seconds: error ? 6 : 2),
      backgroundColor: error ? AppColors.dangerDark : null,
      content: Text(message),
    ));
  }

  Future<void> _save(Map<String, dynamic> fields, {String? okKey}) async {
    final t = context.read<LanguageCubit>().state.t;
    try {
      await fs.updateTechnicianFields(profile.techId, fields);
      _toast(okKey != null ? t(okKey) : t('profile_saved_ok'));
    } catch (e) {
      _toast('${t('profile_save_error')}: ${e.toString().replaceFirst('Exception: ', '')}', error: true);
    }
  }

  Future<void> _changePhoto() async {
    final t = context.read<LanguageCubit>().state.t;
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (file == null) return;
      setState(() => _uploadingPhoto = true);
      final bytes = await file.readAsBytes();
      final url = await _storageService.upload(
          path: 'technicians/${profile.techId}/profile.jpg',
          localPathOrIgnoredOnWeb: file.path, bytes: bytes, contentType: 'image/jpeg')
          .timeout(const Duration(seconds: 20));
      await fs.updateTechnicianFields(profile.techId, {'profilePhotoUrl': url});
      _toast(t('profile_photo_updated'));
    } catch (e) { _toast('${t('profile_photo_error')}: $e', error: true);
    } finally { if (mounted) setState(() => _uploadingPhoto = false); }
  }

  Future<void> _uploadIntroVideo() async {
    final t = context.read<LanguageCubit>().state.t;
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
      if (file == null) return;
      setState(() => _uploadingVideo = true);
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 25 * 1024 * 1024) { _toast(t('profile_video_too_large'), error: true); return; }
      final url = await _storageService.upload(
          path: 'technicians/${profile.techId}/intro.mp4',
          localPathOrIgnoredOnWeb: file.path, bytes: bytes, contentType: 'video/mp4')
          .timeout(const Duration(seconds: 45));
      await fs.updateTechnicianFields(profile.techId, {'introVideoUrl': url});
      _toast(t('profile_video_updated'));
    } catch (e) { _toast('${t('profile_video_error')}: $e', error: true);
    } finally { if (mounted) setState(() => _uploadingVideo = false); }
  }

  Future<void> _uploadCin() async {
    final t = context.read<LanguageCubit>().state.t;
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file == null) return;
      setState(() => _uploadingCin = true);
      final bytes = await file.readAsBytes();
      final url = await _storageService.upload(
          path: 'technicians/${profile.techId}/cin.jpg',
          localPathOrIgnoredOnWeb: file.path, bytes: bytes, contentType: 'image/jpeg')
          .timeout(const Duration(seconds: 20));
      await fs.updateTechnicianFields(profile.techId, {'cinPhotoUrl': url});
      _toast(t('profile_cin_sent_ok'));
    } catch (e) { _toast('${t('profile_cin_error')}: $e', error: true);
    } finally { if (mounted) setState(() => _uploadingCin = false); }
  }

  Future<void> _updatePosition() async {
    final t = context.read<LanguageCubit>().state.t;
    setState(() => _updatingPosition = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 12));
      await fs.updateTechnicianFields(profile.techId, {'location': GeoPoint(pos.latitude, pos.longitude)});
      _toast(t('profile_location_updated'));
    } catch (e) { _toast('${t('profile_location_unavailable')}: $e', error: true);
    } finally { if (mounted) setState(() => _updatingPosition = false); }
  }

  Future<void> _editText({required String titleKey, required String initial, required String field, int maxLines = 1, String? hintKey}) async {
    final t = context.read<LanguageCubit>().state.t;
    final controller = TextEditingController(text: initial);
    final value = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 22, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t(titleKey), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: controller, maxLines: maxLines, autofocus: true,
              decoration: InputDecoration(hintText: hintKey != null ? t(hintKey) : null)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                  child: Text(t('profile_save_btn')))),
        ]),
      ),
    );
    if (value != null) await _save({field: value});
  }

  Future<void> _editCity() async {
    final city = await showCityPicker(context, current: profile.city);
    if (city != null) await _save({'city': city});
  }

  Future<void> _editExperience() async {
    final t = context.read<LanguageCubit>().state.t;
    var years = profile.yearsExperience;
    final result = await showModalBottomSheet<int>(
      context: context, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('profile_years_exp_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Center(child: Text(t('profile_years_exp_years').replaceAll('{n}', '$years'),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.primary))),
            Slider(value: years.toDouble(), min: 0, max: 40, divisions: 40,
                activeColor: AppColors.primary, onChanged: (v) => setSheet(() => years = v.round())),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity,
                child: ElevatedButton(onPressed: () => Navigator.pop(ctx, years), child: Text(t('profile_save_btn')))),
          ]),
        ),
      ),
    );
    if (result != null) await _save({'yearsExperience': result});
  }

  double get _completion {
    var done = 0;
    if (profile.fullName.isNotEmpty) done++;
    if (profile.profilePhotoUrl != null) done++;
    if (profile.city.isNotEmpty) done++;
    if (profile.bio.isNotEmpty) done++;
    if (profile.approvedSpecialties.isNotEmpty) done++;
    if (profile.location != null) done++;
    return done / 6;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TechnicianProfile?>(
      stream: fs.streamTechnicianProfile(widget.profile.techId),
      builder: (context, snapshot) { _live = snapshot.data; return _buildBody(context); },
    );
  }

  Widget _buildBody(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final completion = _completion;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark]),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Stack(children: [
              Container(padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: CircleAvatar(radius: 42, backgroundColor: AppColors.primaryLight,
                  backgroundImage: profile.profilePhotoUrl != null ? NetworkImage(profile.profilePhotoUrl!) : null,
                  child: profile.profilePhotoUrl == null
                      ? Text(profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary))
                      : null)),
              Positioned(right: 0, bottom: 0,
                child: GestureDetector(onTap: _uploadingPhoto ? null : _changePhoto,
                  child: Container(width: 30, height: 30,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)]),
                    child: _uploadingPhoto
                        ? const Padding(padding: EdgeInsets.all(7), child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_camera_rounded, size: 16, color: AppColors.primary)))),
            ]),
            const SizedBox(height: 12),
            Text(profile.fullName.isEmpty ? t('chat_default_technician') : profile.fullName,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            Text('${profile.city.isEmpty ? t('profile_city_undefined') : profile.city} · ${profile.rating.toStringAsFixed(1)} ★',
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 14),
            Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(t('profile_completion'), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                Text('${(completion * 100).round()}%', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: completion),
                  duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 7,
                      backgroundColor: Colors.white24, color: Colors.white))),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        _SectionCard(title: t('profile_section_info'), children: [
          _EditRow(icon: Icons.badge_rounded, label: t('profile_full_name'),
              value: profile.fullName.isEmpty ? t('profile_add') : profile.fullName,
              onTap: () => _editText(titleKey: 'profile_full_name', initial: profile.fullName, field: 'fullName')),
          _EditRow(icon: Icons.location_city_rounded, label: t('account_city'),
              value: profile.city.isEmpty ? t('profile_choose_city') : profile.city, onTap: _editCity),
          _EditRow(icon: Icons.notes_rounded, label: t('profile_bio'),
              value: profile.bio.isEmpty ? t('profile_bio_add') : profile.bio,
              onTap: () => _editText(titleKey: 'profile_bio', initial: profile.bio, field: 'bio', maxLines: 4, hintKey: 'profile_bio_hint')),
          _EditRow(icon: Icons.phone_rounded, label: t('profile_phone'),
              value: profile.phone.isEmpty ? '—' : profile.phone, locked: true),
        ]),
        const SizedBox(height: 14),
        _SectionCard(title: t('profile_section_activity'), children: [
          _EditRow(icon: Icons.timeline_rounded, label: t('profile_years_exp'),
              value: t('profile_years_exp_years').replaceAll('{n}', '${profile.yearsExperience}'), onTap: _editExperience),
          _EditRow(icon: Icons.videocam_rounded, label: t('profile_video'),
              value: profile.introVideoUrl != null ? t('profile_video_online') : t('profile_video_add'),
              trailing: _uploadingVideo ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              onTap: _uploadingVideo ? null : _uploadIntroVideo),
          _EditRow(icon: Icons.my_location_rounded, label: t('profile_location'),
              value: profile.location != null ? t('profile_location_saved') : t('profile_location_none'),
              trailing: _updatingPosition ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              onTap: _updatingPosition ? null : _updatePosition),
        ]),
        const SizedBox(height: 14),
        SpecialtyManagerSection(profile: profile),
        const SizedBox(height: 14),
        _SectionCard(title: t('profile_section_account'), children: [
          BlocBuilder<LanguageCubit, LanguageState>(
            builder: (context, langState) {
              final isArabic = langState.language == AppLanguage.ar;
              return _EditRow(icon: Icons.translate_rounded, label: t('profile_language'),
                  value: isArabic ? 'الدارجة' : 'Français',
                  onTap: () => context.read<LanguageCubit>().toggle());
            },
          ),
          _EditRow(icon: Icons.smart_toy_rounded, label: t('profile_assistant'), value: t('profile_assistant_sub'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSupportChatScreen()))),
          _EditRow(icon: Icons.credit_card_rounded, label: t('profile_cin'),
              value: profile.isVerified ? t('profile_cin_verified')
                  : ((_live?.cinPhotoUrl ?? widget.profile.cinPhotoUrl) != null ? t('profile_cin_sent') : t('profile_cin_add')),
              trailing: _uploadingCin ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              locked: profile.isVerified, onTap: profile.isVerified || _uploadingCin ? null : _uploadCin),
          _EditRow(icon: Icons.verified_rounded, label: t('profile_verification'),
              value: profile.isVerified ? t('profile_verified') : t('profile_verification_pending'), locked: true),
          ListTile(dense: true,
              leading: const Icon(Icons.description_rounded, size: 20, color: AppColors.primary),
              title: Text(t('profile_terms'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textMuted),
              onTap: () => launchUrl(Uri.parse('https://brikool.online/terms.html'), mode: LaunchMode.externalApplication)),
          ListTile(dense: true,
              leading: const Icon(Icons.privacy_tip_rounded, size: 20, color: AppColors.primary),
              title: Text(t('profile_privacy'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textMuted),
              onTap: () => launchUrl(Uri.parse('https://brikool.online/privacy.html'), mode: LaunchMode.externalApplication)),
          DeleteAccountTile(uid: profile.techId, userType: 'technician', fs: fs),
          _EditRow(icon: Icons.logout_rounded, label: t('profile_logout'), value: '', danger: true,
              onTap: () async {
                final confirmed = await showDialog<bool>(context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(t('logout_confirm_title')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('logout_confirm_no'))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('logout_confirm_yes'))),
                      ],
                    ));
                if (confirmed == true) await AuthService().signOut();
              }),
        ]),
      ],
    );
  }
}

// =================================================================
// Shared UI helpers
// =================================================================
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: AppColors.textMuted))),
        ...children,
      ]),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({required this.icon, required this.label, required this.value,
      this.onTap, this.locked = false, this.danger = false, this.trailing});
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  final bool locked, danger;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return InkWell(
      onTap: locked ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, size: 19, color: danger ? AppColors.danger : AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
            if (value.isNotEmpty) Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          trailing ?? (locked
              ? const Icon(Icons.lock_rounded, size: 14, color: AppColors.textMuted)
              : const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}