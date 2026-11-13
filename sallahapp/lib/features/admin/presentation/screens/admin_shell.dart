import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import 'admin_analytics_tab.dart';
import '../../../../models/technician_profile.dart';
import '../../../../models/technician_specialty.dart';
import '../../../../models/technician_skill.dart';
import '../../../../models/company_profile.dart';
import '../../../../models/big_service_category.dart';
import '../../../../core/services/storage_service.dart';
import 'package:video_player/video_player.dart';
import 'admin_live_monitoring.dart';

// ── Admin Dark Theme Colors ──────────────────────────────────────
class AC {
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
  static const blue     = Color(0xFF58A6FF);
  static const blueBg   = Color(0xFF0D1F3A);
  static const gold     = Color(0xFFD29922);
  static const goldBg   = Color(0xFF2A1F0D);
  static const purple   = Color(0xFFBC8CFF);
  static const purpleBg = Color(0xFF1A0F2A);
}

const _heading = TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AC.text, letterSpacing: -0.3);
const _label = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AC.muted, letterSpacing: 0.6);

ThemeData adminTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AC.bg,
  colorScheme: const ColorScheme.dark(primary: AC.blue, surface: AC.surface, background: AC.bg),
  appBarTheme: const AppBarTheme(backgroundColor: AC.surface, foregroundColor: AC.text, elevation: 0, surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.text, letterSpacing: -0.2)),
  navigationRailTheme: const NavigationRailThemeData(backgroundColor: AC.surface,
    selectedIconTheme: IconThemeData(color: AC.blue, size: 20), unselectedIconTheme: IconThemeData(color: AC.muted, size: 20),
    selectedLabelTextStyle: TextStyle(color: AC.blue, fontSize: 9, fontWeight: FontWeight.w700),
    unselectedLabelTextStyle: TextStyle(color: AC.muted, fontSize: 9), indicatorColor: AC.blueBg),
  dividerTheme: const DividerThemeData(color: AC.border, space: 1),
  inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: AC.surface2,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AC.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AC.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AC.blue, width: 1.5)),
    labelStyle: const TextStyle(color: AC.muted, fontSize: 13), hintStyle: const TextStyle(color: AC.muted, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
  elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AC.blue, foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), elevation: 0)),
  outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: AC.text, side: const BorderSide(color: AC.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
  textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AC.blue,
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? AC.green : AC.muted),
    trackColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? AC.greenBg : AC.surface2)),
  checkboxTheme: CheckboxThemeData(
    fillColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? AC.blue : AC.surface2),
    side: const BorderSide(color: AC.border)),
  snackBarTheme: SnackBarThemeData(backgroundColor: AC.surface2, contentTextStyle: const TextStyle(color: AC.text, fontSize: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), behavior: SnackBarBehavior.floating),
  dialogTheme: DialogThemeData(backgroundColor: AC.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AC.text)),
  dropdownMenuTheme: const DropdownMenuThemeData(menuStyle: MenuStyle(backgroundColor: MaterialStatePropertyAll(AC.surface2))),
  cardTheme: CardThemeData(color: AC.surface, elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AC.border))),
  chipTheme: ChipThemeData(backgroundColor: AC.surface2, selectedColor: AC.blueBg,
    labelStyle: const TextStyle(color: AC.text, fontSize: 12), side: const BorderSide(color: AC.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AC.text, fontSize: 14), bodyMedium: TextStyle(color: AC.text, fontSize: 13),
    bodySmall: TextStyle(color: AC.muted, fontSize: 11.5), titleLarge: TextStyle(color: AC.text, fontSize: 20, fontWeight: FontWeight.w800),
    titleMedium: TextStyle(color: AC.text, fontSize: 15, fontWeight: FontWeight.w700)),
);

class ACard extends StatelessWidget {
  const ACard({super.key, required this.child, this.padding, this.color, this.border});
  final Widget child; final EdgeInsetsGeometry? padding; final Color? color; final Border? border;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(color: color ?? AC.surface, borderRadius: BorderRadius.circular(12), border: border ?? Border.all(color: AC.border)),
    child: child);
}

class AStatCard extends StatelessWidget {
  const AStatCard({super.key, required this.icon, required this.label, required this.value, required this.iconColor, required this.iconBg, this.sub});
  final IconData icon; final String label, value; final Color iconColor, iconBg; final String? sub;
  @override
  Widget build(BuildContext context) => ACard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 18)),
        if (sub != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(99)),
          child: Text(sub!, style: const TextStyle(color: AC.muted, fontSize: 10, fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 14),
      Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AC.text, letterSpacing: -0.5)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 12, color: AC.muted)),
    ]));
}

class ABadge extends StatelessWidget {
  const ABadge({super.key, required this.label, required this.color, required this.bg});
  final String label; final Color color, bg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)));
}

Widget statusBadge(String status) => switch (status) {
  'pending'     => const ABadge(label: '⏳ Pending',     color: AC.gold,  bg: AC.goldBg),
  'accepted'    => const ABadge(label: '✅ Accepted',    color: AC.green, bg: AC.greenBg),
  'en_route'    => const ABadge(label: '🚗 En Route',    color: AC.blue,  bg: AC.blueBg),
  'in_progress' => const ABadge(label: '🔧 In Progress', color: AC.blue,  bg: AC.blueBg),
  'completed'   => const ABadge(label: '✔️ Completed',  color: AC.green, bg: AC.greenBg),
  'cancelled'   => const ABadge(label: '❌ Cancelled',   color: AC.red,   bg: AC.redBg),
  _             => ABadge(label: status, color: AC.muted, bg: AC.surface2),
};

class AAvatar extends StatelessWidget {
  const AAvatar({super.key, this.url, required this.name, this.radius = 18});
  final String? url; final String name; final double radius;
  @override
  Widget build(BuildContext context) => CircleAvatar(radius: radius, backgroundColor: AC.blueBg,
    backgroundImage: url != null ? NetworkImage(url!) : null,
    child: url == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: AC.blue, fontSize: radius * 0.7, fontWeight: FontWeight.w800)) : null);
}

class ASectionHeader extends StatelessWidget {
  const ASectionHeader({super.key, required this.title, this.action, this.count});
  final String title; final Widget? action; final int? count;
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title, style: _heading),
    if (count != null) ...[const SizedBox(width: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(99), border: Border.all(color: AC.border)),
        child: Text('$count', style: const TextStyle(color: AC.muted, fontSize: 11, fontWeight: FontWeight.w700)))],
    const Spacer(),
    if (action != null) action!,
  ]);
}

class AFilterBar extends StatelessWidget {
  const AFilterBar({super.key, required this.filters, required this.current, required this.onSelect});
  final List<(String, String)> filters; final String current; final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(scrollDirection: Axis.horizontal,
    child: Row(children: filters.map((f) {
      final sel = current == f.$1;
      return Padding(padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(onTap: () => onSelect(f.$1),
          child: AnimatedContainer(duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: sel ? AC.blueBg : AC.surface2, borderRadius: BorderRadius.circular(99), border: Border.all(color: sel ? AC.blue : AC.border)),
            child: Text(f.$2, style: TextStyle(color: sel ? AC.blue : AC.muted, fontSize: 12.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)))));
    }).toList()));
}

class AListTile extends StatelessWidget {
  const AListTile({super.key, required this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.highlight = false});
  final Widget leading, title; final Widget? subtitle, trailing; final VoidCallback? onTap; final bool highlight;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? AC.blue.withOpacity(0.4) : AC.border)),
      child: Row(children: [
        leading, const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title, if (subtitle != null) ...[const SizedBox(height: 2), subtitle!]])),
        if (trailing != null) trailing!])));
}

