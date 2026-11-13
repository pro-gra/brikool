import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../models/technician_profile.dart';

/// Full analytics dashboard with charts — no external chart package needed,
/// all drawn with Flutter's Canvas via CustomPainter.
/// Shows: revenue, cancellation rate, orders by city, orders by service,
/// orders per day (7-day trend), top technicians, conversion funnel.
class AdminAnalyticsTab extends StatelessWidget {
  const AdminAnalyticsTab({super.key, required this.fs});
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.streamAllRequests(),
      builder: (context, reqSnap) {
        if (!reqSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = reqSnap.data!;

        return StreamBuilder<List<TechnicianProfile>>(
          stream: fs.streamAllTechnicians(),
          builder: (context, techSnap) {
            final techs = techSnap.data ?? [];

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: fs.streamAllUsers(),
              builder: (context, usersSnap) {
                final users = usersSnap.data ?? [];
                return _AnalyticsDashboard(
                  requests: requests,
                  techs: techs,
                  users: users,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AnalyticsDashboard extends StatelessWidget {
  const _AnalyticsDashboard({
    required this.requests,
    required this.techs,
    required this.users,
  });

  final List<Map<String, dynamic>> requests;
  final List<TechnicianProfile> techs;
  final List<Map<String, dynamic>> users;

  // ── Computed stats ────────────────────────────────────────────

  int get total => requests.length;
  int get completed => requests.where((r) => r['status'] == 'completed').length;
  int get cancelled => requests.where((r) => r['status'] == 'cancelled').length;
  int get pending => requests.where((r) => r['status'] == 'pending').length;
  int get active => requests.where((r) =>
      ['accepted', 'en_route', 'in_progress'].contains(r['status'])).length;

  double get totalRevenue => requests
      .where((r) => r['status'] == 'completed')
      .fold(0.0, (s, r) => s + ((r['commissionMAD'] as num?)?.toDouble() ?? 0));

  double get totalVolume => requests
      .where((r) => r['status'] == 'completed')
      .fold(0.0, (s, r) => s + ((r['priceQuoteMAD'] as num?)?.toDouble() ?? 0));

  double get cancellationRate =>
      total == 0 ? 0 : (cancelled / total * 100);

  double get completionRate =>
      total == 0 ? 0 : (completed / total * 100);

  double get avgOrderValue =>
      completed == 0 ? 0 : totalVolume / completed;

  // Orders by city
  Map<String, int> get ordersByCity {
    final map = <String, int>{};
    for (final r in requests) {
      final city = r['city'] as String? ?? 'Inconnue';
      map[city] = (map[city] ?? 0) + 1;
    }
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    return Map.fromEntries(sorted.entries.take(8));
  }

  // Orders by service type
  Map<String, int> get ordersByService {
    final map = <String, int>{};
    for (final r in requests) {
      final label = r['serviceLabel'] as String? ?? 'Autre';
      final short = label.length > 20 ? '${label.substring(0, 18)}…' : label;
      map[short] = (map[short] ?? 0) + 1;
    }
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    return Map.fromEntries(sorted.entries.take(6));
  }

  // Orders per day (last 14 days)
  Map<String, int> get ordersPerDay {
    final map = <String, int>{};
    final now = DateTime.now();
    for (var i = 13; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = DateFormat('dd/MM').format(day);
      map[key] = 0;
    }
    for (final r in requests) {
      final ts = r['createdAt'] as Timestamp?;
      if (ts == null) continue;
      final diff = now.difference(ts.toDate()).inDays;
      if (diff < 14) {
        final key = DateFormat('dd/MM').format(ts.toDate());
        map[key] = (map[key] ?? 0) + 1;
      }
    }
    return map;
  }

  // Revenue per day (last 14 days)
  Map<String, double> get revenuePerDay {
    final map = <String, double>{};
    final now = DateTime.now();
    for (var i = 13; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = DateFormat('dd/MM').format(day);
      map[key] = 0;
    }
    for (final r in requests) {
      if (r['status'] != 'completed') continue;
      final ts = r['completedAt'] as Timestamp? ?? r['createdAt'] as Timestamp?;
      if (ts == null) continue;
      final now2 = DateTime.now();
      final diff = now2.difference(ts.toDate()).inDays;
      if (diff < 14) {
        final key = DateFormat('dd/MM').format(ts.toDate());
        final comm = (r['commissionMAD'] as num?)?.toDouble() ?? 0;
        map[key] = (map[key] ?? 0) + comm;
      }
    }
    return map;
  }

  // Status breakdown for funnel
  Map<String, int> get statusFunnel => {
    'Créées': total,
    'Acceptées': requests.where((r) => !['pending', 'cancelled'].contains(r['status'])).length,
    'En cours': requests.where((r) => ['in_progress', 'completed'].contains(r['status'])).length,
    'Terminées': completed,
  };

  // Top technicians by revenue
  List<Map<String, dynamic>> get topTechs {
    final map = <String, double>{};
    final names = <String, String>{};
    for (final r in requests) {
      if (r['status'] != 'completed') continue;
      final techId = r['techId'] as String?;
      if (techId == null) continue;
      final comm = (r['commissionMAD'] as num?)?.toDouble() ?? 0;
      map[techId] = (map[techId] ?? 0) + comm;
    }
    final tech = techs.where((t) => map.containsKey(t.techId)).map((t) {
      return {'name': t.fullName, 'revenue': map[t.techId]!, 'jobs': t.jobsDone, 'rating': t.rating, 'city': t.city};
    }).toList();
    tech.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    return tech.take(5).toList();
  }

  // Users by city
  Map<String, int> get usersByCity {
    final map = <String, int>{};
    for (final u in users) {
      final city = u['city'] as String? ?? '';
      if (city.isEmpty) continue;
      map[city] = (map[city] ?? 0) + 1;
    }
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    return Map.fromEntries(sorted.entries.take(8));
  }

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.currency(locale: 'fr_MA', symbol: 'MAD', decimalDigits: 0);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Title ──────────────────────────────────────────────
        const Text('Analytiques',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Mis à jour à ${DateFormat('HH:mm').format(DateTime.now())}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 20),

        // ── KPI row ─────────────────────────────────────────────
        _SectionTitle('Vue d\'ensemble'),
        const SizedBox(height: 10),
        _KpiGrid(items: [
          _KpiItem('${nf.format(totalRevenue)}', 'Commissions Brikol', Icons.payments_rounded, AppColors.success),
          _KpiItem('${nf.format(totalVolume)}', 'Volume traité', Icons.swap_horiz_rounded, AppColors.primary),
          _KpiItem('${nf.format(avgOrderValue)}', 'Panier moyen', Icons.shopping_bag_rounded, AppColors.accent),
          _KpiItem('$total', 'Commandes totales', Icons.receipt_rounded, const Color(0xFF2B4EAE)),
          _KpiItem('$completed', 'Terminées', Icons.check_circle_rounded, AppColors.success),
          _KpiItem('${cancellationRate.toStringAsFixed(1)}%', 'Taux d\'annulation', Icons.cancel_rounded, AppColors.danger),
          _KpiItem('${completionRate.toStringAsFixed(1)}%', 'Taux de complétion', Icons.trending_up_rounded, AppColors.success),
          _KpiItem('${techs.where((t) => t.isOnline).length}', 'Techs en ligne', Icons.wifi_rounded, AppColors.primary),
        ]),
        const SizedBox(height: 28),

        // ── Orders per day chart ─────────────────────────────────
        _SectionTitle('Commandes par jour (14 jours)'),
        const SizedBox(height: 12),
        _ChartCard(
          child: _BarChart(
            data: ordersPerDay,
            color: AppColors.primary,
            label: 'commandes',
          ),
        ),
        const SizedBox(height: 20),

        // ── Revenue per day chart ────────────────────────────────
        _SectionTitle('Commissions par jour (14 jours)'),
        const SizedBox(height: 12),
        _ChartCard(
          child: _BarChart(
            data: revenuePerDay.map((k, v) => MapEntry(k, v)),
            color: AppColors.success,
            label: 'MAD',
            isCurrency: true,
          ),
        ),
        const SizedBox(height: 20),

        // ── Status funnel ────────────────────────────────────────
        _SectionTitle('Entonnoir de conversion'),
        const SizedBox(height: 12),
        _ChartCard(child: _FunnelChart(data: statusFunnel)),
        const SizedBox(height: 20),

        // ── Orders by city ───────────────────────────────────────
        _SectionTitle('Commandes par ville'),
        const SizedBox(height: 12),
        _ChartCard(
          child: _HorizontalBarChart(
            data: ordersByCity,
            color: AppColors.accent,
            total: total,
          ),
        ),
        const SizedBox(height: 20),

        // ── Users by city ────────────────────────────────────────
        _SectionTitle('Clients par ville'),
        const SizedBox(height: 12),
        _ChartCard(
          child: _HorizontalBarChart(
            data: usersByCity,
            color: AppColors.primary,
            total: users.length,
          ),
        ),
        const SizedBox(height: 20),

        // ── Orders by service ────────────────────────────────────
        _SectionTitle('Commandes par service'),
        const SizedBox(height: 12),
        _ChartCard(child: _PieChart(data: ordersByService)),
        const SizedBox(height: 20),

        // ── Cancellation breakdown ───────────────────────────────
        _SectionTitle('Répartition des statuts'),
        const SizedBox(height: 12),
        _ChartCard(
          child: _PieChart(
            data: {
              'Terminées': completed,
              'Annulées': cancelled,
              'En attente': pending,
              'Actives': active,
            },
            colors: [AppColors.success, AppColors.danger, AppColors.gold, AppColors.accent],
          ),
        ),
        const SizedBox(height: 20),

        // ── Top technicians ──────────────────────────────────────
        _SectionTitle('Top 5 techniciens (commissions)'),
        const SizedBox(height: 12),
        if (topTechs.isEmpty)
          const Text('Aucune donnée',
              style: TextStyle(color: AppColors.textSecondary))
        else
          ...topTechs.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            final rev = (t['revenue'] as double);
            final maxRev = (topTechs.first['revenue'] as double);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: i == 0 ? AppColors.gold : AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: i == 0 ? Colors.white : AppColors.primary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t['name'] as String? ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('${t['city']} · ${t['jobs']} travaux · ${(t['rating'] as double).toStringAsFixed(1)}★',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxRev == 0 ? 0 : rev / maxRev,
                        minHeight: 5,
                        backgroundColor: AppColors.border,
                        color: i == 0 ? AppColors.gold : AppColors.primary,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Text(nf.format(rev),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary)),
              ]),
            );
          }),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHARED CHART WIDGETS
// ═══════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(
          color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
    ]);
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});
  final List<_KpiItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) => SizedBox(
        width: (MediaQuery.of(context).size.width - 60) / 2,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(item.icon, size: 18, color: item.color),
            const SizedBox(height: 8),
            Text(item.value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: item.color)),
            Text(item.label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
          ]),
        ),
      )).toList(),
    );
  }
}

