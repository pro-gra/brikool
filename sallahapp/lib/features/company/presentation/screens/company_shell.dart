import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../models/company_profile.dart';
import '../../../../models/big_service_category.dart';
import '../../../../models/moroccan_cities.dart';
import 'company_wallet_deposit_screen.dart';
import 'company_chat_screen.dart';
import 'company_planning_screen.dart';

int _quoteDurationInDays(double value, String unit) {
  if (value <= 0) return 1;
  switch (unit) {
    case 'heures':
      return value > 24 ? (value / 24).ceil() : 1;
    case 'semaines':
      return (value * 7).ceil();
    default:
      return value.ceil();
  }
}

class CompanyShell extends StatefulWidget {
  const CompanyShell({super.key, required this.profile});
  final CompanyProfile profile;
  @override
  State<CompanyShell> createState() => _CompanyShellState();
}

class _CompanyShellState extends State<CompanyShell> {
  int _index = 0;
  final _fs = FirestoreService();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            _LeadsTab(companyId: widget.profile.companyId, fs: _fs),
            CompanyPlanningScreen(companyId: widget.profile.companyId, fs: _fs),
            _CompanyStatsTab(profile: widget.profile, fs: _fs),
            _CompanyProfileTab(profile: widget.profile, fs: _fs),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: AppColors.surface,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inbox_rounded), label: 'Demandes'),
          NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Planning'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Statistiques'),
          NavigationDestination(icon: Icon(Icons.storefront_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}

// =================================================================
// STATISTICS
// =================================================================
class _CompanyStatsTab extends StatelessWidget {
  const _CompanyStatsTab({required this.profile, required this.fs});
  final CompanyProfile profile;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CompanyProfile?>(
      stream: fs.streamCompany(profile.companyId),
      builder: (context, profileSnap) {
        final live = profileSnap.data ?? profile;
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: fs.streamQuoteRequestsForCompany(profile.companyId),
          builder: (context, snapshot) {
            final requests = snapshot.data ?? const [];
            final total = requests.length;
            final quoted = requests.where((r) => r['status'] != 'new').length;
            final accepted = requests
                .where((r) => ['confirmed', 'in_progress', 'completed'].contains(r['status']))
                .length;
            final inProgress = requests.where((r) => r['status'] == 'in_progress').length;
            final completed = requests.where((r) => r['status'] == 'completed').length;
            final declined = requests.where((r) => r['status'] == 'declined').length;
            final revenue = requests
                .where((r) => r['status'] == 'completed')
                .fold<double>(0, (sum, r) => sum + ((r['quotedPriceMAD'] as num?)?.toDouble() ?? 0));
            final decisionsCount = accepted + declined;
            final acceptanceRate = decisionsCount > 0 ? (accepted / decisionsCount * 100) : null;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const Text('Statistiques',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: live.walletBalance < 100 ? AppColors.danger : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: live.walletBalance < 100 ? AppColors.dangerLight : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.account_balance_wallet_rounded,
                            color: live.walletBalance < 100 ? AppColors.danger : AppColors.primary,
                            size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${live.walletBalance.toStringAsFixed(2)} MAD',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            Text(
                              live.walletBalance < 100
                                  ? 'Solde bas \u2014 rechargez pour \u00e9viter un blocage'
                                  : 'Portefeuille commission',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: live.walletBalance < 100
                                      ? AppColors.danger
                                      : AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 14)),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                CompanyWalletDepositScreen(currentBalance: live.walletBalance))),
                        child: const Text('Recharger'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Chiffre d'affaires (projets termin\u00e9s)",
                          style: TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text('${revenue.toStringAsFixed(0)} MAD',
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 15, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('${live.rating.toStringAsFixed(1)} note moyenne',
                              style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                          const SizedBox(width: 12),
                          const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(live.isVerified ? 'V\u00e9rifi\u00e9e' : 'En v\u00e9rification',
                              style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _CompanyStatTile(
                        icon: Icons.inbox_rounded,
                        color: AppColors.primary,
                        bg: AppColors.primaryLight,
                        value: '$total',
                        label: 'Demandes re\u00e7ues'),
                    _CompanyStatTile(
                        icon: Icons.description_rounded,
                        color: const Color(0xFF2B4EAE),
                        bg: const Color(0xFFE8EDFB),
                        value: '$quoted',
                        label: 'Devis envoy\u00e9s'),
                    _CompanyStatTile(
                        icon: Icons.construction_rounded,
                        color: AppColors.gold,
                        bg: AppColors.gold.withOpacity(0.14),
                        value: '$inProgress',
                        label: 'Chantiers en cours'),
                    _CompanyStatTile(
                        icon: Icons.task_alt_rounded,
                        color: const Color(0xFF0E7C66),
                        bg: const Color(0xFFE0F5EF),
                        value: '$completed',
                        label: 'Projets termin\u00e9s'),
                  ],
                ),
                const SizedBox(height: 16),
                if (acceptanceRate != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Taux d'acceptation de vos devis",
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                            Text('${acceptanceRate.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: acceptanceRate / 100,
                            minHeight: 8,
                            backgroundColor: AppColors.background,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('$accepted accept\u00e9s sur $decisionsCount devis d\u00e9cid\u00e9s',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tips_and_updates_rounded, size: 17, color: AppColors.gold),
                          SizedBox(width: 8),
                          Text('Pour \u00eatre vu par plus de clients',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (live.portfolioUrls.length < 3)
                        const _TipRow(text: 'Ajoutez au moins 3 photos de r\u00e9alisations \u00e0 votre portfolio'),
                      if (!live.isVerified)
                        const _TipRow(text: 'Une entreprise v\u00e9rifi\u00e9e appara\u00eet en premier dans les r\u00e9sultats'),
                      if (live.description.length < 60)
                        const _TipRow(text: 'Compl\u00e9tez votre pr\u00e9sentation avec plus de d\u00e9tails'),
                      const _TipRow(text: 'R\u00e9pondez vite aux nouvelles demandes \u2014 les clients comparent plusieurs entreprises'),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CompanyStatTile extends StatelessWidget {
  const _CompanyStatTile({
    required this.icon,
    required this.color,
    required this.bg,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final Color bg;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 4, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// LEADS
// =================================================================
class _LeadsTab extends StatelessWidget {
  const _LeadsTab({required this.companyId, required this.fs});
  final String companyId;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.streamQuoteRequestsForCompany(companyId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Erreur: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ),
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final requests = snapshot.data!;
        final newCount = requests.where((r) => (r['status'] ?? 'new') == 'new').length;
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              pinned: true,
              title: Text('Demandes${newCount > 0 ? ' ($newCount nouvelles)' : ''}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            if (requests.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inbox_rounded, size: 40, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        const Text('Aucune demande pour le moment',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text(
                            'Compl\u00e9tez votre profil pour \u00eatre plus visible\ndans les cat\u00e9gories de recherche.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _LeadCard(request: requests[i], fs: fs),
                    childCount: requests.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.request, required this.fs});
  final Map<String, dynamic> request;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    final requestId = request['_id'] as String;
    final status = request['status'] as String? ?? 'new';
    final createdAt = request['createdAt'];
    final date = createdAt is Timestamp
        ? DateFormat('dd/MM/yyyy \u00e0 HH:mm').format(createdAt.toDate())
        : '';
    final clientName = request['clientName'] as String? ?? 'Client';
    final clientPhone = request['clientPhone'] as String? ?? '';
    final address = request['address'] as String? ?? request['city'] as String? ?? '';
    final description = request['description'] as String? ?? '';
    final mediaUrls = (request['mediaUrls'] as List?)?.cast<String>() ?? [];
    final categoryId = request['categoryId'] as String?;
    final category = categoryId != null ? BigServiceCategory.byId(categoryId) : null;
    final preferredDate = request['preferredDate'];
    final preferredTime = request['preferredTime'] as String? ?? '';
    final scheduleLabel = preferredDate is Timestamp
        ? '${DateFormat('dd/MM/yyyy').format(preferredDate.toDate())}${preferredTime.isNotEmpty ? ' \u00e0 $preferredTime' : ''}'
        : '';
    final quotedPrice = (request['quotedPriceMAD'] as num?)?.toDouble();

    final (statusColor, statusBg, statusLabel) = switch (status) {
      'quoted' => (const Color(0xFF2B4EAE), const Color(0xFFE8EDFB), 'Devis envoy\u00e9'),
      'confirmed' => (AppColors.gold, AppColors.gold.withOpacity(0.14), 'Confirm\u00e9 \u2014 \u00e0 d\u00e9marrer'),
      'in_progress' => (const Color(0xFFB3541E), const Color(0xFFFBEADD), 'En cours'),
      'completed' => (AppColors.primary, AppColors.primaryLight, 'Termin\u00e9'),
      'declined' => (AppColors.textMuted, AppColors.background, 'Refus\u00e9'),
      _ => (AppColors.danger, AppColors.dangerLight, 'Nouveau'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: status == 'new' ? AppColors.danger.withOpacity(0.4) : AppColors.border,
            width: status == 'new' ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                child: Text(statusLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
              ),
              const SizedBox(width: 8),
              if (category != null)
                Expanded(
                  child: Text(category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              Text(date, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('R\u00e9f. ${requestId.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.4)),
              const SizedBox(width: 10),
              Expanded(child: _MiniStepper(status: status)),
            ],
          ),
          const SizedBox(height: 10),
          Text(clientName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          if (address.isNotEmpty)
            Text(address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (scheduleLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.event_rounded, size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(scheduleLabel,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: Text(description, style: const TextStyle(fontSize: 12.5, height: 1.4)),
            ),
          ],
          if (mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mediaUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) =>
                        Dialog(child: InteractiveViewer(child: Image.network(mediaUrls[i]))),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(mediaUrls[i],
                        width: 64, height: 64, fit: BoxFit.cover,
                        errorBuilder: (a, b, c) => const SizedBox(width: 64)),
                  ),
                ),
              ),
            ),
          ],
          if (quotedPrice != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFE8EDFB), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.request_quote_rounded, size: 16, color: Color(0xFF2B4EAE)),
                  const SizedBox(width: 8),
                  Text('Devis envoy\u00e9 : ${quotedPrice.toStringAsFixed(0)} MAD',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF2B4EAE))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (clientPhone.isNotEmpty &&
                  ['confirmed', 'in_progress', 'completed'].contains(status))
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: clientPhone)),
                    icon: const Icon(Icons.phone_rounded, size: 15),
                    label: const Text('Appeler', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              if (clientPhone.isNotEmpty &&
                  ['confirmed', 'in_progress', 'completed'].contains(status))
                const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CompanyChatScreen(requestId: requestId, title: clientName))),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                  label: const Text('Chat', style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ],
          ),
          if (!['confirmed', 'in_progress', 'completed'].contains(status)) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textMuted),
                SizedBox(width: 4),
                Text('Num\u00e9ro visible apr\u00e8s acceptation du devis par le client',
                    style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          _ActionForStatus(status: status, requestId: requestId, fs: fs, request: request),
        ],
      ),
    );
  }
}