class AError extends StatelessWidget {
  const AError({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.lock_rounded, color: AC.muted, size: 36), const SizedBox(height: 12),
      const Text('Access denied or error', style: TextStyle(color: AC.text, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Add your UID to the "admins" collection in Firestore.\n$message',
        textAlign: TextAlign.center, style: const TextStyle(color: AC.muted, fontSize: 12.5))])));
}

class AEmpty extends StatelessWidget {
  const AEmpty({super.key, required this.icon, required this.label, this.sub});
  final IconData icon; final String label; final String? sub;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(48),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AC.muted, size: 40), const SizedBox(height: 14),
      Text(label, style: const TextStyle(color: AC.text, fontSize: 14, fontWeight: FontWeight.w700)),
      if (sub != null) ...[const SizedBox(height: 4), Text(sub!, textAlign: TextAlign.center, style: const TextStyle(color: AC.muted, fontSize: 12.5))]])));
}

class AMiniChart extends StatelessWidget {
  const AMiniChart({super.key, required this.values, required this.labels, this.color = AC.blue});
  final List<double> values; final List<String> labels; final Color color;
  @override
  Widget build(BuildContext context) {
    final max = values.fold(0.0, (a, b) => b > a ? b : a);
    return SizedBox(height: 120, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < values.length; i++) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (values[i] > 0) Text(values[i].toStringAsFixed(0), style: const TextStyle(color: AC.muted, fontSize: 9)),
          const SizedBox(height: 3),
          AnimatedContainer(duration: Duration(milliseconds: 400 + i * 60),
            height: max == 0 ? 4 : (values[i] / max * 72).clamp(4, 72),
            decoration: BoxDecoration(color: i == values.length - 1 ? color : color.withOpacity(0.35), borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          Text(labels[i], style: const TextStyle(color: AC.muted, fontSize: 9.5, fontWeight: FontWeight.w600))])))
    ]));
  }
}

// ================================================================
// ADMIN SHELL
// ================================================================
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  final _fs = FirestoreService();
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Widget get _body => switch (_index) {
    0  => AdminLiveMonitoringTab(fs: _fs),
    1  => _OverviewTab(fs: _fs),
    2  => _VerificationsTab(fs: _fs),
    3  => _TechniciansTab(fs: _fs),
    4  => _OrdersTab(fs: _fs),
    5  => _CompaniesTab(fs: _fs),
    6  => _ReportsTab(fs: _fs),
    7  => _SpecialtyApprovalsTab(fs: _fs),
    8  => _PromosTab(fs: _fs),
    9  => _UsersTab(fs: _fs),
    10 => AdminAnalyticsTab(fs: _fs),
    _  => _SystemTab(fs: _fs),
  };

  @override
  Widget build(BuildContext context) => Theme(data: adminTheme(), child: Scaffold(backgroundColor: AC.bg,
    body: SafeArea(child: _uid == null ? const AError(message: 'Not signed in') : _buildLayout())));

  Widget _buildLayout() {
    final wide = MediaQuery.of(context).size.width > 640;
    if (wide) return Row(children: [
      _Sidebar(index: _index, onSelect: (i) => setState(() => _index = i), fs: _fs),
      const VerticalDivider(width: 1, color: AC.border),
      Expanded(child: _body)]);
    return Column(children: [Expanded(child: _body), _BottomBar(index: _index, onSelect: (i) => setState(() => _index = i))]);
  }
}

// ── SIDEBAR ───────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onSelect, required this.fs});
  final int index; final ValueChanged<int> onSelect; final FirestoreService fs;

  static const _nav = [
    (Icons.sensors_rounded,          'Live Monitor',  0),
    (Icons.dashboard_rounded,        'Overview',      1),
    (Icons.verified_user_rounded,    'Verifications', 2),
    (Icons.engineering_rounded,      'Technicians',   3),
    (Icons.receipt_long_rounded,     'Orders',        4),
    (Icons.apartment_rounded,        'Companies',     5),
    (Icons.flag_rounded,             'Reports',       6),
    (Icons.workspace_premium_rounded,'Specialties',   7),
    (Icons.local_offer_rounded,      'Promos',        8),
    (Icons.people_rounded,           'Clients',       9),
    (Icons.bar_chart_rounded,        'Analytics',     10),
    (Icons.settings_rounded,         'System',        11),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(width: 220, child: Container(color: AC.surface, child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 12), child: Row(children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0e8050), Color(0xFF0a6040)]),
        borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.build_rounded, color: Colors.white, size: 17)),
      const SizedBox(width: 10),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Brikol.ma', style: TextStyle(color: AC.text, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        Text('ADMIN', style: TextStyle(color: AC.muted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2))])])),
    const Divider(height: 1, color: AC.border),
    const SizedBox(height: 8),
    Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 8), children: [
      _navSection('LIVE'), _navItem(context, _nav[0]),
      _navSection('OVERVIEW'), _navItem(context, _nav[1]),
      _navSection('MANAGEMENT'),
      for (final n in _nav.sublist(2, 10)) _navItem(context, n),
      _navSection('SYSTEM'),
      _navItem(context, _nav[10]),
      _navItem(context, _nav[11]),
    ])),
    const Divider(height: 1, color: AC.border),
    Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      AAvatar(name: FirebaseAuth.instance.currentUser?.email ?? 'A', radius: 16),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'Admin',
          style: const TextStyle(color: AC.text, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        const Text('Super Admin', style: TextStyle(color: AC.muted, fontSize: 10))])),
      IconButton(icon: const Icon(Icons.logout_rounded, size: 16, color: AC.muted),
        onPressed: () => AuthService().signOut(), tooltip: 'Sign out',
        style: IconButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.all(6)))])),
  ])));

  Widget _navSection(String label) => Padding(padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
    child: Text(label, style: const TextStyle(color: AC.muted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)));

  Widget _navItem(BuildContext context, (IconData, String, int) nav) {
    final sel = index == nav.$3;
    return GestureDetector(onTap: () => onSelect(nav.$3),
      child: Container(margin: const EdgeInsets.only(bottom: 2), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: sel ? AC.blueBg : Colors.transparent, borderRadius: BorderRadius.circular(8),
          border: sel ? Border.all(color: AC.blue.withOpacity(0.3)) : null),
        child: Row(children: [
          Icon(nav.$1, size: 16, color: sel ? AC.blue : AC.muted), const SizedBox(width: 10),
          Text(nav.$2, style: TextStyle(color: sel ? AC.blue : AC.muted, fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w500))])));
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect});
  final int index; final ValueChanged<int> onSelect;
  static const _items = [
    (Icons.dashboard_rounded, 'Overview', 1), (Icons.engineering_rounded, 'Techs', 3),
    (Icons.receipt_long_rounded, 'Orders', 4), (Icons.flag_rounded, 'Reports', 6),
    (Icons.settings_rounded, 'System', 11)];
  @override
  Widget build(BuildContext context) => Container(height: 60, color: AC.surface,
    child: Row(children: _items.map((item) {
      final sel = index == item.$3;
      return Expanded(child: GestureDetector(onTap: () => onSelect(item.$3),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(item.$1, size: 20, color: sel ? AC.blue : AC.muted),
          Text(item.$2, style: TextStyle(color: sel ? AC.blue : AC.muted, fontSize: 9.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500))])));
    }).toList()));
}

