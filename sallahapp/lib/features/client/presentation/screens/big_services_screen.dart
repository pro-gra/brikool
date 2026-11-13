import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../models/big_service_category.dart';
import '../../../../models/company_profile.dart';
import 'my_project_requests_screen.dart';

/// Entry point for "Grands Services" — large-scale projects handled
/// by partner companies (windows, wiring, aluminum, painting,
/// construction) rather than individual technicians.
class BigServicesScreen extends StatelessWidget {
  const BigServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Grands Services',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Mes demandes',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const MyProjectRequestsScreen())),
            icon: const Icon(Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Un grand projet ? 🏗️',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 6),
                        const Text(
                            'Entreprises partenaires vérifiées pour vos '
                            'projets de grande envergure — devis gratuit.',
                            style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Choisissez une catégorie',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...BigServiceCategory.all.map((cat) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              CompanyListScreen(category: cat))),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration:
                            BoxDecoration(border: Border.all(color: AppColors.border)),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Icon(cat.icon, color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cat.label,
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(cat.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// Companies available for a given category.
class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key, required this.category});
  final BigServiceCategory category;

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  String? _preferredCity;
  bool _cityLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferredCity();
  }

  Future<void> _loadPreferredCity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _cityLoaded = true);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _preferredCity = doc.data()?['city'] as String?;
          _cityLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cityLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(widget.category.label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: !_cityLoaded
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<List<CompanyProfile>>(
                stream: firestoreService.streamCompanies(
                    categoryId: widget.category.id, preferredCity: _preferredCity),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Erreur: ${snapshot.error}',
                            style: const TextStyle(fontSize: 12.5)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final companies = snapshot.data!;
                  if (companies.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(widget.category.icon, size: 40, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text('Aucune entreprise partenaire pour le moment',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text(
                                'Nous ajoutons de nouveaux partenaires régulièrement.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  }
                  final hasLocalMatch = _preferredCity != null &&
                      companies.any((c) => c.city.toLowerCase() == _preferredCity!.toLowerCase());
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                    color: AppColors.primary, shape: BoxShape.circle),
                                child: const Icon(Icons.verified_rounded,
                                    size: 18, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  hasLocalMatch
                                      ? '${companies.length} entreprises disponibles - triées près de $_preferredCity'
                                      : companies.length == 1
                                          ? '1 entreprise disponible pour ce type de projet'
                                          : '${companies.length} entreprises disponibles pour ce type de projet',
                                  style: const TextStyle(
                                      fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: companies.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, i) => TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 320 + i * 60),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                  offset: Offset(0, 14 * (1 - value)), child: child),
                            ),
                            child: _CompanyCard(company: companies[i], category: widget.category),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// Deterministic realistic-looking placeholder photo for a company
/// that hasn't uploaded a real cover photo yet (no Storage plan active
/// = no real uploads possible right now). Same seed always returns
/// the same image, so a given company looks consistent across visits.
String companyPlaceholderPhoto(String seed, {int width = 400, int height = 220}) {
  return 'https://picsum.photos/seed/$seed/$width/$height';
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.company, required this.category});
  final CompanyProfile company;
  final BigServiceCategory category;

  @override
  Widget build(BuildContext context) {
    final coverUrl = company.coverPhotoUrl ?? companyPlaceholderPhoto(company.companyId);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                CompanyDetailScreen(company: company, category: category))),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Image.network(coverUrl,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : Container(height: 130, color: AppColors.background),
                      errorBuilder: (_, __, ___) =>
                          Container(height: 130, color: AppColors.primaryLight)),
                  if (company.isVerified)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1D3576),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2)),
                            ]),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 11, color: Colors.white),
                            SizedBox(width: 3),
                            Text('VÉRIFIÉE',
                                style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -28),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryLight,
                          border: Border.all(color: AppColors.surface, width: 3),
                          image: company.logoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(company.logoUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: company.logoUrl == null
                            ? Center(
                                child: Text(company.name.isNotEmpty ? company.name[0] : '?',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        color: AppColors.primary)))
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(0, -4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(company.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 2),
                                Text(company.city,
                                    style: const TextStyle(
                                        fontSize: 11.5, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    company.reviewCount > 0
                        ? _StatPill(
                            icon: Icons.star_rounded,
                            label:
                                '${company.rating.toStringAsFixed(1)} (${company.reviewCount})',
                            accent: true)
                        : const _StatPill(icon: Icons.fiber_new_rounded, label: 'Nouveau partenaire'),
                    if (company.projectsCompleted > 0)
                      _StatPill(
                          icon: Icons.task_alt_rounded, label: '${company.projectsCompleted} projets'),
                    if (company.yearsInBusiness > 0)
                      _StatPill(
                          icon: Icons.workspace_premium_rounded,
                          label: '${company.yearsInBusiness} ans'),
                    if (company.priceRangeMax > 0)
                      _StatPill(
                        icon: Icons.payments_rounded,
                        label:
                            '${company.priceRangeMin.toStringAsFixed(0)}-${company.priceRangeMax.toStringAsFixed(0)} MAD',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, this.accent = false});
  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent ? const Color(0xFF1D3576).withOpacity(0.08) : AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent ? const Color(0xFF1D3576) : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent ? const Color(0xFF1D3576) : AppColors.textPrimary)),
        ],
      ),
    );
  }
}

