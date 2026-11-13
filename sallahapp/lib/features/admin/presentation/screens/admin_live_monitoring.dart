import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/firestore_service.dart';

// ── Timeout rules per status ─────────────────────────────────────
const _timeouts = {
  'pending':     Duration(minutes: 5),
  'accepted':    Duration(minutes: 10),
  'en_route':    Duration(minutes: 15),
  'in_progress': Duration(minutes: 60),
};

// ── Colors (reuse AC from admin_shell) ──────────────────────────
class _C {
  static const bg       = Color(0xFF0D1117);
  static const surface  = Color(0xFF161B22);
  static const surface2 = Color(0xFF21262D);
  static const border   = Color(0xFF30363D);
  static const text     = Color(0xFFE6EDF3);
  static const muted    = Color(0xFF8B949E);
  static const green    = Color(0xFF3FB950);
  static const greenBg  = Color(0xFF0F2A14);
  static const red      = Color(0xFFF85149);
  static const redBg    = Color(0xFF2A0F0F);
  static const gold     = Color(0xFFD29922);
  static const goldBg   = Color(0xFF2A1F0D);
  static const blue     = Color(0xFF58A6FF);
  static const blueBg   = Color(0xFF0D1F3A);
}

// ================================================================
// LIVE MONITORING TAB
// ================================================================
class AdminLiveMonitoringTab extends StatefulWidget {
  const AdminLiveMonitoringTab({super.key, required this.fs});
  final FirestoreService fs;
  @override
  State<AdminLiveMonitoringTab> createState() => _AdminLiveMonitoringTabState();
}