// ================================================================
// 1. OVERVIEW TAB
// ================================================================
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.fs});
  final FirestoreService fs;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.streamAllRequests(),
      builder: (context, reqSnap) {
        if (reqSnap.hasError) return AError(message: reqSnap.error.toString());
        final reqs = reqSnap.data ?? [];
        final pending   = reqs.where((r) => r['status'] == 'pending').length;
        final active    = reqs.where((r) => ['accepted','en_route','in_progress'].contains(r['status'])).length;
        final completed = reqs.where((r) => r['status'] == 'completed').length;
        final revenue   = reqs.where((r) => r['status'] == 'completed').fold<double>(0, (s,r) => s + ((r['commissionMAD'] as num?)?.toDouble() ?? 0));
        final now = DateTime.now();
        final days7 = List.generate(7, (i) => DateTime(now.year, now.month, now.day - (6 - i)));
        final reqCounts = days7.map((d) => reqs.where((r) {
          final t = (r['createdAt'] as Timestamp?)?.toDate();
          return t != null && DateFormat('yyyyMMdd').format(t) == DateFormat('yyyyMMdd').format(d);
        }).length.toDouble()).toList();
        final dayLabels = days7.map((d) => DateFormat('E').format(d)[0]).toList();
        return StreamBuilder<List<TechnicianProfile>>(
          stream: fs.streamAllTechnicians(),
          builder: (context, techSnap) {
            final techs = techSnap.data ?? [];
            final online = techs.where((t) => t.isOnline).length;
            final verified = techs.where((t) => t.isVerified).length;
            return ListView(padding: const EdgeInsets.all(20), children: [
              const _MaintenanceBanner(),
              GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
                children: [
                  AStatCard(icon: Icons.payments_rounded, label: 'Commission Revenue', value: '${revenue.toStringAsFixed(0)} MAD', iconColor: AC.green, iconBg: AC.greenBg),
                  AStatCard(icon: Icons.check_circle_rounded, label: 'Completed Jobs', value: '$completed', iconColor: AC.blue, iconBg: AC.blueBg, sub: 'total'),
                  AStatCard(icon: Icons.hourglass_top_rounded, label: 'Pending', value: '$pending', iconColor: AC.gold, iconBg: AC.goldBg),
                  AStatCard(icon: Icons.bolt_rounded, label: 'Active Now', value: '$active', iconColor: AC.purple, iconBg: AC.purpleBg),
                  AStatCard(icon: Icons.engineering_rounded, label: 'Technicians', value: '${techs.length}', iconColor: AC.blue, iconBg: AC.blueBg, sub: '$verified verified'),
                  AStatCard(icon: Icons.wifi_rounded, label: 'Online Now', value: '$online', iconColor: AC.green, iconBg: AC.greenBg),
                ]),
              const SizedBox(height: 20),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: ACard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Requests — 7 days', style: TextStyle(color: AC.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  AMiniChart(values: reqCounts, labels: dayLabels.map((e) => e.toString()).toList())]))),
                const SizedBox(width: 12),
                Expanded(child: ACard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Status breakdown', style: TextStyle(color: AC.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  _StatusRow('Completed', completed, reqs.length, AC.green),
                  _StatusRow('Active', active, reqs.length, AC.blue),
                  _StatusRow('Pending', pending, reqs.length, AC.gold),
                  _StatusRow('Cancelled', reqs.where((r) => r['status'] == 'cancelled').length, reqs.length, AC.red)]))),
              ]),
              const SizedBox(height: 20),
              ACard(padding: EdgeInsets.zero, child: Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16,14,16,10), child: ASectionHeader(title: 'Recent Requests', count: reqs.length)),
                const Divider(height: 1, color: AC.border),
                ...reqs.take(8).map((r) => _OrderRow(order: r, fs: fs))])),
            ]);
          });
      });
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(this.label, this.count, this.total, this.color);
  final String label; final int count, total; final Color color;
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(children: [
      Row(children: [Text(label, style: const TextStyle(color: AC.muted, fontSize: 12)), const Spacer(),
        Text('$count', style: const TextStyle(color: AC.text, fontSize: 12, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: AC.surface2, color: color))]));
  }
}

// ================================================================
// 2. VERIFICATIONS TAB
// ================================================================
class _VerificationsTab extends StatelessWidget {
  const _VerificationsTab({required this.fs});
  final FirestoreService fs;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TechnicianProfile>>(
      stream: fs.streamPendingVerifications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return AError(message: snapshot.error.toString());
        final pending = snapshot.data ?? [];
        return ListView(padding: const EdgeInsets.all(20), children: [
          ASectionHeader(title: 'Identity Verifications', count: pending.length),
          const SizedBox(height: 16),
          if (pending.isEmpty) const AEmpty(icon: Icons.verified_user_rounded, label: 'All caught up', sub: 'No pending verifications'),
          for (final tech in pending) Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                AAvatar(url: tech.profilePhotoUrl, name: tech.fullName, radius: 22),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tech.fullName, style: const TextStyle(color: AC.text, fontSize: 14, fontWeight: FontWeight.w800)),
                  Text('${tech.city} · ${tech.phone} · ${tech.yearsExperience}y exp', style: const TextStyle(color: AC.muted, fontSize: 12))])),
                if (tech.introVideoUrl != null) IconButton(
                  onPressed: () => showDialog(context: context, builder: (_) => _VideoDialog(url: tech.introVideoUrl!)),
                  icon: const Icon(Icons.play_circle_outline_rounded, color: AC.blue, size: 20), tooltip: 'Watch intro video')])),
              const Divider(height: 1, color: AC.border),
              Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                _DocThumb(label: 'CIN', url: tech.cinPhotoUrl),
                const SizedBox(width: 10),
                _DocThumb(label: 'Diploma', url: tech.diplomaPhotoUrl)])),
              Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: Row(children: [
                Expanded(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AC.red, side: const BorderSide(color: AC.red), minimumSize: const Size(0, 42)),
                  onPressed: () async { await fs.adminRejectCin(tech.techId); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CIN rejected'))); },
                  child: const Text('Reject CIN'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AC.green, minimumSize: const Size(0, 42)),
                  onPressed: () async { await fs.adminSetVerified(tech.techId, true); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tech.fullName} verified ✓'))); },
                  child: const Text('Verify ✓')))]))
            ])),
        ]);
      });
  }
}

class _DocThumb extends StatelessWidget {
  const _DocThumb({required this.label, required this.url});
  final String label; final String? url;
  @override
  Widget build(BuildContext context) {
    if (url == null) return Container(width: 100, height: 68, decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(10)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.image_not_supported_rounded, color: AC.muted, size: 20), Text(label, style: const TextStyle(color: AC.muted, fontSize: 10))]));
    return GestureDetector(
      onTap: () => showDialog(context: context, builder: (_) => Dialog(backgroundColor: AC.bg, child: InteractiveViewer(child: Image.network(url!)))),
      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(url!, width: 100, height: 68, fit: BoxFit.cover)));
  }
}

class _VideoDialog extends StatefulWidget {
  const _VideoDialog({required this.url}); final String url;
  @override State<_VideoDialog> createState() => _VideoDialogState();
}
class _VideoDialogState extends State<_VideoDialog> {
  late final VideoPlayerController _c; bool _ready = false;
  @override void initState() { super.initState(); _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))..initialize().then((_) { if (mounted) { setState(() => _ready = true); _c.play(); } }); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Dialog(backgroundColor: Colors.black,
    child: _ready ? AspectRatio(aspectRatio: _c.value.aspectRatio, child: GestureDetector(onTap: () => _c.value.isPlaying ? _c.pause() : _c.play(), child: VideoPlayer(_c)))
      : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AC.blue))));
}