/// Full company profile + quote request form.
class CompanyDetailScreen extends StatelessWidget {
  const CompanyDetailScreen(
      {super.key, required this.company, required this.category});
  final CompanyProfile company;
  final BigServiceCategory category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          children: [
            if (company.coverPhotoUrl != null)
              Image.network(company.coverPhotoUrl!,
                  height: 180, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(company.name,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800)),
                      ),
                      if (company.isVerified)
                        const Icon(Icons.verified_rounded,
                            color: Color(0xFF2B4EAE)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _Stat(label: 'Note', value: '${company.rating.toStringAsFixed(1)}★'),
                      _Stat(label: 'Projets', value: '${company.projectsCompleted}'),
                      _Stat(label: 'Expérience', value: '${company.yearsInBusiness} ans'),
                      _Stat(label: 'Ville', value: company.city),
                    ],
                  ),
                  if (company.priceRangeMax > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(14)),
                      child: Text(
                          'Devis indicatif: ${company.priceRangeMin.toStringAsFixed(0)} – ${company.priceRangeMax.toStringAsFixed(0)} MAD\n(le prix final dépend de votre projet)',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success)),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text('À propos',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(company.description,
                      style: const TextStyle(
                          fontSize: 13, height: 1.5, color: AppColors.textSecondary)),
                  if (company.portfolioUrls.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Réalisations',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: company.portfolioUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(company.portfolioUrls[i],
                              width: 100, height: 100, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
                      onPressed: () => _openQuoteDialog(context),
                      icon: const Icon(Icons.request_quote_rounded, size: 18),
                      label: const Text('Demander un devis gratuit'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (company.phone.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                        onPressed: () =>
                            launchUrl(Uri(scheme: 'tel', path: company.phone)),
                        icon: const Icon(Icons.phone_rounded, size: 17),
                        label: Text('Appeler ${company.name}'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openQuoteDialog(BuildContext context) async {
    final descriptionController = TextEditingController();
    final phoneController =
        TextEditingController(text: FirebaseAuth.instance.currentUser?.phoneNumber ?? '');
    final addressController = TextEditingController(text: company.city);
    final picker = ImagePicker();
    final photos = <(XFile, Uint8List)>[];
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Demande de devis — ${company.name}',
                    style:
                        const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                    'Décrivez précisément votre projet — l\'entreprise vous répondra avec un prix fixe.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Décrivez votre projet *',
                      hintText: 'Ex: Remplacer 8 fenêtres dans une villa R+1…'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now().add(const Duration(days: 3)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setSheet(() => selectedDate = picked);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_rounded,
                                  size: 17,
                                  color: selectedDate != null
                                      ? AppColors.primary
                                      : AppColors.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedDate != null
                                      ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                                      : 'Date souhaitée *',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: selectedDate != null
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (picked != null) setSheet(() => selectedTime = picked);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 17,
                                  color: selectedTime != null
                                      ? AppColors.primary
                                      : AppColors.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedTime != null
                                      ? selectedTime!.format(ctx)
                                      : 'Heure *',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: selectedTime != null
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                      labelText: 'Adresse complète du projet *',
                      hintText: 'Rue, quartier, ville…'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Votre téléphone *'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ...photos.map((p) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(p.$2, width: 56, height: 56, fit: BoxFit.cover),
                          ),
                        )),
                    if (photos.length < 4)
                      GestureDetector(
                        onTap: () async {
                          final file = await picker.pickImage(
                              source: ImageSource.gallery, imageQuality: 70);
                          if (file == null) return;
                          final bytes = await file.readAsBytes();
                          setSheet(() => photos.add((file, bytes)));
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_a_photo_rounded,
                              size: 20, color: AppColors.textMuted),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (descriptionController.text.trim().isEmpty ||
                            phoneController.text.trim().isEmpty ||
                            addressController.text.trim().isEmpty ||
                            selectedDate == null ||
                            selectedTime == null)
                        ? null
                        : () => Navigator.pop(ctx, true),
                    child: const Text('Envoyer la demande'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (submitted != true) return;
    if (!context.mounted) return;
    if (selectedDate == null || selectedTime == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final conflict =
        await FirestoreService().findActiveRequestForCategory(uid, category.id);
    if (conflict != null) {
      if (!context.mounted) return;
      const statusLabels = {
        'new': 'en attente de devis',
        'quoted': 'devis reçu, en attente de votre réponse',
        'confirmed': 'confirmée, en attente de démarrage',
        'in_progress': 'en cours',
      };
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Commande déjà en cours'),
          content: Text(
              'Vous avez déjà une commande "${category.label}" en cours avec '
              '${conflict.companyName} (${statusLabels[conflict.status] ?? conflict.status}). '
              'Vous pourrez en soumettre une nouvelle une fois celle-ci terminée ou refusée.\n\n'
              'Vous pouvez toujours demander un devis dans une autre catégorie.',
              style: const TextStyle(fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Compris')),
          ],
        ),
      );
      return;
    }

    final combinedDate = DateTime(selectedDate!.year, selectedDate!.month,
        selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
    final timeLabel =
        '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

    try {
      final storageService = StorageService();
      final mediaUrls = <String>[];
      for (var i = 0; i < photos.length; i++) {
        try {
          final url = await storageService
              .upload(
                path: 'company_quotes/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
                localPathOrIgnoredOnWeb: photos[i].$1.path,
                bytes: photos[i].$2,
                contentType: 'image/jpeg',
              )
              .timeout(const Duration(seconds: 40));
          mediaUrls.add(url);
        } catch (_) {}
      }

      await FirestoreService().submitCompanyQuoteRequest(
        companyId: company.companyId,
        companyName: company.name,
        clientId: uid,
        clientName: FirebaseAuth.instance.currentUser?.displayName ?? '',
        clientPhone: phoneController.text.trim(),
        categoryId: category.id,
        description: descriptionController.text.trim(),
        preferredDate: combinedDate,
        preferredTime: timeLabel,
        address: addressController.text.trim(),
        mediaUrls: mediaUrls,
        city: addressController.text.trim(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(
                'Demande envoyée à ${company.name} ✓ Vous recevrez un devis dans "Mes demandes".')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Échec: $e')));
      }
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.background, borderRadius: BorderRadius.circular(10)),
      child: Text('$label: $value',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}