class _KpiItem {
  const _KpiItem(this.value, this.label, this.icon, this.color);
  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

// ── Bar chart (orders or revenue per day) ─────────────────────
class _BarChart extends StatelessWidget {
  const _BarChart({required this.data, required this.color, required this.label, this.isCurrency = false});
  final Map<String, num> data;
  final Color color;
  final String label;
  final bool isCurrency;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Text('Aucune donnée');
    final maxVal = data.values.fold<num>(0, (a, b) => a > b ? a : b);
    final keys = data.keys.toList();
    final vals = data.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(keys.length, (i) {
              final pct = maxVal == 0 ? 0.0 : vals[i] / maxVal;
              final isToday = i == keys.length - 1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Tooltip(
                    message: isCurrency
                        ? '${keys[i]}: ${vals[i].toStringAsFixed(0)} MAD'
                        : '${keys[i]}: ${vals[i]} $label',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (vals[i] > 0)
                          Text(
                            isCurrency ? '${vals[i].toStringAsFixed(0)}' : '${vals[i]}',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w600,
                              color: isToday ? color : AppColors.textMuted,
                            ),
                          ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 400 + i * 30),
                          height: 110 * pct.toDouble(),
                          decoration: BoxDecoration(
                            color: isToday ? color : color.withOpacity(0.5),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(keys.length, (i) {
            final showLabel = i % 2 == 0 || i == keys.length - 1;
            return Expanded(
              child: Text(
                showLabel ? keys[i] : '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 7.5, color: AppColors.textMuted),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Horizontal bar chart (by city) ───────────────────────────
class _HorizontalBarChart extends StatelessWidget {
  const _HorizontalBarChart({required this.data, required this.color, required this.total});
  final Map<String, int> data;
  final Color color;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Text('Aucune donnée');
    final maxVal = data.values.fold(0, (a, b) => a > b ? a : b);

    return Column(
      children: data.entries.map((e) {
        final pct = maxVal == 0 ? 0.0 : e.value / maxVal;
        final sharePct = total == 0 ? 0.0 : e.value / total * 100;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(
              width: 80,
              child: Text(e.key,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(children: [
                Container(height: 22, decoration: BoxDecoration(
                    color: AppColors.border, borderRadius: BorderRadius.circular(6))),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(height: 22, decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(6))),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 55,
              child: Text('${e.value} (${sharePct.toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ── Pie/donut chart ───────────────────────────────────────────
class _PieChart extends StatelessWidget {
  const _PieChart({required this.data, this.colors});
  final Map<String, int> data;
  final List<Color>? colors;

  static const _defaultColors = [
    AppColors.primary, AppColors.accent, AppColors.gold,
    AppColors.success, AppColors.danger, Color(0xFF2B4EAE),
    Color(0xFF9A6A00), AppColors.textMuted,
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Text('Aucune donnée');
    final total = data.values.fold(0, (a, b) => a + b);
    if (total == 0) return const Text('Aucune donnée');

    final colorList = colors ?? _defaultColors;
    final entries = data.entries.toList();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Row(children: [
            Expanded(
              child: CustomPaint(
                painter: _DonutPainter(
                  values: entries.map((e) => e.value.toDouble()).toList(),
                  colors: List.generate(entries.length, (i) => colorList[i % colorList.length]),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entries.asMap().entries.map((e) {
                  final color = colorList[e.key % colorList.length];
                  final pct = e.value.value / total * 100;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Container(width: 10, height: 10,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.value.key,
                          style: const TextStyle(fontSize: 11.5),
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                      Text('${pct.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    const strokeWidth = 32.0;
    const gapAngle = 0.03;

    double startAngle = -3.14159 / 2;
    for (var i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * 3.14159 - gapAngle;
      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle + gapAngle;
    }

    // Center text — use paragraph builder to avoid TextDirection import issues
    final total2 = values.fold(0.0, (a, b) => a + b).toInt();
    final tp = TextPainter(
      text: TextSpan(
        text: '$total2',
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900,
            color: Color(0xFF0c1c13)),
      ),
      textDirection: ui.TextDirection.ltr, // TextDirection.ltr = index 0
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_DonutPainter old) => values != old.values;
}

// ── Funnel chart ──────────────────────────────────────────────
class _FunnelChart extends StatelessWidget {
  const _FunnelChart({required this.data});
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final maxVal = entries.isNotEmpty ? entries.first.value : 1;
    final colors = [AppColors.primary, AppColors.accent, AppColors.gold, AppColors.success];

    return Column(
      children: entries.asMap().entries.map((e) {
        final width = maxVal == 0 ? 0.0 : e.value.value / maxVal;
        final convPct = e.key == 0 ? 100.0 :
            entries[e.key - 1].value == 0 ? 0.0 :
            e.value.value / entries[e.key - 1].value * 100;
        final color = colors[e.key % colors.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(width: 90, child: Text(e.value.key,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              Expanded(
                child: Stack(children: [
                  Container(height: 28,
                      decoration: BoxDecoration(color: AppColors.border,
                          borderRadius: BorderRadius.circular(8))),
                  FractionallySizedBox(
                    widthFactor: width,
                    child: Container(height: 28,
                        decoration: BoxDecoration(color: color,
                            borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: width > 0.2 ? Text('${e.value.value}',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 11, fontWeight: FontWeight.w700)) : null),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 48, child: Text(
                e.key == 0 ? '100%' : '→${convPct.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
              )),
            ]),
          ]),
        );
      }).toList(),
    );
  }
}