// ================================================================
// 3. TECHNICIANS TAB
// ================================================================
class _TechniciansTab extends StatefulWidget {
  const _TechniciansTab({required this.fs}); final FirestoreService fs;
  @override State<_TechniciansTab> createState() => _TechniciansTabState();
}
class _TechniciansTabState extends State<_TechniciansTab> {
  String _filter = 'all', _query = '';
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TechnicianProfile>>(
      stream: widget.fs.streamAllTechnicians(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return AError(message: snapshot.error.toString());
        var techs = snapshot.data ?? [];
        if (_filter == 'verified') techs = techs.where((t) => t.isVerified && !t.isSuspended).toList();
        if (_filter == 'pending') techs = techs.where((t) => !t.isVerified).toList();
        if (_filter == 'online') techs = techs.where((t) => t.isOnline).toList();
        if (_filter == 'suspended') techs = techs.where((t) => t.isSuspended).toList();
        if (_query.isNotEmpty) techs = techs.where((t) =>
          t.fullName.toLowerCase().contains(_query.toLowerCase()) || t.city.toLowerCase().contains(_query.toLowerCase()) || t.phone.contains(_query)).toList();
        return ListView(padding: const EdgeInsets.all(20), children: [
          ASectionHeader(title: 'Technicians', count: techs.length), const SizedBox(height: 14),
          AFilterBar(filters: const [('all','All'),('verified','✅ Verified'),('pending','⏳ Pending'),('online','🟢 Online'),('suspended','🚫 Suspended')],
            current: _filter, onSelect: (f) => setState(() => _filter = f)),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => setState(() => _query = v), style: const TextStyle(color: AC.text),
            decoration: const InputDecoration(hintText: 'Search by name, city or phone…', prefixIcon: Icon(Icons.search_rounded, size: 18, color: AC.muted))),
          const SizedBox(height: 14),
          if (techs.isEmpty) const AEmpty(icon: Icons.engineering_rounded, label: 'No technicians found'),
          ...techs.map((t) => AListTile(
            leading: AAvatar(url: t.profilePhotoUrl, name: t.fullName),
            title: Row(children: [
              Flexible(child: Text(t.fullName.isEmpty ? '(no name)' : t.fullName, style: const TextStyle(color: AC.text, fontSize: 13.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              if (t.isVerified) const Icon(Icons.verified_rounded, size: 14, color: AC.blue),
              if (t.isOnline) const Text(' 🟢', style: TextStyle(fontSize: 10)),
              if (t.isSuspended) ...[const SizedBox(width: 4), const ABadge(label: 'Suspended', color: AC.red, bg: AC.redBg)]]),
            subtitle: Text('${t.city} · ${t.rating.toStringAsFixed(1)}★ · ${t.jobsDone} jobs · ${t.walletBalance.toStringAsFixed(0)} MAD', style: const TextStyle(color: AC.muted, fontSize: 11.5)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              _IconBtn(icon: Icons.account_balance_wallet_rounded, color: AC.blue, tooltip: 'Wallet', onTap: () => _walletDialog(t)),
              _IconBtn(icon: t.isSuspended ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                color: t.isSuspended ? AC.green : AC.red, tooltip: t.isSuspended ? 'Reinstate' : 'Suspend', onTap: () => _suspendDialog(t)),
              Transform.scale(scale: 0.8, child: Switch(value: t.isVerified, activeColor: AC.blue, onChanged: (v) => widget.fs.adminSetVerified(t.techId, v)))]))),
        ]);
      });
  }

  Future<void> _suspendDialog(TechnicianProfile t) async {
    if (!t.isSuspended) {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Suspend ${t.fullName}?'),
        content: const Text('They will be taken offline and stop receiving orders.', style: TextStyle(color: AC.muted)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Suspend', style: TextStyle(color: AC.red)))]));
      if (ok != true) return;
    }
    await widget.fs.adminSetSuspended(t.techId, !t.isSuspended);
  }

  Future<void> _walletDialog(TechnicianProfile t) async {
    final amtCtrl = TextEditingController(); final noteCtrl = TextEditingController(text: 'Admin adjustment'); var credit = true;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text('Wallet — ${t.fullName}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.account_balance_wallet_rounded, color: AC.blue, size: 18), const SizedBox(width: 8),
            Text('${t.walletBalance.toStringAsFixed(2)} MAD', style: const TextStyle(color: AC.text, fontSize: 18, fontWeight: FontWeight.w800))])),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: GestureDetector(onTap: () => set(() => credit = true), child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: credit ? AC.greenBg : AC.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: credit ? AC.green : AC.border)),
            child: Center(child: Text('Credit +', style: TextStyle(color: credit ? AC.green : AC.muted, fontWeight: FontWeight.w700)))))),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(onTap: () => set(() => credit = false), child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: !credit ? AC.redBg : AC.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: !credit ? AC.red : AC.border)),
            child: Center(child: Text('Debit −', style: TextStyle(color: !credit ? AC.red : AC.muted, fontWeight: FontWeight.w700))))))]),
        const SizedBox(height: 12),
        TextField(controller: amtCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AC.text), decoration: const InputDecoration(labelText: 'Amount (MAD)')),
        const SizedBox(height: 8),
        TextField(controller: noteCtrl, style: const TextStyle(color: AC.text), decoration: const InputDecoration(labelText: 'Note'))]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final amt = double.tryParse(amtCtrl.text.trim());
          if (amt == null || amt <= 0) return;
          await widget.fs.adminAdjustWallet(techId: t.techId, amountMad: credit ? amt : -amt, note: noteCtrl.text.trim());
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${credit ? '+' : '−'}${amt.toStringAsFixed(0)} MAD applied ✓')));
        }, child: const Text('Apply'))])));
  }
}

// ================================================================
// 4. ORDERS TAB
// ================================================================
class _OrdersTab extends StatefulWidget {
  const _OrdersTab({required this.fs}); final FirestoreService fs;
  @override State<_OrdersTab> createState() => _OrdersTabState();
}
class _OrdersTabState extends State<_OrdersTab> {
  String _filter = 'all';
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.fs.streamAllRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return AError(message: snapshot.error.toString());
        var orders = snapshot.data ?? [];
        if (_filter == 'active') orders = orders.where((o) => ['pending','accepted','en_route','in_progress'].contains(o['status'])).toList();
        else if (_filter != 'all') orders = orders.where((o) => o['status'] == _filter).toList();
        return ListView(padding: const EdgeInsets.all(20), children: [
          ASectionHeader(title: 'Requests', count: orders.length), const SizedBox(height: 14),
          AFilterBar(filters: const [('all','All'),('active','Active'),('pending','Pending'),('completed','Completed'),('cancelled','Cancelled')],
            current: _filter, onSelect: (f) => setState(() => _filter = f)),
          const SizedBox(height: 14),
          if (orders.isEmpty) const AEmpty(icon: Icons.receipt_long_rounded, label: 'No orders found'),
          ...orders.map((o) => _OrderRow(order: o, fs: widget.fs))]);
      });
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.fs});
  final Map<String, dynamic> order; final FirestoreService fs;
  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? '';
    final isActive = ['pending','accepted','en_route','in_progress'].contains(status);
    final ts = order['createdAt']; final date = ts is Timestamp ? DateFormat('dd MMM HH:mm').format(ts.toDate()) : '';
    final price = (order['priceQuoteMAD'] as num?)?.toDouble() ?? 0;
    final comm = (order['commissionMAD'] as num?)?.toDouble() ?? 0;
    return AListTile(
      leading: statusBadge(status),
      title: Text(order['serviceLabel'] as String? ?? 'Service', style: const TextStyle(color: AC.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
      subtitle: Text('${order['clientName'] ?? '—'} · ${price.toStringAsFixed(0)} MAD · comm ${comm.toStringAsFixed(0)} MAD · $date', style: const TextStyle(color: AC.muted, fontSize: 11.5)),
      trailing: isActive ? _IconBtn(icon: Icons.cancel_rounded, color: AC.red, tooltip: 'Cancel', onTap: () async {
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Cancel this order?'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes', style: TextStyle(color: AC.red)))]));
        if (ok == true) await fs.adminCancelRequest(order['requestId'] as String);
      }) : null);
  }
}

