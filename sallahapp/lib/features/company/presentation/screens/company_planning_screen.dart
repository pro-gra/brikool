import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../models/big_service_category.dart';

const _kFrenchWeekdays = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
];
const _kFrenchMonths = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];

String _formatFullFrenchDate(DateTime d) {
  return '${_kFrenchWeekdays[d.weekday - 1]} ${d.day} ${_kFrenchMonths[d.month - 1]} ${d.year}';
}

/// Converts a request's duration fields into a whole number of days
/// it occupies on the calendar (hours round up to at least 1 day so
/// a same-day job still shows on the calendar; weeks convert to 7x).
int _durationInDays(Map<String, dynamic> request) {
  final value = (request['durationValue'] as num?)?.toDouble() ?? 0;
  final unit = request['durationUnit'] as String? ?? 'jours';
  if (value <= 0) return 1;
  switch (unit) {
    case 'heures':
      return value > 24 ? (value / 24).ceil() : 1;
    case 'semaines':
      return (value * 7).ceil();
    default: // jours
      return value.ceil();
  }
}

/// The inclusive [start, end] range of calendar days a request
/// occupies, based on its preferred date and (once quoted) duration.
(DateTime, DateTime) _requestDateRange(Map<String, dynamic> request) {
  final pd = request['preferredDate'];
  final start = pd is Timestamp
      ? DateTime(pd.toDate().year, pd.toDate().month, pd.toDate().day)
      : DateTime.now();
  final days = _durationInDays(request);
  final end = start.add(Duration(days: days - 1));
  return (start, end);
}

bool _rangesOverlap(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
  return !aEnd.isBefore(bStart) && !bEnd.isBefore(aStart);
}

/// A scheduling view for the company: a color-coded month calendar
/// (green = free day, yellow = one job, red = two or more jobs that
/// day — a scheduling conflict worth noticing) plus a full sortable
/// table of every request, each one tappable for full detail.
class CompanyPlanningScreen extends StatefulWidget {
  const CompanyPlanningScreen({super.key, required this.companyId, required this.fs});
  final String companyId;
  final FirestoreService fs;

  @override
  State<CompanyPlanningScreen> createState() => _CompanyPlanningScreenState();
}