class _AdminLiveMonitoringTabState extends State<AdminLiveMonitoringTab> {
  // Ticks every second to refresh timers
  Timer? _ticker;
  DateTime _now = DateTime.now();
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.fs.streamAllRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _C.red)));
        }

        final all = snapshot.data ?? [];
        // Only active orders
        final active = all.where((r) =>
          ['pending', 'accepted', 'en_route', 'in_progress'].contains(r['status'] as String? ?? '')
        ).toList();

        // Compute alerts
        final alerts = active.where((r) => _isAlert(r)).toList();
        final warnings = active.where((r) => _isWarning(r) && !_isAlert(r)).toList();
        final healthy = active.where((r) => !_isWarning(r) && !_isAlert(r)).toList();

        // Filter
        List<Map<String, dynamic>> displayed;
        switch (_filter) {
          case 'alert':   displayed = alerts; break;
          case 'warning': displayed = warnings; break;
          case 'healthy': displayed = healthy; break;
          default:        displayed = active;
        }

        // Sort: alerts first, then warnings, then healthy
        displayed.sort((a, b) {
          final aScore = _isAlert(a) ? 0 : _isWarning(a) ? 1 : 2;
          final bScore = _isAlert(b) ? 0 : _isWarning(b) ? 1 : 2;
          return aScore.compareTo(bScore);
        });

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Header ──
            Row(children: [
              const Text('🔴 Live Monitoring', style: TextStyle(
                color: _C.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              const SizedBox(width: 10),
              _dot(active.isNotEmpty),
              const Spacer(),
              Text('${active.length} active', style: const TextStyle(color: _C.muted, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            const Text(
              'Real-time view of all ongoing orders. Timers show time elapsed in current status.',
              style: TextStyle(color: _C.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 16),

            // ── Summary cards ──
            Row(children: [
              _SummaryCard(label: 'Total Active', value: '${active.length}', color: _C.blue, bg: _C.blueBg),
              const SizedBox(width: 10),
              _SummaryCard(label: '🚨 Alert', value: '${alerts.length}', color: _C.red, bg: _C.redBg),
              const SizedBox(width: 10),
              _SummaryCard(label: '⚠️ Warning', value: '${warnings.length}', color: _C.gold, bg: _C.goldBg),
              const SizedBox(width: 10),
              _SummaryCard(label: '✅ Healthy', value: '${healthy.length}', color: _C.green, bg: _C.greenBg),
            ]),
            const SizedBox(height: 16),

            // ── Timeout rules legend ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: _C.muted, size: 15),
                const SizedBox(width: 8),
                const Text('Timeout rules: ', style: TextStyle(color: _C.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                _ruleChip('pending', '5 min', _C.gold),
                const SizedBox(width: 6),
                _ruleChip('accepted', '10 min', _C.blue),
                const SizedBox(width: 6),
                _ruleChip('en_route', '15 min', _C.green),
                const SizedBox(width: 6),
                _ruleChip('in_progress', '60 min', _C.muted),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Filter chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterChip('all', 'All (${active.length})', _filter, (f) => setState(() => _filter = f)),
                const SizedBox(width: 8),
                _FilterChip('alert', '🚨 Alert (${alerts.length})', _filter, (f) => setState(() => _filter = f), color: _C.red, bg: _C.redBg),
                const SizedBox(width: 8),
                _FilterChip('warning', '⚠️ Warning (${warnings.length})', _filter, (f) => setState(() => _filter = f), color: _C.gold, bg: _C.goldBg),
                const SizedBox(width: 8),
                _FilterChip('healthy', '✅ Healthy (${healthy.length})', _filter, (f) => setState(() => _filter = f), color: _C.green, bg: _C.greenBg),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Order cards ──
            if (displayed.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
                child: Column(children: [
                  Icon(_filter == 'alert' ? Icons.check_circle_rounded : Icons.live_tv_rounded,
                    color: _filter == 'alert' ? _C.green : _C.muted, size: 40),
                  const SizedBox(height: 12),
                  Text(_filter == 'alert' ? 'No alerts — all orders are on track 🎉' : 'No active orders',
                    style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              )
            else
              ...displayed.map((r) => _OrderMonitorCard(
                order: r, now: _now, fs: widget.fs,
                onBan: (uid, collection, name) => _banDialog(context, uid: uid, collection: collection, name: name),
              )),
          ],
        );
      },
    );
  }

  // ── Alert: exceeded timeout ──────────────────────────────────
  bool _isAlert(Map<String, dynamic> r) {
    final elapsed = _elapsedInStatus(r);
    final timeout = _timeouts[r['status'] as String? ?? ''];
    if (elapsed == null || timeout == null) return false;
    return elapsed > timeout;
  }

  // ── Warning: >70% of timeout ─────────────────────────────────
  bool _isWarning(Map<String, dynamic> r) {
    final elapsed = _elapsedInStatus(r);
    final timeout = _timeouts[r['status'] as String? ?? ''];
    if (elapsed == null || timeout == null) return false;
    return elapsed > timeout * 0.7;
  }

  Duration? _elapsedInStatus(Map<String, dynamic> r) {
    final ts = r['updatedAt'] ?? r['createdAt'];
    if (ts is! Timestamp) return null;
    return _now.difference(ts.toDate());
  }

  Widget _dot(bool active) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(
      color: active ? _C.green : _C.muted,
      shape: BoxShape.circle,
      boxShadow: active ? [BoxShadow(color: _C.green.withOpacity(0.5), blurRadius: 6)] : null,
    ),
  );

  Widget _ruleChip(String label, String time, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
    child: Text('$label: $time', style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
  );

  Future<void> _banDialog(BuildContext context, {required String uid, required String collection, required String name}) async {
    final ctrl = TextEditingController();
    int duration = 7;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: _C.surface,
        title: Text('Ban $name', style: const TextStyle(color: _C.text)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: ctrl, autofocus: true, maxLines: 2,
            style: const TextStyle(color: _C.text),
            decoration: const InputDecoration(labelText: 'Reason *', labelStyle: TextStyle(color: _C.muted))),
          const SizedBox(height: 14),
          const Text('Duration', style: TextStyle(color: _C.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [for (final d in [1, 3, 7, 30, 0])
            GestureDetector(onTap: () => set(() => duration = d), child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: duration == d ? _C.redBg : _C.surface2,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: duration == d ? _C.red : _C.border),
              ),
              child: Text(d == 0 ? 'Permanent' : '${d}d',
                style: TextStyle(color: duration == d ? _C.red : _C.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () { if (ctrl.text.trim().isEmpty) return; Navigator.pop(ctx, true); },
            child: const Text('Ban', style: TextStyle(color: _C.red, fontWeight: FontWeight.w800))),
        ],
      ),
    ));
    if (ok != true) return;
    final bannedUntil = duration == 0 ? null : Timestamp.fromDate(DateTime.now().add(Duration(days: duration)));
    await FirebaseFirestore.instance.collection(collection).doc(uid).update({
      'isBanned': true, 'isSuspended': true, 'banReason': ctrl.text.trim(),
      'bannedAt': FieldValue.serverTimestamp(), 'bannedUntil': bannedUntil,
      'banDurationDays': duration, 'bannedBy': FirebaseAuth.instance.currentUser?.uid,
      if (collection == 'technicians') 'isOnline': false,
    });
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name banned ✓'),
        backgroundColor: _C.surface2, behavior: SnackBarBehavior.floating));
  }
}

// ── Summary card ─────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.color, required this.bg});
  final String label, value; final Color color, bg;
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: _C.muted, fontSize: 11), textAlign: TextAlign.center),
    ]),
  ));
}