// ================================================================
// 5. COMPANIES TAB
// ================================================================
class _CompaniesTab extends StatefulWidget {
  const _CompaniesTab({required this.fs}); final FirestoreService fs;
  @override State<_CompaniesTab> createState() => _CompaniesTabState();
}
class _CompaniesTabState extends State<_CompaniesTab> {
  bool _showQuotes = false;
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20,20,20,0), child: Row(children: [
      ASectionHeader(title: _showQuotes ? 'Quote Requests' : 'Partner Companies'),
      const SizedBox(width: 12),
      TextButton(onPressed: () => setState(() => _showQuotes = !_showQuotes), child: Text(_showQuotes ? 'View companies' : 'View quotes')),
      if (!_showQuotes) ElevatedButton.icon(style: ElevatedButton.styleFrom(minimumSize: const Size(0,38)),
        onPressed: () => _companyDialog(context), icon: const Icon(Icons.add_rounded, size: 15), label: const Text('Add'))])),
    const SizedBox(height: 14),
    Expanded(child: _showQuotes ? _QuotesList(fs: widget.fs) : _CompaniesList(fs: widget.fs, onEdit: _companyDialog))]);

  Future<void> _companyDialog(BuildContext context, {CompanyProfile? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final cityCtrl = TextEditingController(text: existing?.city ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    var isVerified = existing?.isVerified ?? false;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text(existing == null ? 'New Company' : 'Edit Company'),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, style: const TextStyle(color: AC.text), decoration: const InputDecoration(labelText: 'Company Name')),
        const SizedBox(height: 10),
        TextField(controller: descCtrl, maxLines: 2, style: const TextStyle(color: AC.text), decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 10),
        TextField(controller: cityCtrl, style: const TextStyle(color: AC.text), decoration: const InputDecoration(labelText: 'City')),
        TextField(controller: phoneCtrl, style: const TextStyle(color: AC.text), decoration: const InputDecoration(labelText: 'Phone')),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: isVerified, title: const Text('Verified', style: TextStyle(color: AC.text)), onChanged: (v) => set(() => isVerified = v))]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final id = existing?.companyId ?? 'company_${DateTime.now().millisecondsSinceEpoch}';
          await widget.fs.adminSaveCompany(CompanyProfile(companyId: id, name: nameCtrl.text.trim(), description: descCtrl.text.trim(), city: cityCtrl.text.trim(), phone: phoneCtrl.text.trim(), isVerified: isVerified));
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Save'))])));
  }
}

class _CompaniesList extends StatelessWidget {
  const _CompaniesList({required this.fs, required this.onEdit});
  final FirestoreService fs; final Function(BuildContext, {CompanyProfile? existing}) onEdit;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<CompanyProfile>>(
    stream: fs.streamCompanies(),
    builder: (context, snap) {
      if (snap.hasError) return AError(message: snap.error.toString());
      final list = snap.data ?? [];
      if (list.isEmpty) return const AEmpty(icon: Icons.apartment_rounded, label: 'No companies yet', sub: 'Click Add to create one');
      return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: list.length, itemBuilder: (_, i) {
        final c = list[i];
        return AListTile(
          leading: AAvatar(url: c.logoUrl, name: c.name),
          title: Row(children: [
            Text(c.name, style: const TextStyle(color: AC.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
            if (c.isVerified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 13, color: AC.blue))]),
          subtitle: Text('${c.city} · ${c.rating.toStringAsFixed(1)}★ · ${c.categories.length} categories', style: const TextStyle(color: AC.muted, fontSize: 11.5)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            _IconBtn(icon: Icons.edit_rounded, color: AC.blue, tooltip: 'Edit', onTap: () => onEdit(context, existing: c)),
            Transform.scale(scale: 0.8, child: Switch(value: c.isActive, activeColor: AC.green, onChanged: (v) => fs.adminSetCompanyActive(c.companyId, v)))]));
      });
    });
}

class _QuotesList extends StatelessWidget {
  const _QuotesList({required this.fs}); final FirestoreService fs;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: fs.streamAllQuoteRequests(),
    builder: (context, snap) {
      if (snap.hasError) return AError(message: snap.error.toString());
      final list = snap.data ?? [];
      if (list.isEmpty) return const AEmpty(icon: Icons.request_quote_rounded, label: 'No quote requests');
      return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: list.length, itemBuilder: (_, i) {
        final r = list[i]; final ts = r['createdAt']; final date = ts is Timestamp ? DateFormat('dd/MM HH:mm').format(ts.toDate()) : '';
        return AListTile(
          leading: const Icon(Icons.request_quote_rounded, color: AC.blue),
          title: Text(r['companyName'] as String? ?? '—', style: const TextStyle(color: AC.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
          subtitle: Text('${r['clientName']??'—'} · ${r['city']??'—'} · $date', style: const TextStyle(color: AC.muted, fontSize: 11.5)),
          trailing: DropdownButton<String>(value: r['status'] as String? ?? 'new',
            dropdownColor: AC.surface2, iconEnabledColor: AC.muted, style: const TextStyle(color: AC.text, fontSize: 12), underline: const SizedBox(),
            items: const [DropdownMenuItem(value:'new', child: Text('New')), DropdownMenuItem(value:'contacted', child: Text('Contacted')), DropdownMenuItem(value:'closed', child: Text('Closed'))],
            onChanged: (v) { if (v != null) fs.adminUpdateQuoteRequestStatus(r['_id'] as String, v); }));
      });
    });
}

