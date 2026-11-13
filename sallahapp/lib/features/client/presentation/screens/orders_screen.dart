import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as ul;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/invoice_service.dart';
import '../../../../core/widgets/qr_scanner_screen.dart';
import '../../../../models/catalog.dart';
import '../bloc/language_cubit.dart';
import 'chat_screen.dart';
import 'technician_public_profile.dart';
import 'viral_widgets.dart';
import 'my_project_requests_screen.dart' show ProjectRequestsList;

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  String _filter = 'all';
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _matchesFilter(String status) {
    switch (_filter) {
      case 'active':
        return FirestoreService.activeStatuses.contains(status);
      case 'completed':
        return status == 'completed';
      case 'cancelled':
        return status == 'cancelled';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    final fs = FirestoreService();
    final t = context.watch<LanguageCubit>().state.t;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Bar
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 28 : 20,
                    16,
                    isDesktop ? 28 : 20,
                    10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t('orders_title'),
                        style: TextStyle(
                          fontSize: isDesktop ? 26 : 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF14241F),
                          letterSpacing: -0.4,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F5A47).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded, size: 14, color: Color(0xFF0F5A47)),
                            SizedBox(width: 4),
                            Text(
                              'BRIKOOL DIRECT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F5A47),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Modern Pill TabBar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 20),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      labelColor: const Color(0xFF0F5A47),
                      unselectedLabelColor: Colors.grey.shade600,
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      tabs: [
                        Tab(text: t('orders_tab_services')),
                        Tab(text: t('orders_tab_projects')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _servicesTab(user, fs, t, isDesktop),
                      const ProjectRequestsList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _servicesTab(
      User user, FirestoreService fs, String Function(String) t, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 20),
          child: Row(
            children: [
              _FilterChip(
                label: t('orders_filter_all'),
                value: 'all',
                current: _filter,
                onTap: (v) => setState(() => _filter = v),
              ),
              _FilterChip(
                label: t('orders_filter_active'),
                value: 'active',
                current: _filter,
                onTap: (v) => setState(() => _filter = v),
              ),
              _FilterChip(
                label: t('orders_filter_completed'),
                value: 'completed',
                current: _filter,
                onTap: (v) => setState(() => _filter = v),
              ),
              _FilterChip(
                label: t('orders_filter_cancelled'),
                value: 'cancelled',
                current: _filter,
                onTap: (v) => setState(() => _filter = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Orders List
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: fs.streamClientRequests(user.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorState(message: snapshot.error.toString(), t: t);
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF0F5A47),
                  ),
                );
              }
              final orders = snapshot.data!
                  .where((o) => _matchesFilter(o['status'] as String? ?? ''))
                  .toList();
              if (orders.isEmpty) return _EmptyState(t: t);

              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 28 : 20,
                  6,
                  isDesktop ? 28 : 20,
                  32,
                ),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _OrderCard(
                  order: orders[i],
                  t: t,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(
                        requestId: orders[i]['requestId'] as String,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0F5A47) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF0F5A47)
                  : Colors.grey.withOpacity(0.18),
              width: 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F5A47).withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.t});
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF0F5A47).withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 36,
                color: Color(0xFF0F5A47),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('orders_empty'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E2D27),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t('orders_empty_sub'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.t});
  final String message;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              t('orders_load_error'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _serviceIconFor(String serviceType, String Function(String) t) {
  final id = serviceType.replaceFirst('sos_', '');
  for (final offers in [sosOffers(t), ...categoryCatalog(t).values]) {
    for (final o in offers) {
      if (o.skillId == id) return o.icon;
    }
  }
  return Icons.build_rounded;
}

String _formatDate(dynamic timestamp) {
  if (timestamp is! Timestamp) return '';
  return DateFormat('dd/MM · HH:mm').format(timestamp.toDate());
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.t});
  final String status;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String label;
    switch (status) {
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = t('status_pending');
      case 'accepted':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = t('status_accepted');
      case 'en_route':
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF4338CA);
        label = t('status_en_route');
      case 'in_progress':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = t('status_in_progress');
      case 'completed':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        label = t('status_completed');
      case 'cancelled':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = t('status_cancelled');
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap, required this.t});
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  final String Function(String) t;

  Future<void> _confirmCancel(BuildContext context) async {
    final requestId = order['requestId'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Text(t('order_cancel_confirm_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            content: Text(t('order_cancel_confirm_body'),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('order_cancel_no')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('order_cancel_yes'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await FirestoreService().cancelRequest(requestId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('order_cancelled_snack'))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t('order_cancel_refused')}${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceType = order['serviceType'] as String? ?? '';
    final label = order['serviceLabel'] as String? ?? t('chat_default_service');
    final budget = (order['budgetMAD'] as num?)?.toDouble() ??
        (order['priceQuoteMAD'] as num?)?.toDouble() ??
        0;
    final status = order['status'] as String? ?? '';
    final date = _formatDate(order['createdAt']);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.04),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
          ),
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F5A47).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_serviceIconFor(serviceType, t), color: const Color(0xFF0F5A47), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StatusBadge(status: status, t: t),
                        if (date.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            date,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${budget.toStringAsFixed(0)} MAD',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Color(0xFF0F5A47),
                    ),
                  ),
                  if (FirestoreService.activeStatuses.contains(status)) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _confirmCancel(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          t('order_cancel'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ORDER DETAIL SCREEN (Responsive, Card-Structured)
// ================================================================
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final t = context.watch<LanguageCubit>().state.t;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        title: Text(
          t('order_detail_title'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: fs.streamRequest(requestId),
              builder: (context, snapshot) {
                if (snapshot.hasError) return _ErrorState(message: snapshot.error.toString(), t: t);
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!.exists) return _ErrorState(message: 'Commande introuvable.', t: t);

                final data = snapshot.data!.data()!;
                final status = data['status'] as String? ?? '';
                final budget = (data['budgetMAD'] as num?)?.toDouble() ?? 0;
                final price = (data['priceQuoteMAD'] as num?)?.toDouble() ?? budget;
                final otp = data['otpCode'] as String? ?? '----';
                final techId = data['techId'] as String?;
                final serviceType = data['serviceType'] as String? ?? '';
                final serviceLabel = data['serviceLabel'] as String? ?? t('chat_default_service');
                final clientRating = (data['clientRating'] as num?)?.toInt();
                final isActive = FirestoreService.activeStatuses.contains(status);
                final isPending = status == 'pending';

                try {
                  return _buildDetail(
                    context, fs, t, data, status, budget, price, otp, techId,
                    serviceType, serviceLabel, clientRating, isActive, isPending, isDesktop,
                  );
                } catch (e, st) {
                  return _ErrorState(message: 'Erreur: $e\n$st', t: t);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context, FirestoreService fs, String Function(String) t,
    Map<String, dynamic> data, String status, double budget, double price,
    String otp, String? techId, String serviceType, String serviceLabel,
    int? clientRating, bool isActive, bool isPending, bool isDesktop,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 20, vertical: 16),
      children: [
        // ── Service Summary Card ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F5A47).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_serviceIconFor(serviceType, t), color: const Color(0xFF0F5A47), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(serviceLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    _StatusBadge(status: status, t: t),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${price.toStringAsFixed(0)} MAD',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F5A47)),
                  ),
                  Text(
                    isPending ? t('order_budget_label') : t('order_price_label'),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Media Strip ──
        if ((data['mediaUrls'] as List?)?.isNotEmpty ?? false) ...[
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: ((data['mediaUrls'] as List).cast<String>())
                  .map((url) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              child: InteractiveViewer(child: Image.network(url)),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              url,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(width: 80),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Offers & Raise Budget (Pending State) ──
        if (isPending) ...[
          SafeSection(builder: () => _OffersSection(requestId: requestId, budget: budget, fs: fs, t: t)),
          const SizedBox(height: 12),
          SafeSection(builder: () => _RaiseBudgetCard(requestId: requestId, budget: budget, fs: fs, t: t)),
          const SizedBox(height: 12),
        ],

        // ── Status Timeline ──
        if (status != 'cancelled' && !isPending) ...[
          _StatusTimeline(current: status, t: t),
          const SizedBox(height: 12),
        ],

        // ── Technician Card ──
        if (techId != null) ...[
          SafeSection(
            builder: () => _TechnicianCard(
              techId: techId,
              fs: fs,
              requestId: requestId,
              serviceLabel: serviceLabel,
              chatEnabled: isActive,
              t: t,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Verification OTP ──
        if (isActive && !isPending) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.withOpacity(0.12)),
            ),
            child: Column(
              children: [
                Text(t('otp_title'), style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  otp,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: Color(0xFF0F5A47),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(data: buildOtpQrData(requestId, otp), size: 140, backgroundColor: Colors.transparent),
                ),
                const SizedBox(height: 12),
                Text(t('otp_scan'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(t('otp_warning'), style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Repair Journal ──
        if ((data['journal'] as List?)?.isNotEmpty ?? false) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('journal_title'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: ((data['journal'] as List).cast<Map<String, dynamic>>())
                        .map((entry) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onTap: () => showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        child: InteractiveViewer(child: Image.network(entry['url'] as String)),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(
                                        entry['url'] as String,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder: (a, b, c) => const SizedBox(width: 72),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry['label'] as String? ?? '',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Sharing, Emergency & Help Options ──
        if (isActive && !isPending && techId != null) ...[
          _ShareTrackingButton(techId: techId, serviceLabel: serviceLabel, status: status, fs: fs, t: t),
          const SizedBox(height: 12),
        ],

        if (isActive) ...[
          EmergencyButton(requestId: requestId, techId: techId ?? '', fs: fs, t: t),
          const SizedBox(height: 10),
          CallSupportButton(t: t),
          const SizedBox(height: 12),
        ],

        // ── Post-Order Rating & Invoicing ──
        if (status == 'completed' && techId != null) ...[
          _RatingCard(requestId: requestId, techId: techId, existingRating: clientRating, fs: fs, t: t),
          const SizedBox(height: 12),
          _InvoiceButton(requestId: requestId, orderData: data, t: t),
          const SizedBox(height: 10),
          _ShareCardButton(techId: techId, serviceLabel: serviceLabel, priceMad: price, fs: fs),
          const SizedBox(height: 10),
          _ReportButton(requestId: requestId, techId: techId, fs: fs, t: t),
          const SizedBox(height: 12),
        ],

        // ── Cancel Button ──
        if (isActive)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  title: Text(t('order_cancel_confirm_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  content: Text(t('order_cancel_confirm_body'), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('order_cancel_no'))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(t('order_cancel_yes'), style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await fs.cancelRequest(requestId);
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: Text(t('order_cancel'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }
}

// ================================================================
// OFFERS SECTION
// ================================================================
class _OffersSection extends StatelessWidget {
  const _OffersSection({required this.requestId, required this.budget, required this.fs, required this.t});
  final String requestId;
  final double budget;
  final FirestoreService fs;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.streamOffers(requestId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(14)),
            child: Text('${snapshot.error}', style: const TextStyle(fontSize: 11.5, color: AppColors.dangerDark)),
          );
        }
        final offers = (snapshot.data ?? []).where((o) => o['status'] == 'proposed').toList();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t('offers_title'),
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (offers.isEmpty)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F5A47)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                offers.isEmpty ? t('offers_waiting') : t('offers_hint'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              ...offers.map((offer) => SafeSection(builder: () {
                    final offerPrice = (offer['priceMAD'] as num?)?.toDouble() ?? 0;
                    final transportFee = (offer['transportFeeMAD'] as num?)?.toDouble() ?? 0;
                    final total = offerPrice + transportFee;
                    final diff = offerPrice - budget;
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => showTechnicianPublicProfile(context, offer['techId'] as String, allowDirectOrder: false),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF0F5A47).withOpacity(0.1),
                              child: Text(
                                (offer['techName'] as String? ?? '?').isNotEmpty
                                    ? (offer['techName'] as String)[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Color(0xFF0F5A47), fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  offer['techName'] as String? ?? t('chat_default_technician'),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                                Text(
                                  '${((offer['techRating'] as num?)?.toDouble() ?? 5.0).toStringAsFixed(1)} ★'
                                  '${diff == 0 ? ' · ${t('offer_accepts_budget')}' : diff > 0 ? ' · +${diff.toStringAsFixed(0)} MAD' : ' · ${diff.toStringAsFixed(0)} MAD'}',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                ),
                                if (transportFee > 0)
                                  Text(
                                    '+ ${transportFee.toStringAsFixed(0)} MAD transport',
                                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${total.toStringAsFixed(0)} MAD',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F5A47)),
                              ),
                              if (transportFee > 0)
                                Text(t('offer_total'), style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: const Color(0xFF0F5A47)),
                            onPressed: () async {
                              try {
                                await fs.acceptOffer(
                                  requestId: requestId,
                                  offerId: offer['offerId'] as String,
                                  techId: offer['techId'] as String,
                                  priceMad: offerPrice,
                                  transportFeeMad: transportFee,
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                          ),
                          IconButton(
                            onPressed: () => fs.rejectOffer(requestId, offer['offerId'] as String),
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  })),
            ],
          ),
        );
      },
    );
  }
}

// ================================================================
// RAISE BUDGET CARD
// ================================================================
class _RaiseBudgetCard extends StatelessWidget {
  const _RaiseBudgetCard({required this.requestId, required this.budget, required this.fs, required this.t});
  final String requestId;
  final double budget;
  final FirestoreService fs;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('raise_budget_title'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(t('raise_budget_sub'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Row(
            children: [10, 20, 50].map((bump) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F5A47),
                      side: BorderSide(color: const Color(0xFF0F5A47).withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(0, 42),
                    ),
                    onPressed: () async {
                      await fs.increaseRequestPrice(requestId, budget + bump);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              t('raise_budget_snack').replaceAll('{amount}', (budget + bump).toStringAsFixed(0)),
                            ),
                          ),
                        );
                      }
                    },
                    child: Text('+$bump MAD', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// STATUS TIMELINE
// ================================================================
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.current, required this.t});
  final String current;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('accepted', t('timeline_accepted'), Icons.check_rounded),
      ('en_route', t('timeline_en_route'), Icons.directions_car_rounded),
      ('in_progress', t('timeline_in_progress'), Icons.build_rounded),
      ('completed', t('timeline_completed'), Icons.flag_rounded),
    ];
    final currentIndex = steps.indexWhere((s) => s.$1 == current);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = i ~/ 2 < currentIndex;
            return Expanded(
              child: Container(
                height: 2.5,
                color: done ? const Color(0xFF0F5A47) : Colors.grey.shade200,
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final (_, label, icon) = steps[stepIndex];
          final reached = stepIndex <= currentIndex;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: reached ? const Color(0xFF0F5A47) : const Color(0xFFF7FAFA),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: reached ? const Color(0xFF0F5A47) : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, size: 17, color: reached ? Colors.white : Colors.grey.shade400),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: reached ? FontWeight.w800 : FontWeight.w500,
                  color: reached ? const Color(0xFF14241F) : Colors.grey.shade500,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ================================================================
// TECHNICIAN CARD
// ================================================================
class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({
    required this.techId,
    required this.fs,
    required this.requestId,
    required this.serviceLabel,
    required this.chatEnabled,
    required this.t,
  });
  final String techId;
  final FirestoreService fs;
  final String requestId;
  final String serviceLabel;
  final bool chatEnabled;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fs.streamTechnician(techId),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['fullName'] as String? ?? t('chat_default_technician');
        final rating = (data?['rating'] as num?)?.toDouble() ?? 5.0;
        final phone = data?['phone'] as String?;
        final photoUrl = data?['profilePhotoUrl'] as String?;

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => showTechnicianPublicProfile(context, techId, allowDirectOrder: false),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF0F5A47).withOpacity(0.08),
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Color(0xFF0F5A47), fontWeight: FontWeight.w800),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(
                      '⭐ ${rating.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (chatEnabled)
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF0F5A47)),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(requestId: requestId, title: name, techId: techId),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 17, color: Colors.white),
                ),
              const SizedBox(width: 6),
              _FavoriteHeart(techId: techId, fs: fs, t: t),
              if (phone != null && phone.isNotEmpty) ...[
                const SizedBox(width: 6),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: () => ul.launchUrl(Uri.parse('tel:$phone')),
                  icon: const Icon(Icons.call_rounded, size: 17, color: Colors.white),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ================================================================
// RATING CARD
// ================================================================
class _RatingCard extends StatefulWidget {
  const _RatingCard({
    required this.requestId,
    required this.techId,
    required this.existingRating,
    required this.fs,
    required this.t,
  });
  final String requestId;
  final String techId;
  final int? existingRating;
  final FirestoreService fs;
  final String Function(String) t;

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  int? _selected;
  bool _saving = false;
  final _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final rating = widget.existingRating ?? _selected;
    final alreadyRated = widget.existingRating != null;
    final t = widget.t;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Text(
            alreadyRated ? t('rating_done') : t('rating_title'),
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starValue = i + 1;
              final filled = rating != null && starValue <= rating;
              return IconButton(
                onPressed: alreadyRated || _saving ? null : () => setState(() => _selected = starValue),
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 34,
                  color: filled ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                ),
              );
            }),
          ),
          if (!alreadyRated && _selected != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: t('rating_comment_hint'),
                filled: true,
                fillColor: const Color(0xFFF7FAFA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F5A47),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await widget.fs.rateCompletedRequest(
                          requestId: widget.requestId,
                          techId: widget.techId,
                          stars: _selected!,
                          comment: _commentController.text.trim(),
                        );
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (mounted && uid != null) await showRewardWheel(context, uid);
                      } catch (_) {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(t('rating_submit'), style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }
}

// ================================================================
// SAFE SECTION
// ================================================================
class SafeSection extends StatelessWidget {
  const SafeSection({super.key, required this.builder});
  final Widget Function() builder;
  @override
  Widget build(BuildContext context) {
    try {
      return builder();
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(14)),
        child: Text('Section en erreur: $e', style: const TextStyle(fontSize: 11.5, color: AppColors.dangerDark)),
      );
    }
  }
}

// ================================================================
// FAVORITE HEART
// ================================================================
class _FavoriteHeart extends StatelessWidget {
  const _FavoriteHeart({required this.techId, required this.fs, required this.t});
  final String techId;
  final FirestoreService fs;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<Map<String, dynamic>?>(
      stream: fs.streamUserProfile(uid),
      builder: (context, snapshot) {
        final favorites = (snapshot.data?['favoriteTechIds'] as List?)?.cast<String>() ?? [];
        final isFavorite = favorites.contains(techId);
        return IconButton(
          onPressed: () async {
            try {
              await fs.toggleFavoriteTech(uid, techId, !isFavorite);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    duration: const Duration(seconds: 2),
                    content: Text(isFavorite ? t('favorite_remove') : t('favorite_add'))));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t('failed')}$e')));
              }
            }
          },
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
            size: 20,
            color: isFavorite ? const Color(0xFFEF4444) : Colors.grey.shade400,
          ),
        );
      },
    );
  }
}