// ── Filter chip ──────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip(this.value, this.label, this.current, this.onTap, {this.color = _C.blue, this.bg = _C.blueBg});
  final String value, label, current; final ValueChanged<String> onTap; final Color color, bg;
  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? bg : _C.surface2,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: sel ? color : _C.border),
        ),
        child: Text(label, style: TextStyle(color: sel ? color : _C.muted, fontSize: 12.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

// ── Individual order monitor card ────────────────────────────────
class _OrderMonitorCard extends StatelessWidget {
  const _OrderMonitorCard({
    super.key, required this.order, required this.now,
    required this.fs, required this.onBan,
  });
  final Map<String, dynamic> order;
  final DateTime now;
  final FirestoreService fs;
  final void Function(String uid, String collection, String name) onBan;

  Duration? get _elapsed {
    final ts = order['updatedAt'] ?? order['createdAt'];
    if (ts is! Timestamp) return null;
    return now.difference(ts.toDate());
  }

  Duration? get _timeout => _timeouts[order['status'] as String? ?? ''];

  bool get isAlert {
    final e = _elapsed; final t = _timeout;
    return e != null && t != null && e > t;
  }

  bool get isWarning {
    final e = _elapsed; final t = _timeout;
    return e != null && t != null && e > t * 0.7 && !isAlert;
  }

  Color get _borderColor => isAlert ? _C.red : isWarning ? _C.gold : _C.border;
  Color get _bgColor => isAlert ? _C.redBg.withOpacity(0.5) : isWarning ? _C.goldBg.withOpacity(0.3) : _C.surface;

  String _formatElapsed(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  String _formatTimeout(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h';
    return '${d.inMinutes}m';
  }

  double get _progress {
    final e = _elapsed; final t = _timeout;
    if (e == null || t == null) return 0;
    return (e.inSeconds / t.inSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final status    = order['status'] as String? ?? '';
    final service   = order['serviceLabel'] as String? ?? 'Service';
    final clientId  = order['clientId'] as String? ?? '';
    final clientName= order['clientName'] as String? ?? 'Client';
    final techId    = order['techId'] as String? ?? '';
    final price     = (order['priceQuoteMAD'] as num?)?.toDouble() ?? 0;
    final requestId = order['requestId'] as String? ?? '';
    final createdAt = order['createdAt'];
    final createdStr = createdAt is Timestamp
        ? DateFormat('HH:mm dd/MM').format(createdAt.toDate()) : '—';
    final elapsed   = _elapsed;
    final timeout   = _timeout;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: isAlert ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Card header ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            // Alert indicator
            if (isAlert) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _C.red, borderRadius: BorderRadius.circular(6)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.warning_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('TIMEOUT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(width: 8),
            ] else if (isWarning) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _C.goldBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: _C.gold)),
                child: const Text('⚠️ SLOW', style: TextStyle(color: _C.gold, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
            ],
            // Status badge
            _StatusBadge(status),
            const SizedBox(width: 8),
            Expanded(child: Text(service, style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w800))),
            // Price
            Text('${price.toStringAsFixed(0)} MAD', style: const TextStyle(color: _C.muted, fontSize: 12.5)),
            const SizedBox(width: 8),
            // Request ID
            Text('#${requestId.substring(0, 6)}', style: const TextStyle(color: _C.muted, fontSize: 10)),
          ]),
        ),

        // ── Timer bar ────────────────────────────────────────────
        if (elapsed != null && timeout != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(
                    'Time in status: ${_formatElapsed(elapsed)}',
                    style: TextStyle(
                      color: isAlert ? _C.red : isWarning ? _C.gold : _C.muted,
                      fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const Text(' / ', style: TextStyle(color: _C.muted, fontSize: 12)),
                  Text(_formatTimeout(timeout), style: const TextStyle(color: _C.muted, fontSize: 12)),
                  if (isAlert) ...[
                    const SizedBox(width: 6),
                    Text(
                      '+${_formatElapsed(elapsed - timeout)} over',
                      style: const TextStyle(color: _C.red, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 5,
                    backgroundColor: _C.surface2,
                    color: isAlert ? _C.red : isWarning ? _C.gold : _C.green,
                  ),
                ),
              ])),
              const SizedBox(width: 12),
              // Big timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isAlert ? _C.red : isWarning ? _C.goldBg : _C.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: isWarning && !isAlert ? Border.all(color: _C.gold) : null,
                ),
                child: Text(
                  _formatElapsed(elapsed),
                  style: TextStyle(
                    color: isAlert ? Colors.white : isWarning ? _C.gold : _C.muted,
                    fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
        ],

        const Divider(height: 1, color: _C.border),

        // ── People involved ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Client
            Expanded(child: _PersonCard(
              role: 'CLIENT',
              name: clientName,
              uid: clientId,
              collection: 'users',
              color: _C.blue,
              icon: Icons.person_rounded,
              isAlert: isAlert,
              onBan: onBan,
            )),
            const SizedBox(width: 10),
            // Arrow
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Icon(
                status == 'en_route' ? Icons.arrow_forward_rounded : Icons.compare_arrows_rounded,
                color: isAlert ? _C.red : _C.muted, size: 20),
            ),
            const SizedBox(width: 10),
            // Technician
            Expanded(child: techId.isEmpty
              ? _EmptyPersonCard(role: 'TECHNICIAN', color: _C.muted)
              : _TechPersonCard(
                  techId: techId, isAlert: isAlert,
                  onBan: onBan,
                )),
          ]),
        ),

        // ── Footer: created at + actions ─────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(children: [
            const Icon(Icons.access_time_rounded, color: _C.muted, size: 13),
            const SizedBox(width: 4),
            Text('Created: $createdStr', style: const TextStyle(color: _C.muted, fontSize: 11.5)),
            const Spacer(),
            if (isAlert || isWarning)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.red,
                  side: const BorderSide(color: _C.red),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _cancelOrder(context, requestId),
                icon: const Icon(Icons.cancel_rounded, size: 14),
                label: const Text('Force Cancel', style: TextStyle(fontSize: 12)),
              ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _cancelOrder(BuildContext context, String requestId) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _C.surface,
      title: const Text('Force cancel?', style: TextStyle(color: _C.text)),
      content: const Text('The order will be cancelled and both client and technician notified.', style: TextStyle(color: _C.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel Order', style: TextStyle(color: _C.red))),
      ],
    ));
    if (ok == true) await fs.adminCancelRequest(requestId);
  }
}