// ================================================================
// 6. REPORTS TAB
// ================================================================
class _ReportsTab extends StatelessWidget {
  const _ReportsTab({required this.fs}); final FirestoreService fs;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: fs.streamAllReports(),
    builder: (context, snap) {
      if (snap.hasError) return AError(message: snap.error.toString());
      final all = snap.data ?? [];
      final open = all.where((r) => r['status'] == 'open').toList()..sort((a,b) => (b['urgent']==true?1:0)-(a['urgent']==true?1:0));
      final resolved = all.where((r) => r['status'] != 'open').toList();
      final urgent = open.where((r) => r['urgent'] == true).length;
      return ListView(padding: const EdgeInsets.all(20), children: [
        ASectionHeader(title: 'Reports', count: all.length, action: urgent > 0 ? ABadge(label: '🚨 $urgent urgent', color: AC.red, bg: AC.redBg) : null),
        const SizedBox(height: 16),
        if (open.isEmpty) const AEmpty(icon: Icons.flag_rounded, label: 'No open reports'),
        ...open.map((r) => _ReportCard(r: r, fs: fs, open: true)),
        if (resolved.isNotEmpty) ...[const SizedBox(height: 20),
          const Text('Resolved', style: TextStyle(color: AC.muted, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...resolved.map((r) => _ReportCard(r: r, fs: fs, open: false))]]);
    });
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.r, required this.fs, required this.open});
  final Map<String, dynamic> r; final FirestoreService fs; final bool open;
  @override
  Widget build(BuildContext context) {
    final urgent = r['urgent'] == true && open;
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: urgent ? AC.redBg : AC.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgent ? AC.red : open ? AC.red.withOpacity(0.4) : AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(urgent ? Icons.warning_rounded : Icons.flag_rounded, color: AC.red, size: 16), const SizedBox(width: 8),
          if (urgent) ...[const ABadge(label: 'URGENT', color: AC.red, bg: Colors.transparent), const SizedBox(width: 8)],
          Expanded(child: Text(r['reason'] as String? ?? 'Report', style: const TextStyle(color: AC.text, fontSize: 13.5, fontWeight: FontWeight.w800)))]),
        if ((r['comment'] as String? ?? '').isNotEmpty) ...[const SizedBox(height: 6), Text(r['comment'] as String, style: const TextStyle(color: AC.muted, fontSize: 12))],
        const SizedBox(height: 6),
        Text('Request: ${(r['requestId'] as String?)?.substring(0,8) ?? '—'}… · Tech: ${(r['techId'] as String?)?.substring(0,8) ?? '—'}…', style: const TextStyle(color: AC.muted, fontSize: 10.5)),
        if (open) ...[const SizedBox(height: 10), SizedBox(width: double.infinity,
          child: OutlinedButton(onPressed: () => fs.resolveReport(r['_reportId'] as String), child: const Text('Mark as Resolved')))]]));
  }
}

// ================================================================
// 7. SPECIALTIES TAB
// ================================================================
class _SpecialtyApprovalsTab extends StatelessWidget {
  const _SpecialtyApprovalsTab({required this.fs}); final FirestoreService fs;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<TechnicianProfile>>(
    stream: fs.streamPendingSpecialtyRequests(),
    builder: (context, snap) {
      if (snap.hasError) return AError(message: snap.error.toString());
      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AC.blue));
      final pairs = snap.data!.expand((t) => t.specialties.where((s) => s.isPending).map((s) => (t, s))).toList();
      return ListView(padding: const EdgeInsets.all(20), children: [
        ASectionHeader(title: 'Specialty Approvals', count: pairs.length), const SizedBox(height: 16),
        if (pairs.isEmpty) const AEmpty(icon: Icons.check_circle_rounded, label: 'All caught up', sub: 'No pending specialties'),
        ...pairs.map((p) => _SpecCard(tech: p.$1, spec: p.$2, fs: fs))]);
    });
}

class _SpecCard extends StatefulWidget {
  const _SpecCard({required this.tech, required this.spec, required this.fs});
  final TechnicianProfile tech; final TechnicianSpecialty spec; final FirestoreService fs;
  @override State<_SpecCard> createState() => _SpecCardState();
}
class _SpecCardState extends State<_SpecCard> {
  bool _working = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.spec; final t = widget.tech;
    return Container(margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.blue.withOpacity(0.3))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          AAvatar(url: t.profilePhotoUrl, name: t.fullName), const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.fullName, style: const TextStyle(color: AC.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
            Text('${t.city} · ${t.yearsExperience}y · ${t.jobsDone} jobs', style: const TextStyle(color: AC.muted, fontSize: 12))])),
          const ABadge(label: 'PENDING', color: AC.gold, bg: AC.goldBg)])),
        const Divider(height: 1, color: AC.border),
        Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.skillLabel, style: const TextStyle(color: AC.text, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _infoBox('Description', s.description.isEmpty ? '(none)' : s.description),
          const SizedBox(height: 8),
          _infoBox('Details / Experience', s.details.isEmpty ? '(none)' : s.details),
          if (s.diplomaImageUrl != null) ...[const SizedBox(height: 10), const Text('Document', style: _label), const SizedBox(height: 4),
            GestureDetector(onTap: () => showDialog(context: context, builder: (_) => Dialog(backgroundColor: AC.bg, child: InteractiveViewer(child: Image.network(s.diplomaImageUrl!)))),
              child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(s.diplomaImageUrl!, height: 120, width: double.infinity, fit: BoxFit.cover)))],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: AC.red, side: const BorderSide(color: AC.red), minimumSize: const Size(0,44)),
              onPressed: _working ? null : _reject, child: const Text('Reject'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AC.green, minimumSize: const Size(0,44)),
              onPressed: _working ? null : _approve,
              child: _working ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Approve ✓')))])]))]));
  }
  Widget _infoBox(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: _label), const SizedBox(height: 4),
    Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(8)),
      child: Text(value, style: const TextStyle(color: AC.text, fontSize: 13)))]);
  Future<void> _approve() async {
    setState(() => _working = true);
    try { await widget.fs.adminApproveSpecialtyV2(techId: widget.tech.techId, skillId: widget.spec.skillId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.spec.skillLabel} approved ✓')));
    } catch (e) { if (mounted) setState(() => _working = false); }
  }
  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Reject "${widget.spec.skillLabel}"?'),
      content: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: AC.text), decoration: const InputDecoration(labelText: 'Rejection reason *')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject', style: TextStyle(color: AC.red)))]));
    if (ok != true || ctrl.text.trim().isEmpty) return;
    setState(() => _working = true);
    try { await widget.fs.adminRejectSpecialtyV2(techId: widget.tech.techId, skillId: widget.spec.skillId, reason: ctrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Specialty rejected')));
    } catch (e) { if (mounted) setState(() => _working = false); }
  }
}

// ================================================================
// 8. PROMOS TAB
// ================================================================
class _PromosTab extends StatelessWidget {
  const _PromosTab({required this.fs}); final FirestoreService fs;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: fs.streamPromoCodes(),
    builder: (context, snap) {
      if (snap.hasError) return AError(message: snap.error.toString());
      final promos = snap.data ?? [];
      return ListView(padding: const EdgeInsets.all(20), children: [
        ASectionHeader(title: 'Promo Codes', count: promos.length,
          action: ElevatedButton.icon(style: ElevatedButton.styleFrom(minimumSize: const Size(0,38)),
            onPressed: () => _dialog(context), icon: const Icon(Icons.add_rounded, size: 15), label: const Text('Create'))),
        const SizedBox(height: 16),
        if (promos.isEmpty) const AEmpty(icon: Icons.local_offer_rounded, label: 'No promo codes yet'),
        ...promos.map((p) => AListTile(
          leading: Icon(Icons.local_offer_rounded, color: (p['active'] as bool? ?? false) ? AC.green : AC.muted),
          title: Text(p['code'] as String, style: const TextStyle(color: AC.text, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          subtitle: Text('−${((p['amountMAD'] as num?)?.toDouble()??0).toStringAsFixed(0)} MAD · ${(p['active'] as bool? ?? false) ? 'Active' : 'Inactive'}', style: const TextStyle(color: AC.muted, fontSize: 12)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            _IconBtn(icon: Icons.edit_rounded, color: AC.blue, tooltip: 'Edit', onTap: () => _dialog(context, existing: p)),
            _IconBtn(icon: Icons.delete_outline_rounded, color: AC.red, tooltip: 'Delete', onTap: () => fs.adminDeletePromo(p['code'] as String))])))]);
    });
  Future<void> _dialog(BuildContext context, {Map<String, dynamic>? existing}) async {
    final codeCtrl = TextEditingController(text: existing?['code'] as String? ?? '');
    final amtCtrl = TextEditingController(text: ((existing?['amountMAD'] as num?)?.toDouble()??10).toStringAsFixed(0));
    var active = existing?['active'] as bool? ?? true;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text(existing == null ? 'New Promo Code' : 'Edit Promo'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: codeCtrl, enabled: existing == null, textCapitalization: TextCapitalization.characters, style: const TextStyle(color: AC.text), decoration: const InputDecoration(labelText: 'Code (e.g. BRIKOL20)')),
        const SizedBox(height: 10),
        TextField(controller: amtCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AC.text), decoration: const InputDecoration(labelText: 'Discount (MAD)')),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: active, title: const Text('Active', style: TextStyle(color: AC.text)), onChanged: (v) => set(() => active = v))]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final code = codeCtrl.text.trim(); final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
          if (code.isEmpty || amt <= 0) return;
          await fs.adminUpsertPromo(code: code, amountMad: amt, active: active);
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Save'))])));
  }
}