// ================================================================
// SHARE TRACKING
// ================================================================
class _ShareTrackingButton extends StatelessWidget {
  const _ShareTrackingButton({
    required this.techId,
    required this.serviceLabel,
    required this.status,
    required this.fs,
    required this.t,
  });
  final String techId;
  final String serviceLabel;
  final String status;
  final FirestoreService fs;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fs.streamTechnician(techId),
      builder: (context, snapshot) {
        final name = snapshot.data?.data()?['fullName'] as String? ?? t('chat_default_technician');
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F5A47),
            side: const BorderSide(color: Color(0xFF0F5A47)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: () => shareTracking(context, techName: name, serviceLabel: serviceLabel, status: status),
          icon: const Icon(Icons.share_location_rounded, size: 18),
          label: Text(t('share_tracking'), style: const TextStyle(fontWeight: FontWeight.w800)),
        );
      },
    );
  }
}

// ================================================================
// SHARE CARD BUTTON
// ================================================================
class _ShareCardButton extends StatelessWidget {
  const _ShareCardButton({
    required this.techId,
    required this.serviceLabel,
    required this.priceMad,
    required this.fs,
  });
  final String techId;
  final String serviceLabel;
  final double priceMad;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fs.streamTechnician(techId),
      builder: (context, snapshot) {
        final tech = snapshot.data?.data();
        final name = tech?['fullName'] as String? ?? t('chat_default_technician');
        final rating = (tech?['rating'] as num?)?.toDouble() ?? 5.0;
        final city = tech?['city'] as String? ?? '';
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: () => showShareCardDialog(
            context,
            serviceLabel: serviceLabel,
            techName: name,
            priceMad: priceMad,
            rating: rating,
            city: city,
          ),
          icon: const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white),
          label: Text(t('share_repair'), style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        );
      },
    );
  }
}

