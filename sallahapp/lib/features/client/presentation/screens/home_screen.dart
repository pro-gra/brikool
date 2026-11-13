import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../models/service_category.dart';
import '../../../../models/catalog.dart';
import '../../../../models/technician_profile.dart';
import '../bloc/language_cubit.dart';
import 'orders_screen.dart';
import 'sos_flow_screen.dart';
import 'technician_public_profile.dart';
import 'ai_assistant_bubble.dart';
import 'big_services_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();
  String? _locationLabel;
  Map<String, dynamic>? _userProfile;
  StreamSubscription? _profileSub;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _profileSub = _firestoreService.streamUserProfile(uid).listen((data) {
        if (mounted) setState(() => _userProfile = data);
      });
    }
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  Future<void> _resolveLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _locationLabel = location?.label);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return BlocBuilder<LanguageCubit, LanguageState>(
      builder: (context, state) {
        final t = state.t;
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth >= 1024;
        final isTablet = screenWidth >= 640 && screenWidth < 1024;

        return Directionality(
          textDirection: state.language.direction,
          child: Scaffold(
            backgroundColor: const Color(0xFFF7FAFA),
            body: Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HeaderSection(
                        state: state,
                        locationLabel: _locationLabel,
                        uid: user?.uid,
                        userProfile: _userProfile,
                        firestoreService: _firestoreService,
                        onRefreshLocation: _resolveLocation,
                        isDesktop: isDesktop,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1140),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 28 : 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                if (user != null)
                                  _ActiveOrderCard(
                                    uid: user.uid,
                                    firestoreService: _firestoreService,
                                    state: state,
                                  ),
                                const SizedBox(height: 18),
                                _SectionHeading(
                                  title: t('most_requested'),
                                  badge: 'PRO',
                                ),
                                const SizedBox(height: 12),
                                _ServiceShortcutsStrip(state: state),
                                const SizedBox(height: 22),
                                const _PromoCarousel(),
                                const SizedBox(height: 26),
                                _SectionHeading(
                                  title: t('services_heading'),
                                  badge: 'PRO',
                                ),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1140),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 28 : 16,
                            ),
                            child: _ResponsiveCategoryGrid(
                              state: state,
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (user != null)
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1140),
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: isDesktop ? 28 : 0,
                                right: isDesktop ? 28 : 0,
                                top: 24,
                              ),
                              child: _TopTechniciansRail(
                                city: _userProfile?['city'] as String? ?? '',
                                firestoreService: _firestoreService,
                                state: state,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 110)),
                  ],
                ),
                const AiAssistantBubble(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =================================================================
// HEADER SECTION
// =================================================================
class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.state,
    required this.locationLabel,
    required this.uid,
    required this.userProfile,
    required this.firestoreService,
    required this.onRefreshLocation,
    required this.isDesktop,
  });

  final LanguageState state;
  final String? locationLabel;
  final String? uid;
  final Map<String, dynamic>? userProfile;
  final FirestoreService firestoreService;
  final VoidCallback onRefreshLocation;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final t = state.t;
    final fullName = userProfile?['fullName'] as String? ?? '';
    final firstName = fullName.isEmpty ? '' : fullName.split(' ').first;
    final credit = (userProfile?['creditMAD'] as num?)?.toDouble() ?? 0;
    final greeting = t('greeting');

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF063A2D),
            Color(0xFF0A5542),
            Color(0xFF04271E),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1140),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 28 : 16,
              MediaQuery.of(context).padding.top + 14,
              isDesktop ? 28 : 16,
              26,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: ActiveLocation.selected,
                      builder: (context, chosen, _) {
                        final label = chosen != null
                            ? chosen['label'] as String? ?? t('location_add_hint')
                            : (locationLabel ?? t('location_current'));
                        return InkWell(
                          onTap: () => _showLocationPicker(
                            context,
                            uid,
                            firestoreService,
                            locationLabel,
                            onRefreshLocation,
                            t,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withOpacity(0.18)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4ADE80),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: isDesktop ? 240 : 130),
                                  child: Text(
                                    label,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white70),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    if (credit > 0)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '🎁 ${credit.toStringAsFixed(0)} MAD',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    Material(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.read<LanguageCubit>().toggle(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Text(
                            state.language == AppLanguage.fr ? 'FR' : 'ع',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(20),
                      elevation: 3,
                      shadowColor: const Color(0xFFEF4444).withOpacity(0.4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SosFlowScreen()),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt_rounded, size: 17, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                t('sos_title'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              firstName.isEmpty ? '$greeting 👋' : '$greeting, $firstName 👋',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t('greeting_sub'),
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: _HeaderSearchBar(state: state),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName.isEmpty ? '$greeting 👋' : '$greeting, $firstName 👋',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        t('greeting_sub'),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _HeaderSearchBar(state: state),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSearchBar extends StatelessWidget {
  const _HeaderSearchBar({required this.state});
  final LanguageState state;

  @override
  Widget build(BuildContext context) {
    final t = state.t;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showServiceSearch(context, t),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 22, color: Color(0xFF0F5A47)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t('search_placeholder'),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F6F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, size: 14, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Text(
                      t('search_hint').split(' ').first,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
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

// =================================================================
// SECTION HEADING
// =================================================================
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.badge});
  final String title;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF192A24),
            letterSpacing: -0.2,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0F5A47).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F5A47),
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}

// =================================================================
// SHORTCUTS STRIP
// =================================================================
class _ServiceShortcutsStrip extends StatelessWidget {
  const _ServiceShortcutsStrip({required this.state});
  final LanguageState state;

  @override
  Widget build(BuildContext context) {
    final t = state.t;
    final shortcuts = [
      (emoji: '🚿', label: t('shortcut_plumbing'), skillId: 'plumbing'),
      (emoji: '⚡', label: t('shortcut_electricity'), skillId: 'electricity'),
      (emoji: '❄️', label: t('shortcut_clim'), skillId: 'clim'),
      (emoji: '🔧', label: t('shortcut_handyman'), skillId: 'handyman'),
      (emoji: '🚗', label: t('shortcut_mechanic'), skillId: 'mecanique'),
      (emoji: '🎨', label: t('shortcut_painting'), skillId: 'painting'),
      (emoji: '🔒', label: t('shortcut_locksmith'), skillId: 'locksmith'),
      (emoji: '➕', label: t('shortcut_more'), skillId: ''),
    ];

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: shortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = shortcuts[i];
          return Container(
            width: 82,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (s.skillId.isEmpty) {
                    _showServiceSearch(context, t);
                    return;
                  }
                  final all = <ServiceOffer>[
                    ...sosOffers(t),
                    for (final list in categoryCatalog(t).values) ...list,
                  ];
                  final offer = all.firstWhere(
                    (o) => o.skillId == s.skillId,
                    orElse: () => ServiceOffer(
                      skillId: s.skillId,
                      label: s.label,
                      sublabel: '',
                      icon: Icons.build_rounded,
                      suggestedBudget: 150,
                    ),
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SosFlowScreen(preselected: offer)),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F7F5),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(s.emoji, style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(height: 7),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =================================================================
// PROMO CAROUSEL
// =================================================================
class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();
  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _controller = PageController(viewportFraction: 1.0);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _page = (_page + 1) % 3;
      _controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final promos = [
      (
        title: t('promo_negotiated_prices'),
        sub: t('promo_negotiated_prices_sub'),
        colors: [const Color(0xFF0A4E3D), const Color(0xFF052A21)],
        icon: Icons.handshake_rounded
      ),
      (
        title: t('promo_verified_technicians'),
        sub: t('promo_verified_technicians_sub'),
        colors: [const Color(0xFF1B3D77), const Color(0xFF10254C)],
        icon: Icons.verified_user_rounded
      ),
      (
        title: t('promo_earn_credits'),
        sub: t('promo_earn_credits_sub'),
        colors: [const Color(0xFFB85918), const Color(0xFF7F3B0D)],
        icon: Icons.card_giftcard_rounded
      ),
    ];

    return SizedBox(
      height: 104,
      child: PageView.builder(
        controller: _controller,
        onPageChanged: (i) => _page = i,
        itemCount: promos.length,
        itemBuilder: (context, i) {
          final item = promos[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: item.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, size: 24, color: Colors.white),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =================================================================
// CATEGORY GRID
// =================================================================
const Map<ServiceCategory, String> _categoryImages = {
  ServiceCategory.auto: 'https://images.unsplash.com/photo-1487754180451-c456f719a1fc?w=500&q=60',
  ServiceCategory.home: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=500&q=60',
  ServiceCategory.appliance: 'https://images.unsplash.com/photo-1556911220-bff31c812dba?w=500&q=60',
  ServiceCategory.moto: 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=500&q=60',
  ServiceCategory.transport: 'https://images.unsplash.com/photo-1519003722824-194d4455a60c?w=500&q=60',
  ServiceCategory.carwash: 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?w=500&q=60',
};

class _ResponsiveCategoryGrid extends StatelessWidget {
  const _ResponsiveCategoryGrid({
    required this.state,
    required this.isDesktop,
    required this.isTablet,
  });

  final LanguageState state;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final t = state.t;
    final categories = ServiceCategory.values;
    final crossCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final totalCount = categories.length + 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isDesktop ? 1.45 : 1.30,
      ),
      itemCount: totalCount,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Material(
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BigServicesScreen()),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0B4636), Color(0xFF041F18)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.apartment_rounded, color: Color(0xFF0B4636), size: 19),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      t('cat_big_projects'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final cat = categories[i - 1];
        final imageUrl = _categoryImages[cat];

        return Material(
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showCategorySheet(context, cat, state),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F5A47)),
                  )
                else
                  Container(color: const Color(0xFF0F5A47)),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0xD9000000)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(cat.icon, size: 18, color: const Color(0xFF0B4636)),
                      ),
                      Text(
                        t(cat.labelKey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =================================================================
// TOP TECHNICIANS RAIL
// =================================================================
class _TopTechniciansRail extends StatelessWidget {
  const _TopTechniciansRail({
    required this.city,
    required this.firestoreService,
    required this.state,
  });

  final String city;
  final FirestoreService firestoreService;
  final LanguageState state;

  @override
  Widget build(BuildContext context) {
    final t = state.t;
    return StreamBuilder<List<TechnicianProfile>>(
      stream: firestoreService.streamTopTechnicians(city, limit: 8),
      builder: (context, techSnap) {
        final techs = techSnap.data ?? [];
        if (techs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionHeading(
                title: city.isEmpty
                    ? '🏆 ${t('top_technicians')}'
                    : '🏆 ${t('top_technicians_city').replaceFirst('{city}', city)}',
                badge: 'PRO',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 134,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: techs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final tech = techs[i];
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => showTechnicianPublicProfile(context, tech.techId),
                      child: Container(
                        width: 108,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.withOpacity(0.12)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 23,
                              backgroundColor: const Color(0xFF0F5A47).withOpacity(0.08),
                              backgroundImage: tech.profilePhotoUrl != null
                                  ? NetworkImage(tech.profilePhotoUrl!)
                                  : null,
                              child: tech.profilePhotoUrl == null
                                  ? Text(
                                      tech.fullName.isNotEmpty ? tech.fullName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Color(0xFF0F5A47), fontWeight: FontWeight.w800),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tech.fullName.isEmpty ? t('chat_default_technician') : tech.fullName.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '⭐ ${tech.rating.toStringAsFixed(1)} (${tech.jobsDone})',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// =================================================================
// ACTIVE ORDER CARD
// =================================================================
class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({
    required this.uid,
    required this.firestoreService,
    required this.state,
  });

  final String uid;
  final FirestoreService firestoreService;
  final LanguageState state;

  @override
  Widget build(BuildContext context) {
    final t = state.t;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: firestoreService.streamActiveRequestForClient(uid),
      builder: (context, snapshot) {
        final activeOrder = snapshot.data;
        if (activeOrder == null) return const SizedBox.shrink();

        final status = activeOrder['status'] as String? ?? '';
        final requestId = activeOrder['requestId'] as String;
        final label = activeOrder['serviceLabel'] as String? ?? t('orders_title');

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 2,
          shadowColor: const Color(0xFF0F5A47).withOpacity(0.06),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => OrderDetailScreen(requestId: requestId)),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F5A47).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sync_rounded, color: Color(0xFF0F5A47), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          status == 'pending' ? t('active_order_negotiating') : t('active_order_assigned'),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF0F5A47)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =================================================================
// BOTTOM SHEETS
// =================================================================
void _showServiceSearch(BuildContext context, String Function(String) t) {
  final all = <ServiceOffer>[
    ...sosOffers(t),
    for (final list in categoryCatalog(t).values) ...list,
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      var query = '';
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              final results = query.isEmpty
                  ? all
                  : all
                      .where((o) =>
                          o.label.toLowerCase().contains(query.toLowerCase()) ||
                          o.sublabel.toLowerCase().contains(query.toLowerCase()))
                      .toList();
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.82,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(99)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                        child: TextField(
                          autofocus: true,
                          onChanged: (v) => setSheet(() => query = v),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF2F7F6),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            hintText: t('search_hint'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF0F5A47)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: results.isEmpty
                            ? Center(
                                child: Text(t('search_no_result'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                                itemCount: results.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final offer = results[i];
                                  return ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: Colors.grey.withOpacity(0.12)),
                                    ),
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F5A47).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(offer.icon, size: 20, color: const Color(0xFF0F5A47)),
                                    ),
                                    title: Text(offer.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                    subtitle: Text(offer.sublabel, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => SosFlowScreen(preselected: offer)),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

void _showCategorySheet(BuildContext context, ServiceCategory category, LanguageState state) {
  final t = state.t;
  final offers = categoryCatalog(t)[category] ?? const <ServiceOffer>[];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
                    Text(t(category.labelKey), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(t('category_choose_price'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: offers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final offer = offers[i];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.withOpacity(0.12)),
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F5A47).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(offer.icon, size: 20, color: const Color(0xFF0F5A47)),
                            ),
                            title: Text(offer.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                            subtitle: Text(offer.sublabel, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => SosFlowScreen(preselected: offer)),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showLocationPicker(
  BuildContext context,
  String? uid,
  FirestoreService firestoreService,
  String? currentLocationLabel,
  VoidCallback onRefreshLocation,
  String Function(String) t,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: uid == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<Map<String, dynamic>?>(
                      stream: firestoreService.streamUserProfile(uid),
                      builder: (context, snapshot) {
                        final addresses =
                            (snapshot.data?['addresses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                        final chosen = ActiveLocation.selected.value;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                width: 44,
                                height: 4,
                                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(99)),
                              ),
                            ),
                            Text(t('location_where'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 12),
                            ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: chosen == null ? const Color(0xFF0F5A47) : Colors.transparent,
                                ),
                              ),
                              tileColor: chosen == null ? const Color(0xFF0F5A47).withOpacity(0.08) : const Color(0xFFF7FAFA),
                              leading: const Icon(Icons.my_location_rounded, size: 20, color: Color(0xFF0F5A47)),
                              title: Text(t('location_current'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                              subtitle: Text(currentLocationLabel ?? t('location_gps'), style: const TextStyle(fontSize: 11.5)),
                              trailing: chosen == null
                                  ? const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF0F5A47))
                                  : null,
                              onTap: () {
                                ActiveLocation.selected.value = null;
                                onRefreshLocation();
                                Navigator.pop(ctx);
                              },
                            ),
                            ...addresses.map((address) {
                              final label = address['label'] as String? ?? t('location_add_hint');
                              final details = address['details'] as String? ?? '';
                              final isChosen = chosen != null &&
                                  chosen['label'] == label &&
                                  chosen['lat'] == address['lat'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: isChosen ? const Color(0xFF0F5A47) : Colors.transparent,
                                    ),
                                  ),
                                  tileColor: isChosen ? const Color(0xFF0F5A47).withOpacity(0.08) : const Color(0xFFF7FAFA),
                                  leading: Icon(
                                    label == 'Maison'
                                        ? Icons.home_rounded
                                        : label == 'Travail'
                                            ? Icons.work_rounded
                                            : Icons.place_rounded,
                                    size: 20,
                                    color: const Color(0xFF0F5A47),
                                  ),
                                  title: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                  subtitle: details.isEmpty ? null : Text(details, style: const TextStyle(fontSize: 11.5)),
                                  trailing: isChosen
                                      ? const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF0F5A47))
                                      : null,
                                  onTap: () {
                                    ActiveLocation.selected.value = Map<String, dynamic>.from(address);
                                    Navigator.pop(ctx);
                                  },
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            Text(t('location_add_hint'), style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ),
      );
    },
  );
}