class _ActionForStatus extends StatelessWidget {
  const _ActionForStatus(
      {required this.status, required this.requestId, required this.fs, required this.request});
  final String status;
  final String requestId;
  final FirestoreService fs;
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final quoteDocumentUrl = request['quoteDocumentUrl'] as String?;
    final showDevisLink = status != 'new' && quoteDocumentUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDevisLink) ...[
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse(quoteDocumentUrl)),
            icon: const Icon(Icons.description_rounded, size: 15),
            label: const Text('Voir le devis (PDF)', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 4),
        ],
        _statusAction(context),
      ],
    );
  }

  Widget _statusAction(BuildContext context) {
    switch (status) {
      case 'new':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => _openQuoteDialog(context),
            icon: const Icon(Icons.request_quote_rounded, size: 17),
            label: const Text('R\u00e9pondre avec un devis'),
          ),
        );
      case 'quoted':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: AppColors.background, borderRadius: BorderRadius.circular(12)),
          child: const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, size: 15, color: AppColors.textMuted),
              SizedBox(width: 8),
              Expanded(
                child: Text('En attente de la r\u00e9ponse du client',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
        );
      case 'confirmed':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44), backgroundColor: AppColors.gold),
            onPressed: () => _openOtpDialog(context),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
            label: const Text('D\u00e9marrer avec le code OTP'),
          ),
        );
      case 'in_progress':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44), backgroundColor: AppColors.primary),
            onPressed: () => _completeProject(context),
            icon: const Icon(Icons.task_alt_rounded, size: 17),
            label: const Text('Marquer comme termin\u00e9'),
          ),
        );
      case 'completed':
        final invoiceUrl = request['invoiceUrl'] as String?;
        if (invoiceUrl == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: AppColors.textMuted),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Projet termin\u00e9 \u2014 facture pas encore disponible',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ),
              ],
            ),
          );
        }
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () => launchUrl(Uri.parse(invoiceUrl)),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('Voir la facture', style: TextStyle(fontSize: 12.5)),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _openQuoteDialog(BuildContext context) async {
    final priceController = TextEditingController();
    final notesController = TextEditingController();
    final durationController = TextEditingController();
    final teamSizeController = TextEditingController();
    final depositController = TextEditingController(text: '30');
    final warrantyController = TextEditingController(text: '12');
    bool materialsIncluded = true;
    String durationUnit = 'jours';
    bool depositRequired = true;
    bool warrantyOffered = true;
    int validityDays = 7;
    final lineItems = <(TextEditingController, TextEditingController)>[
      (TextEditingController(text: "Main d'\u0153uvre"), TextEditingController()),
    ];

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) => Padding(
            padding:
                EdgeInsets.fromLTRB(24, 22, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
            child: ListView(
              controller: scrollController,
              children: [
                const Text('Envoyer un devis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                    'Prix fixe et d\u00e9taill\u00e9 \u2014 le client ne pourra que l\'accepter ou le refuser, sans n\u00e9gociation.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                      labelText: 'Prix total (MAD) *',
                      prefixIcon: Icon(Icons.payments_rounded)),
                ),
                const SizedBox(height: 20),
                _QuoteSectionLabel('Mat\u00e9riaux'),
                _QuoteToggleRow(
                  label: 'Mat\u00e9riaux inclus dans le prix ?',
                  value: materialsIncluded,
                  onChanged: (v) => setSheet(() => materialsIncluded = v),
                ),
                const SizedBox(height: 18),
                _QuoteSectionLabel('D\u00e9lai d\'ex\u00e9cution'),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Dur\u00e9e estim\u00e9e'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: durationUnit,
                        decoration: const InputDecoration(labelText: 'Unit\u00e9'),
                        items: const [
                          DropdownMenuItem(value: 'heures', child: Text('Heures')),
                          DropdownMenuItem(value: 'jours', child: Text('Jours')),
                          DropdownMenuItem(value: 'semaines', child: Text('Semaines')),
                        ],
                        onChanged: (v) => setSheet(() => durationUnit = v ?? 'jours'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: teamSizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: "Taille de l'\u00e9quipe (optionnel)",
                      hintText: 'Ex: 3 techniciens',
                      prefixIcon: Icon(Icons.groups_rounded)),
                ),
                const SizedBox(height: 18),
                _QuoteSectionLabel('Acompte'),
                _QuoteToggleRow(
                  label: 'Demander un acompte \u00e0 la confirmation ?',
                  value: depositRequired,
                  onChanged: (v) => setSheet(() => depositRequired = v),
                ),
                if (depositRequired) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: depositController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "Pourcentage de l'acompte", suffixText: '%'),
                  ),
                ],
                const SizedBox(height: 18),
                _QuoteSectionLabel('Garantie'),
                _QuoteToggleRow(
                  label: 'Garantie sur le travail r\u00e9alis\u00e9 ?',
                  value: warrantyOffered,
                  onChanged: (v) => setSheet(() => warrantyOffered = v),
                ),
                if (warrantyOffered) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: warrantyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Dur\u00e9e de la garantie', suffixText: 'mois'),
                  ),
                ],
                const SizedBox(height: 18),
                _QuoteSectionLabel('Validit\u00e9 du devis'),
                Wrap(
                  spacing: 8,
                  children: [7, 15, 30].map((days) {
                    final selected = validityDays == days;
                    return ChoiceChip(
                      label: Text('$days jours'),
                      selected: selected,
                      onSelected: (_) => setSheet(() => validityDays = days),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                          color: selected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _QuoteSectionLabel('D\u00e9tail des co\u00fbts (optionnel)'),
                ...lineItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final (labelCtrl, amountCtrl) = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: labelCtrl,
                            decoration: const InputDecoration(
                                hintText: 'Ex: Mat\u00e9riaux', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(hintText: 'MAD', isDense: true),
                          ),
                        ),
                        IconButton(
                          onPressed: lineItems.length > 1
                              ? () => setSheet(() => lineItems.removeAt(i))
                              : null,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () => setSheet(() =>
                      lineItems.add((TextEditingController(), TextEditingController()))),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Ajouter une ligne', style: TextStyle(fontSize: 12.5)),
                ),
                const SizedBox(height: 18),
                _QuoteSectionLabel('Message pour le client (optionnel)'),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: 'Pr\u00e9cisions suppl\u00e9mentaires, conditions particuli\u00e8res\u2026'),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Envoyer le devis'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (submitted != true) return;
    final price = double.tryParse(priceController.text.trim());
    if (price == null || price <= 0) return;

    final builtLineItems = lineItems
        .where((e) => e.$1.text.trim().isNotEmpty && double.tryParse(e.$2.text.trim()) != null)
        .map((e) => {'label': e.$1.text.trim(), 'amountMAD': double.parse(e.$2.text.trim())})
        .toList();

    final newDurationValue = double.tryParse(durationController.text.trim()) ?? 1;
    final preferredDate = request['preferredDate'];
    if (context.mounted && preferredDate is Timestamp) {
      final newStart = DateTime(preferredDate.toDate().year, preferredDate.toDate().month,
          preferredDate.toDate().day);
      final newDays = _quoteDurationInDays(newDurationValue, durationUnit);
      final newEnd = newStart.add(Duration(days: newDays - 1));
      final others =
          await fs.streamQuoteRequestsForCompany(request['companyId'] as String).first;
      for (final other in others) {
        if (other['_id'] == requestId) continue;
        final otherStatus = other['status'] as String? ?? 'new';
        if (!['confirmed', 'in_progress'].contains(otherStatus)) continue;
        final otherPd = other['preferredDate'];
        if (otherPd is! Timestamp) continue;
        final otherStart =
            DateTime(otherPd.toDate().year, otherPd.toDate().month, otherPd.toDate().day);
        final otherDays = _quoteDurationInDays(
            (other['durationValue'] as num?)?.toDouble() ?? 1,
            other['durationUnit'] as String? ?? 'jours');
        final otherEnd = otherStart.add(Duration(days: otherDays - 1));
        final overlaps = !newEnd.isBefore(otherStart) && !otherEnd.isBefore(newStart);
        if (overlaps) {
          final dateFmt = DateFormat('dd/MM/yyyy');
          final otherClient = other['clientName'] as String? ?? 'un autre client';
          if (!context.mounted) return;
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Chevauchement de planning'),
              content: Text(
                  'Vous avez d\u00e9j\u00e0 un projet avec $otherClient du ${dateFmt.format(otherStart)} '
                  'au ${dateFmt.format(otherEnd)}. Ce nouveau projet (du ${dateFmt.format(newStart)} '
                  'au ${dateFmt.format(newEnd)}) chevauche cette p\u00e9riode.\n\n'
                  'Voulez-vous quand m\u00eame envoyer ce devis ?',
                  style: const TextStyle(fontSize: 13)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annuler')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                    child: const Text('Envoyer quand m\u00eame')),
              ],
            ),
          );
          if (proceed != true) return;
          break;
        }
      }
    }

    try {
      await fs.companySendQuote(
        requestId: requestId,
        priceMAD: price,
        notes: notesController.text.trim(),
        materialsIncluded: materialsIncluded,
        durationValue: double.tryParse(durationController.text.trim()) ?? 1,
        durationUnit: durationUnit,
        teamSize: int.tryParse(teamSizeController.text.trim()) ?? 0,
        depositPercent:
            depositRequired ? (double.tryParse(depositController.text.trim()) ?? 0) : 0,
        warrantyMonths:
            warrantyOffered ? (int.tryParse(warrantyController.text.trim()) ?? 0) : 0,
        validityDays: validityDays,
        lineItems: builtLineItems,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('\u00c9chec: $e')));
      }
    }
  }

  // PDF generation stubbed out — invoice_generator.dart and quote_document_generator.dart
  // are in .bak files. Invoice URL is stored in Firestore and opened directly.
  Future<void> _generateAndAttachQuoteDocument(BuildContext context,
      {required double priceMAD,
      required String notes,
      required bool materialsIncluded,
      required double durationValue,
      required String durationUnit,
      required int teamSize,
      required double depositPercent,
      required int warrantyMonths,
      required int validityDays,
      required List<Map<String, dynamic>> lineItems}) async {
    // PDF generation disabled — restore invoice_generator.dart.bak to re-enable
  }

  Future<void> _openOtpDialog(BuildContext context) async {
    final otpController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Code de d\u00e9marrage', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Demandez au client le code \u00e0 4 chiffres affich\u00e9 sur son \u00e9cran.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
              decoration: const InputDecoration(counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('D\u00e9marrer')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await fs.companyStartWithOtp(requestId, otpController.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chantier d\u00e9marr\u00e9 \u2713')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _completeProject(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marquer comme termin\u00e9 ?'),
        content: const Text('Le projet sera marqu\u00e9 termin\u00e9.',
            style: TextStyle(fontSize: 12.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await fs.companyCompleteProject(requestId: requestId);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          backgroundColor: AppColors.danger,
          content: Text('\u00c9chec: impossible de marquer le projet termin\u00e9 \u2014 $e'),
        ));
      }
      return;
    }
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _generateAndAttachInvoice(BuildContext context) async {
    // PDF generation disabled — restore invoice_generator.dart.bak to re-enable
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Facture disponible bient\u00f4t'),
    ));
  }
}