// ================================================================
// REPORT BUTTON
// ================================================================
class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.requestId, required this.techId, required this.fs, required this.t});
  final String requestId;
  final String techId;
  final FirestoreService fs;
  final String Function(String) t;

  Future<void> _openDialog(BuildContext context) async {
    final reasons = [t('report_reason_1'), t('report_reason_2'), t('report_reason_3'), t('report_reason_4'), t('report_reason_5')];
    var selectedReason = reasons.first;
    final commentController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: StatefulBuilder(
            builder: (ctx, setSheet) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: Text(t('report_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('report_body'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  ...reasons.map((reason) => RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: const Color(0xFF0F5A47),
                        value: reason,
                        groupValue: selectedReason,
                        title: Text(reason, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        onChanged: (v) => setSheet(() => selectedReason = v!),
                      )),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: t('report_hint'),
                      filled: true,
                      fillColor: const Color(0xFFF7FAFA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(t('report_send'), style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (submitted != true) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await fs.submitReport(
        requestId: requestId,
        clientId: uid,
        techId: techId,
        reason: selectedReason,
        comment: commentController.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('report_sent_snack'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t('failed')}$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: fs.streamHasReport(requestId, uid),
      builder: (context, snapshot) {
        final alreadyReported = snapshot.data ?? false;
        return SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: alreadyReported ? null : () => _openDialog(context),
            style: TextButton.styleFrom(
              foregroundColor: alreadyReported ? Colors.grey : AppColors.danger,
            ),
            icon: Icon(alreadyReported ? Icons.check_circle_outline_rounded : Icons.flag_outlined, size: 16),
            label: Text(alreadyReported ? t('report_sent') : t('report_title'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }
}

// ================================================================
// EMERGENCY BUTTON
// ================================================================
class EmergencyButton extends StatelessWidget {
  const EmergencyButton({super.key, required this.requestId, required this.techId, required this.fs, required this.t});
  final String requestId;
  final String techId;
  final FirestoreService fs;
  final String Function(String) t;

  Future<void> _confirmAndSend(BuildContext context) async {
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(t('emergency_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('emergency_body'), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: t('emergency_hint'),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('emergency_send'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await fs.submitReport(
        requestId: requestId,
        clientId: uid,
        techId: techId,
        reason: 'Urgence en cours',
        comment: commentController.text.trim(),
        urgent: true,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(t('emergency_snack')),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t('failed')}$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: fs.streamHasReport(requestId, uid, urgentOnly: true),
      builder: (context, snapshot) {
        final alreadySent = snapshot.data ?? false;
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: alreadySent ? Colors.grey.shade400 : AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              minimumSize: const Size(0, 50),
              elevation: alreadySent ? 0 : 2,
            ),
            onPressed: alreadySent ? null : () => _confirmAndSend(context),
            icon: Icon(alreadySent ? Icons.check_circle_rounded : Icons.warning_amber_rounded, size: 20, color: Colors.white),
            label: Text(
              alreadySent ? t('emergency_sent') : t('emergency_button'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// INVOICE BUTTON
// ================================================================
class _InvoiceButton extends StatefulWidget {
  const _InvoiceButton({required this.requestId, required this.orderData, required this.t});
  final String requestId;
  final Map<String, dynamic> orderData;
  final String Function(String) t;
  @override
  State<_InvoiceButton> createState() => _InvoiceButtonState();
}

class _InvoiceButtonState extends State<_InvoiceButton> {
  bool _loading = false;

  Future<void> _tap() async {
    setState(() => _loading = true);
    try {
      String? url = widget.orderData['invoiceUrl'] as String?;
      if (url == null) {
        url = await InvoiceService.generateAndUpload(
          requestId: widget.requestId,
          orderData: widget.orderData,
        );
      }
      if (url.isNotEmpty) {
        await ul.launchUrl(Uri.parse(url), mode: ul.LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.t('error')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasInvoice = widget.orderData['invoiceUrl'] != null;
    final t = widget.t;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _tap,
        icon: _loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F5A47)))
            : const Icon(Icons.picture_as_pdf_rounded, size: 18),
        label: Text(
          _loading ? t('invoice_generating') : hasInvoice ? t('invoice_download') : t('invoice_generate'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0F5A47),
          side: const BorderSide(color: Color(0xFF0F5A47)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }
}

// ================================================================
// CALL SUPPORT
// ================================================================
class CallSupportButton extends StatelessWidget {
  const CallSupportButton({super.key, required this.t});
  final String Function(String) t;
  static const supportPhoneNumber = '+212600000000';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: const Color(0xFF0F5A47),
          side: BorderSide(color: Colors.grey.withOpacity(0.25)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () async {
          try {
            await ul.launchUrl(Uri(scheme: 'tel', path: supportPhoneNumber));
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${t('support_call_error')}$e')),
              );
            }
          }
        },
        icon: const Icon(Icons.support_agent_rounded, size: 20),
        label: Text(t('support_call'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}