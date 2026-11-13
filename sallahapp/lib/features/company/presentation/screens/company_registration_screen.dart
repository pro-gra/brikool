import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../models/company_profile.dart';
import '../../../../models/big_service_category.dart';
import '../../../../models/moroccan_cities.dart';

/// Self-service company registration: the business owner signs in
/// (same phone-auth as everyone else) and fills this once. After
/// submitting, they land straight on their own dashboard (leads +
/// profile) — no admin step required to start receiving requests,
/// though an admin can still grant a "Vérifiée" badge later.
class CompanyRegistrationScreen extends StatefulWidget {
  const CompanyRegistrationScreen({super.key});

  @override
  State<CompanyRegistrationScreen> createState() =>
      _CompanyRegistrationScreenState();
}

class _CompanyRegistrationScreenState
    extends State<CompanyRegistrationScreen> {
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceMinController = TextEditingController();
  final _priceMaxController = TextEditingController();
  final _yearsController = TextEditingController();
  String? _city;
  final Set<String> _selectedCategories = {};

  XFile? _logoFile;
  Uint8List? _logoBytes;
  XFile? _coverFile;
  Uint8List? _coverBytes;
  final List<(XFile, Uint8List)> _portfolio = [];

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _phoneController.text = user?.phoneNumber ?? '';
  }

  Future<void> _pickLogo() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _logoFile = file;
      _logoBytes = bytes;
    });
  }

  Future<void> _pickCover() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _coverFile = file;
      _coverBytes = bytes;
    });
  }

  Future<void> _pickPortfolioPhoto() async {
    if (_portfolio.length >= 6) return;
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _portfolio.add((file, bytes)));
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      (_city ?? '').isNotEmpty &&
      _selectedCategories.isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) {
      setState(() => _error = 'Merci de remplir tous les champs obligatoires (*)');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      String? logoUrl;
      String? coverUrl;
      final portfolioUrls = <String>[];

      if (_logoBytes != null) {
        try {
          logoUrl = await _storageService
              .upload(
                path: 'companies/${user.uid}/logo.jpg',
                localPathOrIgnoredOnWeb: _logoFile!.path,
                bytes: _logoBytes!,
                contentType: 'image/jpeg',
              )
              .timeout(const Duration(seconds: 40));
        } catch (_) {} // best-effort — a slow logo upload shouldn't block signup
      }
      if (_coverBytes != null) {
        try {
          coverUrl = await _storageService
              .upload(
                path: 'companies/${user.uid}/cover.jpg',
                localPathOrIgnoredOnWeb: _coverFile!.path,
                bytes: _coverBytes!,
                contentType: 'image/jpeg',
              )
              .timeout(const Duration(seconds: 40));
        } catch (_) {} // best-effort — same reasoning
      }
      for (var i = 0; i < _portfolio.length; i++) {
        try {
          final url = await _storageService
              .upload(
                path: 'companies/${user.uid}/portfolio_$i.jpg',
                localPathOrIgnoredOnWeb: _portfolio[i].$1.path,
                bytes: _portfolio[i].$2,
                contentType: 'image/jpeg',
              )
              .timeout(const Duration(seconds: 40));
          portfolioUrls.add(url);
        } catch (_) {} // best-effort — one failed photo shouldn't block signup
      }

      final profile = CompanyProfile(
        companyId: user.uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        city: _city!,
        categories: _selectedCategories.toList(),
        description: _descriptionController.text.trim(),
        priceRangeMin: double.tryParse(_priceMinController.text.trim()) ?? 0,
        priceRangeMax: double.tryParse(_priceMaxController.text.trim()) ?? 0,
        yearsInBusiness: int.tryParse(_yearsController.text.trim()) ?? 0,
        logoUrl: logoUrl,
        coverPhotoUrl: coverUrl,
        portfolioUrls: portfolioUrls,
        isActive: true,
        onboardingComplete: true,
      );

      await _firestoreService.saveMyCompanyProfile(profile);
      // No manual navigation needed — main.dart's _CompanyGate listens
      // to this same document and routes to CompanyShell automatically.
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Échec de l\'inscription: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Inscrire mon entreprise',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.apartment_rounded, color: Colors.white, size: 26),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'Recevez des demandes de gros projets (aluminium, peinture, '
                        'électricité bâtiment, construction…) directement dans '
                        'votre tableau de bord.',
                        style: TextStyle(fontSize: 12.5, color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---- Logo & cover ----
            Row(
              children: [
                GestureDetector(
                  onTap: _pickLogo,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: _logoBytes != null ? MemoryImage(_logoBytes!) : null,
                    child: _logoBytes == null
                        ? const Icon(Icons.add_a_photo_rounded,
                            color: AppColors.primary, size: 22)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickCover,
                    icon: Icon(
                        _coverBytes != null ? Icons.check_circle_rounded : Icons.image_rounded,
                        size: 17),
                    label: Text(_coverBytes != null
                        ? 'Photo de couverture ✓'
                        : 'Ajouter une photo de couverture'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text('Nom de l\'entreprise *',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Ex: Alu Pro Casablanca')),
            const SizedBox(height: 16),

            const Text('Téléphone *',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '+212 6 12 34 56 78')),
            const SizedBox(height: 16),

            const Text('Email (optionnel)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'contact@entreprise.ma')),
            const SizedBox(height: 16),

            const Text('Ville *',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final city = await showCityPicker(context, current: _city);
                if (city != null) setState(() => _city = city);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_city_rounded,
                        size: 19, color: _city != null ? AppColors.primary : AppColors.textMuted),
                    const SizedBox(width: 10),
                    Text(_city ?? 'Choisir la ville…',
                        style: TextStyle(
                            fontSize: 14,
                            color: _city != null ? AppColors.textPrimary : AppColors.textMuted)),
                    const Spacer(),
                    const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Secteurs d\'activité * (sélectionnez-en un ou plusieurs)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BigServiceCategory.all.map((cat) {
                final on = _selectedCategories.contains(cat.id);
                return GestureDetector(
                  onTap: () => setState(
                      () => on ? _selectedCategories.remove(cat.id) : _selectedCategories.add(cat.id)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: on ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: on ? AppColors.primary : AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon, size: 15, color: on ? Colors.white : AppColors.textSecondary),
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
            const SizedBox(height: 16),

            const Text('Présentation de l\'entreprise *',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                  hintText:
                      'Ex: 12 ans d\'expérience en menuiserie aluminium, plus de 300 chantiers réalisés à Casablanca et région…'),
            ),
            const SizedBox(height: 16),

            const Text('Fourchette de prix indicative (optionnel)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                      controller: _priceMinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min (MAD)')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                      controller: _priceMaxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max (MAD)')),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('Années d\'expérience (optionnel)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
                controller: _yearsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Ex: 10')),
            const SizedBox(height: 16),

            Text('Portfolio — photos de vos réalisations (${_portfolio.length}/6)',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...List.generate(_portfolio.length, (i) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_portfolio[i].$2,
                            width: 72, height: 72, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: GestureDetector(
                          onTap: () => setState(() => _portfolio.removeAt(i)),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                                color: AppColors.danger, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                if (_portfolio.length < 6)
                  GestureDetector(
                    onTap: _pickPortfolioPhoto,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.add_a_photo_rounded,
                          size: 22, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.danger)),
            ],

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Créer mon compte entreprise'),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Un badge "Vérifiée" peut être ajouté par SALLAH après examen.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}