import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../models/moroccan_cities.dart';
import '../../../../core/localization/app_localizations.dart';
import '../bloc/language_cubit.dart';
import 'sos_flow_screen.dart';
import 'ai_support_chat_screen.dart';
import '../../../../core/widgets/delete_account_tile.dart';
import '../../../../core/widgets/logout_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fs = FirestoreService();
  final _storage = StorageService();
  final _picker = ImagePicker();
  bool _uploadingPhoto = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: Duration(seconds: error ? 4 : 2),
        backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF0F5A47),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _changePhoto(String Function(String) t) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (file == null) return;

      setState(() => _uploadingPhoto = true);

      final bytes = await file.readAsBytes();

      final url = await _storage
          .upload(
            path: 'users/$_uid/profile.jpg',
            localPathOrIgnoredOnWeb: file.path,
            bytes: bytes,
            contentType: 'image/jpeg',
          )
          .timeout(const Duration(seconds: 20));

      await _fs.updateUserProfile(_uid, photoUrl: url);
      _toast(t('ok'));
    } catch (e) {
      _toast('${t('failed')}: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _editName(String current, String Function(String) t) async {
    final controller = TextEditingController(text: current);

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              t('account_name'),
              style: const TextStyle(color: Color(0xFF192A24), fontWeight: FontWeight.w800),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Color(0xFF192A24), fontWeight: FontWeight.w600),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF2F7F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('cancel'), style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F5A47),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(t('save'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );

    if (value != null && value.isNotEmpty) {
      try {
        await _fs.updateUserProfile(_uid, fullName: value);
        _toast(t('ok'));
      } catch (e) {
        _toast('${t('failed')}: $e', error: true);
      }
    }
  }

  Future<void> _editCity(String? current) async {
    final city = await showCityPicker(context, current: current);
    if (city != null) {
      try {
        await _fs.updateUserProfile(_uid, city: city);
        _toast(city);
      } catch (e) {
        final t = context.read<LanguageCubit>().state.t;
        _toast('${t('failed')}: $e', error: true);
      }
    }
  }

  Future<void> _addAddress(String Function(String) t) async {
    final labelController = TextEditingController();
    final detailsController = TextEditingController();
    String preset = t('address_label_home');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('address_new_title'),
                style: const TextStyle(color: Color(0xFF192A24), fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  t('address_label_home'),
                  t('address_label_work'),
                  t('save'),
                ].map((option) {
                  final selected = preset == option;
                  return ChoiceChip(
                    label: Text(option),
                    selected: selected,
                    selectedColor: const Color(0xFF0F5A47),
                    backgroundColor: const Color(0xFFF2F7F5),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF192A24),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (_) => setSheet(() => preset = option),
                  );
                }).toList(),
              ),
              if (preset == t('save')) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: labelController,
                  style: const TextStyle(color: Color(0xFF192A24)),
                  decoration: InputDecoration(
                    labelText: t('addresses_add'),
                    filled: true,
                    fillColor: const Color(0xFFF2F7F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                style: const TextStyle(color: Color(0xFF192A24)),
                decoration: InputDecoration(
                  labelText: t('location_add_hint'),
                  filled: true,
                  fillColor: const Color(0xFFF2F7F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F5A47),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                  label: Text(
                    t('address_capture'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true) return;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 12));
      final otherLabel = t('save');
      final label = preset == otherLabel
          ? (labelController.text.trim().isEmpty ? t('addresses_add') : labelController.text.trim())
          : preset;

      await _fs.addUserAddress(
        uid: _uid,
        label: label,
        lat: pos.latitude,
        lng: pos.longitude,
        details: detailsController.text.trim(),
      );
      _toast(label);
    } catch (e) {
      _toast('${t('failed')}: $e', error: true);
    }
  }

  void _showAddressesSheet(List<Map<String, dynamic>> addresses, String Function(String) t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('addresses_title'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF192A24)),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0F5A47)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _addAddress(t);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (addresses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(t('addresses_empty'), style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              )
            else
              ...addresses.map((addr) {
                final label = addr['label'] as String? ?? t('addresses_add');
                final details = addr['details'] as String? ?? '';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined, color: Color(0xFF0F5A47)),
                  title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF192A24))),
                  subtitle: details.isNotEmpty ? Text(details) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                    onPressed: () async {
                      try {
                        await _fs.removeUserAddress(_uid, addr);
                        Navigator.pop(ctx);
                        _toast(t('ok'));
                      } catch (e) {
                        _toast('${t('failed')}: $e', error: true);
                      }
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _showFavoritesSheet(List<String> favoriteIds, String Function(String) t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('favorites_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF192A24)),
            ),
            const SizedBox(height: 12),
            if (favoriteIds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(t('favorites_empty'), style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              )
            else
              ...favoriteIds.map((id) {
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _fs.streamTechnician(id),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final name = data?['fullName'] as String? ?? t('chat_default_technician');
                    final rating = (data?['rating'] as num?)?.toDouble() ?? 5.0;

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFE8F5F1),
                        child: Icon(Icons.person, color: Color(0xFF0F5A47), size: 18),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF192A24))),
                      subtitle: Text('⭐ ${rating.toStringAsFixed(1)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => SosFlowScreen(preferredTechId: id)),
                              );
                            },
                            child: Text(t('favorites_order'), style: const TextStyle(color: Color(0xFF0F5A47), fontWeight: FontWeight.w800)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite_rounded, size: 18, color: Color(0xFFEF4444)),
                            onPressed: () async {
                              await _fs.toggleFavoriteTech(_uid, id, false);
                              Navigator.pop(ctx);
                              _toast(t('favorite_remove'));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    if (_uid.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFA),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _fs.streamUserProfile(_uid),
        builder: (context, userSnap) {
          final user = userSnap.data ?? {};
          final name = user['fullName'] as String? ?? '';
          final email = user['email'] as String? ?? FirebaseAuth.instance.currentUser?.email ?? '';
          final city = user['city'] as String? ?? '';
          final photoUrl = user['photoUrl'] as String?;
          final phone = user['phone'] as String? ?? '';
          final credit = (user['creditMAD'] as num?)?.toDouble() ?? 0;
          final addresses = (user['addresses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final favoriteIds = (user['favoriteTechIds'] as List?)?.cast<String>() ?? [];
          final referralCode =
              'BRIKOOL-${_uid.length >= 6 ? _uid.substring(0, 6).toUpperCase() : _uid.toUpperCase()}';

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Emerald Brikool Gradient Header
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color(0xFF063A2D),
                        Color(0xFF0F5A47),
                        Color(0xFF04271E),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Bar Controls
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_rounded, size: 16, color: Color(0xFF4ADE80)),
                                        const SizedBox(width: 6),
                                        Text(
                                          t('nav_profile'),
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (credit > 0)
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        '🎁 ${credit.toStringAsFixed(0)} MAD',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                    ),
                                  Material(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => context.read<LanguageCubit>().toggle(),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                        child: Text(
                                          context.read<LanguageCubit>().state.language == AppLanguage.fr ? 'العربية' : 'FR',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Identity & Avatar Box
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _uploadingPhoto ? null : () => _changePhoto(t),
                                    child: Stack(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFF4ADE80), width: 2),
                                          ),
                                          child: CircleAvatar(
                                            radius: 34,
                                            backgroundColor: Colors.white.withOpacity(0.15),
                                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                            child: photoUrl == null
                                                ? Text(
                                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                    style: const TextStyle(
                                                      fontSize: 26,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF4ADE80),
                                              shape: BoxShape.circle,
                                            ),
                                            child: _uploadingPhoto
                                                ? const SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child: CircularProgressIndicator(color: Color(0xFF063A2D), strokeWidth: 2),
                                                  )
                                                : const Icon(Icons.camera_alt_rounded, size: 12, color: Color(0xFF063A2D)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.isEmpty ? '${t('nav_profile')} 👋' : '$name 👋',
                                          style: const TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.white.withOpacity(0.8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () => _editName(name, t),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(Icons.edit_rounded, size: 12, color: Color(0xFF0F5A47)),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Modifier le profil',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0F5A47),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Body Content Cards
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                      child: Column(
                        children: [
                          // 1. Group: Activity & Quick Access
                          _ThemedCard(
                            children: [
                              _ThemedTile(
                                icon: Icons.favorite_border_rounded,
                                title: t('favorites_title'),
                                trailingBadge: favoriteIds.isNotEmpty ? '${favoriteIds.length}' : null,
                                onTap: () => _showFavoritesSheet(favoriteIds, t),
                              ),
                              _ThemedTile(
                                icon: Icons.location_on_outlined,
                                title: t('addresses_title'),
                                trailingBadge: addresses.isNotEmpty ? '${addresses.length}' : null,
                                onTap: () => _showAddressesSheet(addresses, t),
                              ),
                              _ThemedTile(
                                icon: Icons.card_giftcard_rounded,
                                title: t('referral_title'),
                                trailingBadge: referralCode,
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: referralCode));
                                  _toast(t('referral_copied'));
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 2. Group: Profile & System Settings
                          _ThemedCard(
                            children: [
                              _ThemedTile(
                                icon: Icons.language_rounded,
                                title: t('account_language'),
                                trailingBadge: context.read<LanguageCubit>().state.language == AppLanguage.fr ? 'FR' : 'ع',
                                onTap: () => context.read<LanguageCubit>().toggle(),
                              ),
                              _ThemedTile(
                                icon: Icons.location_city_rounded,
                                title: t('account_city'),
                                trailingBadge: city.isEmpty ? t('location_where') : city,
                                onTap: () => _editCity(city.isEmpty ? null : city),
                              ),
                              _ThemedTile(
                                icon: Icons.phone_outlined,
                                title: t('account_phone'),
                                trailingBadge: phone.isEmpty ? '—' : phone,
                              ),
                              _ThemedTile(
                                icon: Icons.smart_toy_outlined,
                                title: t('account_assistant'),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const AiSupportChatScreen()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 3. Group: Legal & Account Termination
                          _ThemedCard(
                            children: [
                              _ThemedTile(
                                icon: Icons.description_outlined,
                                title: t('account_terms'),
                                onTap: () => launchUrl(
                                  Uri.parse('https://brikool.online/terms.html'),
                                  mode: LaunchMode.externalApplication,
                                ),
                              ),
                              _ThemedTile(
                                icon: Icons.shield_outlined,
                                title: t('account_privacy'),
                                onTap: () => launchUrl(
                                  Uri.parse('https://brikool.online/privacy.html'),
                                  mode: LaunchMode.externalApplication,
                                ),
                              ),
                              DeleteAccountTile(uid: _uid, userType: 'client', fs: _fs),
                              _ThemedTile(
                                icon: Icons.logout_rounded,
                                title: t('account_logout'),
                                color: const Color(0xFFEF4444),
                                onTap: () => signOutWithCheck(
                                  context: context,
                                  uid: _uid,
                                  userType: 'client',
                                  fs: _fs,
                                  t: t,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // App Version Label
                          Center(
                            child: Text(
                              'Brikool v1.0.0',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =================================================================
// REUSABLE THEMED COMPONENTS MATCHING HOME SCREEN
// =================================================================
class _ThemedCard extends StatelessWidget {
  const _ThemedCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: children.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 0.8,
          indent: 52,
          endIndent: 16,
          color: Colors.grey.shade100,
        ),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _ThemedTile extends StatelessWidget {
  const _ThemedTile({
    required this.icon,
    required this.title,
    this.trailingBadge,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? trailingBadge;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(icon, color: color ?? const Color(0xFF0F5A47), size: 20),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? const Color(0xFF192A24),
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingBadge != null) ...[
            Text(
              trailingBadge!,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}