// ================================================================
// 9. CLIENTS TAB
// ================================================================
class _UsersTab extends StatefulWidget {
  const _UsersTab({required this.fs}); final FirestoreService fs;
  @override State<_UsersTab> createState() => _UsersTabState();
}
class _UsersTabState extends State<_UsersTab> {
  String _query = '';
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: widget.fs.streamAllUsers(),
    builder: (context, snap) {
      if (snap.hasError) return AError(message: snap.error.toString());
      var users = (snap.data ?? []).where((u) => u['role'] == 'client' || u['role'] == null).toList();
      if (_query.isNotEmpty) users = users.where((u) =>
        (u['fullName'] as String? ?? '').toLowerCase().contains(_query.toLowerCase()) ||
        (u['phone'] as String? ?? '').contains(_query)).toList();
      return ListView(padding: const EdgeInsets.all(20), children: [
        ASectionHeader(title: 'Clients', count: users.length), const SizedBox(height: 14),
        TextField(onChanged: (v) => setState(() => _query = v), style: const TextStyle(color: AC.text),
          decoration: const InputDecoration(hintText: 'Search by name or phone…', prefixIcon: Icon(Icons.search_rounded, size: 18, color: AC.muted))),
        const SizedBox(height: 14),
        if (users.isEmpty) const AEmpty(icon: Icons.people_rounded, label: 'No clients found'),
        ...users.map((u) {
          final name = u['fullName'] as String? ?? '';
          final uid = u['uid'] as String? ?? '';
          final banned = u['isBanned'] as bool? ?? false;
          return AListTile(highlight: banned,
            leading: AAvatar(url: u['photoUrl'] as String?, name: name),
            title: Row(children: [
              Text(name.isEmpty ? '(no name)' : name, style: const TextStyle(color: AC.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
              if (banned) ...[const SizedBox(width: 6), const ABadge(label: 'Banned', color: AC.red, bg: AC.redBg)]]),
            subtitle: Text('${u['phone']??'—'} · ${u['city']??'—'}', style: const TextStyle(color: AC.muted, fontSize: 11.5)),
            trailing: banned
              ? _IconBtn(icon: Icons.check_circle_outline_rounded, color: AC.green, tooltip: 'Unban', onTap: () => unbanAccount(context, uid: uid, collection: 'users', name: name))
              : _IconBtn(icon: Icons.block_rounded, color: AC.red, tooltip: 'Ban', onTap: () => showBanDialog(context, uid: uid, collection: 'users', name: name, fs: widget.fs)));
        })]);
    });
}

// ================================================================
// 10. SYSTEM TAB
// ================================================================
class _SystemTab extends StatefulWidget {
  const _SystemTab({required this.fs}); final FirestoreService fs;
  @override State<_SystemTab> createState() => _SystemTabState();
}
class _SystemTabState extends State<_SystemTab> {
  final _msgCtrl = TextEditingController(text: 'App temporarily unavailable for maintenance.');
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('System Settings', style: _heading),
    const SizedBox(height: 20),
    StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('maintenance').snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final active = data?['active'] as bool? ?? false;
        return ACard(color: active ? AC.redBg : AC.surface,
          border: Border.all(color: active ? AC.red : AC.border, width: active ? 1.5 : 1),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: active ? AC.red : AC.greenBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(active ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(active ? '🔴 MAINTENANCE MODE ACTIVE' : '🟢 App is running',
                  style: TextStyle(color: active ? AC.red : AC.green, fontSize: 14, fontWeight: FontWeight.w800)),
                const Text('Controls whether users can access the app', style: TextStyle(color: AC.muted, fontSize: 12))]))]),
            const SizedBox(height: 16),
            TextField(controller: _msgCtrl, maxLines: 2, style: const TextStyle(color: AC.text), decoration: const InputDecoration(labelText: 'Message shown to users')),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: active ? AC.green : AC.red, minimumSize: const Size(0,44)),
              onPressed: () => _toggle(context, !active),
              icon: Icon(active ? Icons.play_arrow_rounded : Icons.pause_rounded),
              label: Text(active ? 'Disable Maintenance' : 'Enable Maintenance')))]));
      }),
    const SizedBox(height: 20),
    ACard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Admin Session', style: TextStyle(color: AC.text, fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Text(FirebaseAuth.instance.currentUser?.email ?? '—', style: const TextStyle(color: AC.muted, fontSize: 13)),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: () => AuthService().signOut(),
        icon: const Icon(Icons.logout_rounded, size: 16), label: const Text('Sign Out')))])),
    const SizedBox(height: 20),
    _DeletionRequestsCard(fs: widget.fs),
  ]);

  Future<void> _toggle(BuildContext context, bool activate) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(activate ? '⚠️ Enable Maintenance?' : '✅ Disable Maintenance?'),
      content: Text(activate ? 'All users will see the maintenance screen.' : 'App will become accessible again.', style: const TextStyle(color: AC.muted)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(activate ? 'Enable' : 'Disable', style: TextStyle(color: activate ? AC.red : AC.green)))]));
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('settings').doc('maintenance').set({
      'active': activate, 'message': _msgCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': FirebaseAuth.instance.currentUser?.uid});
  }
}

// ================================================================
// SHARED HELPERS
// ================================================================
class _MaintenanceBanner extends StatelessWidget {
  const _MaintenanceBanner();
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('settings').doc('maintenance').snapshots(),
    builder: (context, snap) {
      final active = (snap.data?.data() as Map?)?['active'] as bool? ?? false;
      if (!active) return const SizedBox.shrink();
      return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AC.redBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.red.withOpacity(0.5))),
        child: Row(children: [
          const Icon(Icons.warning_rounded, color: AC.red, size: 18), const SizedBox(width: 10),
          const Expanded(child: Text('🔴 MAINTENANCE MODE — users cannot access the app', style: TextStyle(color: AC.red, fontSize: 12.5, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => FirebaseFirestore.instance.collection('settings').doc('maintenance').update({'active': false}), child: const Text('Disable', style: TextStyle(color: AC.red)))]));
    });
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});
  final IconData icon; final Color color; final String tooltip; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(icon: Icon(icon, color: color, size: 18),
    tooltip: tooltip, onPressed: onTap, style: IconButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.all(8)));
}

// ================================================================
// DELETION REQUESTS CARD
// ================================================================
// ================================================================
// DELETION REQUESTS CARD — استبدل class _DeletionRequestsCard
// ================================================================