class _CompanyPlanningScreenState extends State<CompanyPlanningScreen> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Planning', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: widget.fs.streamQuoteRequestsForCompany(widget.companyId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final requests = snapshot.data!;

            final byDay = <DateTime, List<Map<String, dynamic>>>{};
            for (final r in requests) {
              if (r['preferredDate'] is! Timestamp) continue;
              // Only committed schedules (confirmed/in_progress/completed)
              // have a real duration to speak of; a bare "new"/"quoted"
              // request without a firm date range just marks its single
              // requested day, same as before.
              final status = r['status'] as String? ?? 'new';
              final (start, end) = ['confirmed', 'in_progress', 'completed'].contains(status)
                  ? _requestDateRange(r)
                  : (() {
                      final d = (r['preferredDate'] as Timestamp).toDate();
                      final day = DateTime(d.year, d.month, d.day);
                      return (day, day);
                    })();
              for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
                byDay.putIfAbsent(d, () => []).add(r);
              }
            }

            final sortedRequests = [...requests]..sort((a, b) {
                final da = a['preferredDate'];
                final db = b['preferredDate'];
                if (da is! Timestamp) return 1;
                if (db is! Timestamp) return -1;
                return da.compareTo(db);
              });

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _MonthCalendar(
                  visibleMonth: _visibleMonth,
                  byDay: byDay,
                  onPrevMonth: () => setState(() => _visibleMonth =
                      DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1)),
                  onNextMonth: () => setState(() => _visibleMonth =
                      DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1)),
                  onDayTap: (day, dayRequests) =>
                      _showDayDetail(context, day, dayRequests),
                ),
                const SizedBox(height: 10),
                const _LegendRow(),
                const SizedBox(height: 24),
                const Text('Toutes les commandes',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (sortedRequests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text('Aucune commande pour le moment',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
                  )
                else
                  ...sortedRequests.map((r) => _OrderRow(
                      request: r, onTap: () => _showRequestDetail(context, r))),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showDayDetail(
      BuildContext context, DateTime day, List<Map<String, dynamic>> dayRequests) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatFullFrenchDate(day),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
                dayRequests.length > 1
                    ? '${dayRequests.length} commandes ce jour — vérifiez votre capacité'
                    : '1 commande ce jour',
                style: TextStyle(
                    fontSize: 12,
                    color: dayRequests.length > 1 ? AppColors.danger : AppColors.textSecondary)),
            const SizedBox(height: 14),
            ...dayRequests.map((r) => _OrderRow(
                request: r,
                onTap: () {
                  Navigator.pop(ctx);
                  _showRequestDetail(context, r);
                })),
          ],
        ),
      ),
    );
  }

  void _showRequestDetail(BuildContext context, Map<String, dynamic> request) {
    final categoryId = request['categoryId'] as String?;
    final category = categoryId != null ? BigServiceCategory.byId(categoryId) : null;
    final clientName = request['clientName'] as String? ?? 'Client';
    final clientPhone = request['clientPhone'] as String? ?? '';
    final address = request['address'] as String? ?? request['city'] as String? ?? '';
    final description = request['description'] as String? ?? '';
    final status = request['status'] as String? ?? 'new';
    final price = (request['quotedPriceMAD'] as num?)?.toDouble();
    final preferredDate = request['preferredDate'];
    final preferredTime = request['preferredTime'] as String? ?? '';
    final durationValue = (request['durationValue'] as num?)?.toDouble() ?? 0;
    final durationUnit = request['durationUnit'] as String? ?? '';
    String scheduleLabel = '';
    if (preferredDate is Timestamp) {
      final dateStr = DateFormat('dd/MM/yyyy').format(preferredDate.toDate());
      scheduleLabel = preferredTime.isNotEmpty ? '$dateStr à $preferredTime' : dateStr;
      if (durationValue > 0 &&
          ['confirmed', 'in_progress', 'completed'].contains(status)) {
        final (start, end) = _requestDateRange(request);
        if (!_MonthCalendar._isSameDay(start, end)) {
          scheduleLabel +=
              '  →  ${DateFormat('dd/MM/yyyy').format(end)} (${durationValue % 1 == 0 ? durationValue.toStringAsFixed(0) : durationValue.toStringAsFixed(1)} $durationUnit)';
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(category?.label ?? 'Grand service',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 12),
              _DetailLine(icon: Icons.person_rounded, text: clientName),
              if (scheduleLabel.isNotEmpty)
                _DetailLine(icon: Icons.event_rounded, text: scheduleLabel),
              if (address.isNotEmpty)
                _DetailLine(icon: Icons.location_on_rounded, text: address),
              if (clientPhone.isNotEmpty)
                _DetailLine(icon: Icons.phone_rounded, text: clientPhone),
              if (price != null)
                _DetailLine(
                    icon: Icons.payments_rounded, text: '${price.toStringAsFixed(0)} MAD'),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                  child: Text(description, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.visibleMonth,
    required this.byDay,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onDayTap,
  });

  final DateTime visibleMonth;
  final Map<DateTime, List<Map<String, dynamic>>> byDay;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final void Function(DateTime day, List<Map<String, dynamic>> requests) onDayTap;

  static const _weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  static const _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onPrevMonth,
                icon: const Icon(Icons.chevron_left_rounded),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text('${_months[visibleMonth.month - 1]} ${visibleMonth.year}',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              IconButton(
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _weekdayLabels
                .map((l) => Expanded(
                      child: Center(
                        child: Text(l,
                            style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingBlanks + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemBuilder: (context, i) {
              if (i < leadingBlanks) return const SizedBox.shrink();
              final dayNum = i - leadingBlanks + 1;
              final day = DateTime(visibleMonth.year, visibleMonth.month, dayNum);
              final dayRequests = byDay[day] ?? const [];
              final count = dayRequests.length;

              final (bg, fg) = switch (count) {
                0 => (AppColors.background, AppColors.textSecondary),
                1 => (const Color(0xFFFFF3D6), const Color(0xFF8A6D1E)),
                _ => (AppColors.dangerLight, AppColors.danger),
              };
              final isToday = _isSameDay(day, DateTime.now());

              return GestureDetector(
                onTap: count > 0 ? () => onDayTap(day, dayRequests) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(9),
                    border: isToday ? Border.all(color: AppColors.primary, width: 1.6) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text('$dayNum',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: count > 0 ? FontWeight.w800 : FontWeight.w500,
                          color: fg)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _LegendDot(color: AppColors.background, label: 'Libre'),
        SizedBox(width: 14),
        _LegendDot(color: Color(0xFFFFF3D6), label: '1 commande'),
        SizedBox(width: 14),
        _LegendDot(color: AppColors.dangerLight, label: '2+ — vérifiez'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.request, required this.onTap});
  final Map<String, dynamic> request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryId = request['categoryId'] as String?;
    final category = categoryId != null ? BigServiceCategory.byId(categoryId) : null;
    final clientName = request['clientName'] as String? ?? 'Client';
    final status = request['status'] as String? ?? 'new';
    final preferredDate = request['preferredDate'];
    final preferredTime = request['preferredTime'] as String? ?? '';
    final dateLabel = preferredDate is Timestamp
        ? '${DateFormat('dd/MM/yyyy').format(preferredDate.toDate())}${preferredTime.isNotEmpty ? ' · $preferredTime' : ''}'
        : 'Date non précisée';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clientName,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${category?.label ?? 'Grand service'} · $dateLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              _StatusBadge(status: status),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'quoted' => (const Color(0xFFE8EDFB), const Color(0xFF2B4EAE), 'Devis envoyé'),
      'confirmed' => (AppColors.primaryLight, AppColors.primary, 'Confirmée'),
      'in_progress' => (AppColors.gold.withOpacity(0.15), AppColors.gold, 'En cours'),
      'completed' => (const Color(0xFFE0F5EF), const Color(0xFF0E7C66), 'Terminée'),
      'declined' => (AppColors.background, AppColors.textMuted, 'Refusée'),
      _ => (AppColors.dangerLight, AppColors.danger, 'Nouveau'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}