// ── Status badge ─────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'pending'     => ('⏳ Pending',      _C.gold,  _C.goldBg),
      'accepted'    => ('✅ Accepted',     _C.green, _C.greenBg),
      'en_route'    => ('🚗 En Route',     _C.blue,  _C.blueBg),
      'in_progress' => ('🔧 In Progress',  _C.blue,  _C.blueBg),
      _             => (status,            _C.muted, _C.surface2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Person card (client) ─────────────────────────────────────────
class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.role, required this.name, required this.uid,
    required this.collection, required this.color, required this.icon,
    required this.isAlert, required this.onBan,
  });
  final String role, name, uid, collection;
  final Color color;
  final IconData icon;
  final bool isAlert;
  final void Function(String, String, String) onBan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface2, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isAlert ? color.withOpacity(0.4) : _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(role, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(name, style: const TextStyle(color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
        ]),
        if (isAlert) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _C.red, backgroundColor: _C.redBg,
              padding: const EdgeInsets.symmetric(vertical: 4),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => onBan(uid, collection, name),
            child: const Text('🚫 Ban', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          )),
        ],
      ]),
    );
  }
}

// ── Tech person card (loads from Firestore) ──────────────────────
class _TechPersonCard extends StatelessWidget {
  const _TechPersonCard({required this.techId, required this.isAlert, required this.onBan});
  final String techId; final bool isAlert;
  final void Function(String, String, String) onBan;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('technicians').doc(techId).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final name = data?['fullName'] as String? ?? 'Technician';
        final isOnline = data?['isOnline'] as bool? ?? false;
        final rating = (data?['rating'] as num?)?.toDouble() ?? 5.0;
        final jobs = (data?['jobsDone'] as num?)?.toInt() ?? 0;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _C.surface2, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isAlert ? _C.green.withOpacity(0.4) : _C.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('TECHNICIAN', style: TextStyle(color: _C.green, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              const Spacer(),
              Container(width: 6, height: 6, decoration: BoxDecoration(
                color: isOnline ? _C.green : _C.muted, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.engineering_rounded, color: _C.green, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(name, style: const TextStyle(color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Text('${rating.toStringAsFixed(1)}★ · $jobs jobs', style: const TextStyle(color: _C.muted, fontSize: 10.5)),
            if (isAlert) ...[
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: _C.red, backgroundColor: _C.redBg,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => onBan(techId, 'technicians', name),
                child: const Text('🚫 Ban', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              )),
            ],
          ]),
        );
      },
    );
  }
}

// ── Empty person card (no tech assigned yet) ─────────────────────
class _EmptyPersonCard extends StatelessWidget {
  const _EmptyPersonCard({required this.role, required this.color});
  final String role; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: _C.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(role, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      const SizedBox(height: 10),
      const Row(children: [
        Icon(Icons.hourglass_top_rounded, color: _C.muted, size: 16),
        SizedBox(width: 6),
        Text('Awaiting...', style: TextStyle(color: _C.muted, fontSize: 12.5, fontStyle: FontStyle.italic)),
      ]),
    ]),
  );
}