// ================================================================
// DELETION REQUESTS CARD — يستعمل Firestore status بدل local Set
// ================================================================
class _DeletionRequestsCard extends StatelessWidget {
  const _DeletionRequestsCard({required this.fs});
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.streamPendingDeletionRequests(),
      builder: (context, snap) {
        final requests = snap.data ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();
        return ACard(
          color: AC.redBg,
          border: Border.all(color: AC.red.withOpacity(0.4)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.delete_forever_rounded, color: AC.red, size: 18),
              const SizedBox(width: 8),
              Text('Demandes de suppression (${requests.length})',
                  style: const TextStyle(color: AC.red, fontSize: 14, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 14),
            ...requests.map((req) => _DeletionRequestTile(req: req, fs: fs)),
          ]));
      });
  }
}

class _DeletionRequestTile extends StatefulWidget {
  const _DeletionRequestTile({required this.req, required this.fs});
  final Map<String, dynamic> req;
  final FirestoreService fs;
  @override
  State<_DeletionRequestTile> createState() => _DeletionRequestTileState();
}

class _DeletionRequestTileState extends State<_DeletionRequestTile> {
  bool _processing = false; // ← local per-tile loading state فقط

  @override
  Widget build(BuildContext context) {
    final uid = widget.req['uid'] as String;
    final userType = widget.req['userType'] as String? ?? 'client';
    final reason = widget.req['reason'] as String? ?? '—';
    final ts = widget.req['requestedAt'];
    final date = ts is Timestamp ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate()) : '—';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection(userType == 'technician' ? 'technicians' : 'users')
          .doc(uid)
          .get(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final name = (userData['fullName'] as String? ?? '').isEmpty
            ? '(sans nom)' : userData['fullName'] as String;
        final phone = userData['phone'] as String? ?? '—';
        final city = userData['city'] as String? ?? '—';
        final rating = (userData['rating'] as num?)?.toStringAsFixed(1) ?? '—';
        final jobsDone = userData['jobsDone'] as int?;
        final wallet = (userData['walletBalance'] as num?)?.toStringAsFixed(0);
        final photoUrl = userData['profilePhotoUrl'] as String? ?? userData['photoUrl'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AC.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AC.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(14), child: Row(children: [
              AAvatar(url: photoUrl, name: name, radius: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  ABadge(
                    label: userType == 'technician' ? '🔧 Technicien' : '👤 Client',
                    color: AC.blue, bg: AC.blueBg),
                  const SizedBox(width: 8),
                  Flexible(child: Text(name,
                    style: const TextStyle(color: AC.text, fontSize: 14, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis))]),
                const SizedBox(height: 4),
                Text(phone, style: const TextStyle(color: AC.muted, fontSize: 12))])),
            ])),
            const Divider(height: 1, color: AC.border),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Wrap(spacing: 12, runSpacing: 8, children: [
                _detail(Icons.location_city_rounded, city),
                _detail(Icons.star_rounded, '$rating ★'),
                if (jobsDone != null) _detail(Icons.check_circle_rounded, '$jobsDone travaux'),
                if (wallet != null) _detail(Icons.account_balance_wallet_rounded, '$wallet MAD'),
                _detail(Icons.badge_rounded, '${uid.substring(0, 10)}…'),
                _detail(Icons.calendar_today_rounded, date),
              ])),
            Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: AC.gold, size: 14),
                const SizedBox(width: 6),
                Flexible(child: Text('Raison: $reason',
                  style: const TextStyle(color: AC.gold, fontSize: 12.5, fontWeight: FontWeight.w600)))])),
            const Divider(height: 1, color: AC.border),
            Padding(padding: const EdgeInsets.all(12), child: Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AC.muted,
                  side: const BorderSide(color: AC.border),
                  minimumSize: const Size(0, 38)),
                onPressed: _processing ? null : () => _reject(context, uid),
                child: const Text('Rejeter'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AC.red,
                  minimumSize: const Size(0, 38)),
                onPressed: _processing ? null : () => _confirm(context, uid, name),
                child: _processing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirmer suppression'))),
            ])),
          ]));
      });
  }

  Widget _detail(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: AC.muted),
    const SizedBox(width: 4),
    Text(text, style: const TextStyle(color: AC.muted, fontSize: 12))]);

  Future<void> _reject(BuildContext context, String uid) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Rejeter la demande ?'),
      content: const Text('La demande sera annulée et le compte conservé.', style: TextStyle(color: AC.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rejeter', style: TextStyle(color: AC.gold)))]));
    if (ok != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await widget.fs.cancelDeletionRequest(uid);
      // الـ stream كيحذفه تلقائياً من الـ list
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _confirm(BuildContext context, String uid, String name) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Confirmer la suppression ?'),
      content: Text('Le compte de "$name" sera supprimé définitivement. Cette action est irréversible.',
        style: const TextStyle(color: AC.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Supprimer', style: TextStyle(color: AC.red)))]));
    if (ok != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await widget.fs.adminConfirmDeletion(uid);
      // adminConfirmDeletion كيحذف deletion_request من Firestore
      // فالـ stream كيحذفه تلقائياً — ما محتاجناش local Set
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Compte de "$name" supprimé ✓')));
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }
}

Future<void> showBanDialog(BuildContext context, {required String uid, required String collection, required String name, required FirestoreService fs}) async {
  final ctrl = TextEditingController(); int duration = 7;
  final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
    title: Text('Ban $name'),
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: ctrl, autofocus: true, maxLines: 2, style: const TextStyle(color: AC.text), decoration: const InputDecoration(labelText: 'Reason *')),
      const SizedBox(height: 14),
      const Text('Duration', style: TextStyle(color: AC.muted, fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: [for (final d in [1,3,7,30,90,0])
        GestureDetector(onTap: () => set(() => duration = d), child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: duration==d ? AC.redBg : AC.surface2, borderRadius: BorderRadius.circular(99), border: Border.all(color: duration==d ? AC.red : AC.border)),
          child: Text(d==0 ? 'Permanent' : '${d}d', style: TextStyle(color: duration==d ? AC.red : AC.muted, fontSize: 12, fontWeight: FontWeight.w600))))])]),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
      TextButton(onPressed: () { if (ctrl.text.trim().isEmpty) return; Navigator.pop(ctx, true); }, child: const Text('Ban', style: TextStyle(color: AC.red)))])));
  if (ok != true) return;
  final bannedUntil = duration == 0 ? null : Timestamp.fromDate(DateTime.now().add(Duration(days: duration)));
  await FirebaseFirestore.instance.collection(collection).doc(uid).update({
    'isBanned': true, 'isSuspended': true, 'banReason': ctrl.text.trim(),
    'bannedAt': FieldValue.serverTimestamp(), 'bannedUntil': bannedUntil,
    'banDurationDays': duration, 'bannedBy': FirebaseAuth.instance.currentUser?.uid,
    if (collection == 'technicians') 'isOnline': false});
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name banned (${duration==0 ? 'permanent' : '${duration}d'}) ✓')));
}

Future<void> unbanAccount(BuildContext context, {required String uid, required String collection, required String name}) async {
  await FirebaseFirestore.instance.collection(collection).doc(uid).update({
    'isBanned': false, 'isSuspended': false,
    'banReason': FieldValue.delete(), 'bannedAt': FieldValue.delete(),
    'bannedUntil': FieldValue.delete(), 'banDurationDays': FieldValue.delete(),
    'unbannedAt': FieldValue.serverTimestamp()});
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name unbanned ✓')));
}