// =================================================================
// PROFILE
// =================================================================
class _CompanyProfileTab extends StatefulWidget {
  const _CompanyProfileTab({required this.profile, required this.fs});
  final CompanyProfile profile;
  final FirestoreService fs;
  @override
  State<_CompanyProfileTab> createState() => _CompanyProfileTabState();
}

class _CompanyProfileTabState extends State<_CompanyProfileTab> {
  CompanyProfile? _live;
  CompanyProfile get profile => _live ?? widget.profile;

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: Duration(seconds: error ? 6 : 2),
      backgroundColor: error ? AppColors.dangerDark : null,
      content: Text(message),
    ));
  }

  Future<void> _save(CompanyProfile updated) async {
    try {
      await widget.fs.saveMyCompanyProfile(updated);
      _toast('Enregistr\u00e9 \u2713');
    } catch (e) {
      _toast('\u00c9chec: $e', error: true);
    }
  }

  Future<void> _editText({
    required String title,
    required String initial,
    required void Function(String) onSave,
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 22, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(controller: controller, maxLines: maxLines, autofocus: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
    if (value != null) onSave(value);
  }

  Future<void> _editCity() async {
    final city = await showCityPicker(context, current: profile.city);
    if (city != null) await _save(profile.copyWith(city: city));
  }

  Future<void> _editCategories() async {
    final selected = Set<String>.from(profile.categories);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Secteurs d'activit\u00e9 (${selected.length})",
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: BigServiceCategory.all.map((cat) {
                        final on = selected.contains(cat.id);
                        return GestureDetector(
                          onTap: () =>
                              setSheet(() => on ? selected.remove(cat.id) : selected.add(cat.id)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                            decoration: BoxDecoration(
                              color: on ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.circular(22),
                              border:
                                  Border.all(color: on ? AppColors.primary : AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(cat.icon,
                                    size: 15,
                                    color: on ? Colors.white : AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(cat.label,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: on ? Colors.white : AppColors.textPrimary)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) await _save(profile.copyWith(categories: selected.toList()));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CompanyProfile?>(
      stream: widget.fs.streamCompany(widget.profile.companyId),
      builder: (context, snapshot) {
        _live = snapshot.data;
        return _buildBody(context);
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white,
                backgroundImage: profile.logoUrl != null ? NetworkImage(profile.logoUrl!) : null,
                child: profile.logoUrl == null
                    ? Text(profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary))
                    : null,
              ),
              const SizedBox(height: 12),
              Text(profile.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(profile.city,
                      style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
                  if (profile.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded, size: 15, color: Colors.white),
                  ],
                ],
              ),
              if (!profile.isVerified) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Text('En cours de v\u00e9rification par Brikol',
                      style: TextStyle(fontSize: 10.5, color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Portefeuille',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text('${profile.walletBalance.toStringAsFixed(0)} MAD',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        CompanyWalletDepositScreen(currentBalance: profile.walletBalance))),
                child: const Text('D\u00e9poser', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(title: 'Informations', children: [
          _EditRow(
              icon: Icons.badge_rounded,
              label: "Nom de l'entreprise",
              value: profile.name,
              onTap: () => _editText(
                  title: "Nom de l'entreprise",
                  initial: profile.name,
                  onSave: (v) => _save(profile.copyWith(name: v)))),
          _EditRow(
              icon: Icons.location_city_rounded,
              label: 'Ville',
              value: profile.city,
              onTap: _editCity),
          _EditRow(
              icon: Icons.phone_rounded,
              label: 'T\u00e9l\u00e9phone',
              value: profile.phone,
              onTap: () => _editText(
                  title: 'T\u00e9l\u00e9phone',
                  initial: profile.phone,
                  onSave: (v) => _save(profile.copyWith(phone: v)))),
          _EditRow(
              icon: Icons.notes_rounded,
              label: 'Pr\u00e9sentation',
              value: profile.description,
              onTap: () => _editText(
                  title: 'Pr\u00e9sentation',
                  initial: profile.description,
                  maxLines: 4,
                  onSave: (v) => _save(profile.copyWith(description: v)))),
        ]),
        const SizedBox(height: 14),
        _SectionCard(title: 'Activit\u00e9', children: [
          _EditRow(
              icon: Icons.category_rounded,
              label: "Secteurs d'activit\u00e9",
              value: '${profile.categories.length} s\u00e9lectionn\u00e9(s)',
              onTap: _editCategories),
          _EditRow(
              icon: Icons.payments_rounded,
              label: 'Fourchette de prix',
              value: profile.priceRangeMax > 0
                  ? '${profile.priceRangeMin.toStringAsFixed(0)} - ${profile.priceRangeMax.toStringAsFixed(0)} MAD'
                  : 'Non renseign\u00e9e',
              onTap: () async {
                final controller =
                    TextEditingController(text: profile.priceRangeMax.toStringAsFixed(0));
                final minController =
                    TextEditingController(text: profile.priceRangeMin.toStringAsFixed(0));
                final result = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Fourchette de prix', style: TextStyle(fontSize: 15)),
                    content: Row(
                      children: [
                        Expanded(
                            child: TextField(
                                controller: minController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Min'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Max'))),
                      ],
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annuler')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Enregistrer')),
                    ],
                  ),
                );
                if (result == true) {
                  await _save(profile.copyWith(
                    priceRangeMin: double.tryParse(minController.text.trim()) ?? 0,
                    priceRangeMax: double.tryParse(controller.text.trim()) ?? 0,
                  ));
                }
              }),
        ]),
        const SizedBox(height: 14),
        _SectionCard(title: 'Compte', children: [
          _EditRow(
            icon: Icons.logout_rounded,
            label: 'D\u00e9connexion',
            value: '',
            danger: true,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Se d\u00e9connecter ?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
                  ],
                ),
              );
              if (confirmed == true) await AuthService().signOut();
            },
          ),
        ]),
      ],
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({required this.status});
  final String status;
  static const _order = ['new', 'quoted', 'confirmed', 'in_progress', 'completed'];
  static const _navy = Color(0xFF1D3576);

  @override
  Widget build(BuildContext context) {
    if (status == 'declined') {
      return const Text('Refus\u00e9',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted));
    }
    final currentIndex = _order.indexOf(status);
    return Row(
      children: List.generate(_order.length * 2 - 1, (i) {
        if (i.isOdd) {
          final passed = (i - 1) ~/ 2 < currentIndex;
          return Expanded(child: Container(height: 2, color: passed ? _navy : AppColors.border));
        }
        final stepIndex = i ~/ 2;
        final done = stepIndex <= currentIndex;
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: done ? _navy : AppColors.border),
        );
      }),
    );
  }
}

class _QuoteSectionLabel extends StatelessWidget {
  const _QuoteSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: AppColors.textMuted)),
    );
  }
}

class _QuoteToggleRow extends StatelessWidget {
  const _QuoteToggleRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
            Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.textMuted)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: danger ? AppColors.danger : AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
                  if (value.isNotEmpty)
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}