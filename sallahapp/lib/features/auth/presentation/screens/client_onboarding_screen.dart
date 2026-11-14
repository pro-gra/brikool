import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../models/moroccan_cities.dart';

const Color _green = Color(0xFF087A4B);
const Color _deepGreen = Color(0xFF06432F);
const Color _ink = Color(0xFF17251E);
const Color _muted = Color(0xFF718078);
const Color _line = Color(0xFFE5ECE7);

class ClientOnboardingScreen extends StatefulWidget {
  const ClientOnboardingScreen({super.key});

  @override
  State<ClientOnboardingScreen> createState() => _ClientOnboardingScreenState();
}

class _ClientOnboardingScreenState extends State<ClientOnboardingScreen> {
  final FirestoreService _firestore = FirestoreService();
  final StorageService _storage = StorageService();
  final TextEditingController _nameController = TextEditingController();

  int _step = 0;
  bool _isArabic = false;
  bool _saving = false;
  String? _city;
  String? _error;
  Uint8List? _photoBytes;
  XFile? _photoFile;

  final Set<String> _selectedNeeds = {'Maison'};

  final List<_NeedOption> _options = const [
    _NeedOption('Maison', 'الدار', 'Plomberie, électricité, peinture', Icons.home_repair_service_rounded),
    _NeedOption('Voiture', 'الطوموبيل', 'Mécanique et dépannage', Icons.directions_car_rounded),
    _NeedOption('Cuisine', 'المطبخ', 'Électroménager', Icons.kitchen_rounded),
    _NeedOption('Climatisation', 'الكليماتيزور', 'Installation et entretien', Icons.ac_unit_rounded),
  ];

  String _t(String french, String arabic) => _isArabic ? arabic : french;

  bool get _canContinue {
    if (_step == 0) return _selectedNeeds.isNotEmpty;
    if (_step == 1) return _city != null;
    if (_step == 2) return _nameController.text.trim().length >= 2;
    return true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 900,
    );
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoFile = file;
      _photoBytes = bytes;
    });
  }

  Future<void> _finish() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = _t('Session expirée. Reconnectez-vous.', 'انتهت الجلسة. يرجى تسجيل الدخول مجدداً.');
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      String? photoUrl;
      if (_photoFile != null && _photoBytes != null) {
        photoUrl = await _storage.uploadUserImage(
          uid: user.uid,
          fileName: 'profile.jpg',
          localPathOrIgnoredOnWeb: _photoFile!.path,
          webBytes: _photoBytes,
        );
      }

      await _firestore.updateUserProfile(
        user.uid,
        fullName: _nameController.text.trim(),
        city: _city,
        photoUrl: photoUrl,
        referralSource: _selectedNeeds.join(', '),
        clientOnboardingComplete: true,
      );

      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _t(
          'Impossible d’enregistrer. Vérifiez votre connexion et réessayez.',
          'تعذر حفظ المعلومات. تحقق من الاتصال وحاول مرة أخرى.',
        );
      });
    }
  }

  void _next() {
    if (!_canContinue) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _step = (_step + 1).clamp(0, 3);
    });
  }

  void _back() {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _step = (_step - 1).clamp(0, 3);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> titles = [
      _t('Vos besoins', 'احتياجاتك'),
      _t('Votre ville', 'مدينتك'),
      _t('Votre profil', 'ملفك الشخصي'),
      _t('Vérification', 'مراجعة المعلومات'),
    ];
    final List<String> subtitles = [
      _t('Quels services recherchez-vous ?', 'شنو الخدمات اللي كتحتاج؟'),
      _t('Pour trouver des professionnels près de chez vous.', 'باش نلقاو ليك مهنيين قريبين منك.'),
      _t('Comment pouvons-nous vous appeler ?', 'شنو الاسم ديالك؟'),
      _t('Vérifiez vos informations avant de terminer.', 'راجع معلوماتك قبل التأكيد.'),
    ];

    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F6F3),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(titles[_step], subtitles[_step]),
                          const SizedBox(height: 18),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _buildStepContent(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],
                          const SizedBox(height: 18),
                          _buildNavigation(),
                          const SizedBox(height: 14),
                          Text(
                            _t('VOS INFORMATIONS RESTENT MODIFIABLES', 'يمكنك تعديل معلوماتك لاحقاً'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF8A9990),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 15, 22, 10),
      child: Row(
        children: [
          const Text(
            'brikool',
            style: TextStyle(
              color: _deepGreen,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -.8,
            ),
          ),
          const Spacer(),
          _languageButton('FR', false),
          const SizedBox(width: 6),
          _languageButton('ع', true),
        ],
      ),
    );
  }

  Widget _languageButton(String label, bool arabic) {
    final bool selected = _isArabic == arabic;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => setState(() => _isArabic = arabic),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _deepGreen : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_deepGreen, Color(0xFF0B7650)],
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: _deepGreen.withOpacity(.13),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _t('CONFIGURATION DU COMPTE', 'إعداد الحساب'),
                style: const TextStyle(
                  color: Color(0xFFB9D8C8),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${_step + 1} / 4',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(4, (index) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsetsDirectional.only(end: index == 3 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: index <= _step ? const Color(0xFFB8E2C9) : Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 19),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFFD6E9DE), fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildNeedsStep();
      case 1:
        return _buildCityStep();
      case 2:
        return _buildProfileStep();
      default:
        return _buildReviewStep();
    }
  }

  Widget _panel({required Key key, required Widget child}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(color: Color(0x0B173D29), blurRadius: 18, offset: Offset(0, 7)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildNeedsStep() {
    return _panel(
      key: const ValueKey('needs'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Sélectionnez vos catégories', 'اختار المجالات'),
            style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            _t('Choisissez une ou plusieurs catégories.', 'اختار مجال واحد أو أكثر.'),
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 15),
          ..._options.map((option) {
            final bool selected = _selectedNeeds.contains(option.french);
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedNeeds.remove(option.french);
                    } else {
                      _selectedNeeds.add(option.french);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFEAF4EE) : const Color(0xFFFAFCFA),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: selected ? _green : _line, width: selected ? 1.4 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: selected ? _green : const Color(0xFFEDF2EE),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(option.icon, color: selected ? Colors.white : _muted),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(option.french, option.arabic),
                              style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(option.description, style: const TextStyle(color: _muted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Icon(
                        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: selected ? _green : _muted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          Text(
            _t('${_selectedNeeds.length} catégorie(s) sélectionnée(s)', '${_selectedNeeds.length} مجالات مختارة'),
            style: const TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildCityStep() {
    final List<String> popularCities = [
      'Casablanca', 'Rabat', 'Marrakech', 'Tanger', 'Fès', 'Agadir',
    ];
    return _panel(
      key: const ValueKey('city'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Dans quelle ville habitez-vous ?', 'فأي مدينة ساكن؟'),
            style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            _t('Choisissez votre ville principale.', 'اختار المدينة الرئيسية ديالك.'),
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 15),
          ...popularCities.map((city) {
            final bool selected = _city == city;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _city = city),
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFEAF4EE) : const Color(0xFFFAFCFA),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: selected ? _green : _line),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_city_outlined, color: selected ? _green : _muted, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(city, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                      if (selected) const Icon(Icons.check_circle, color: _green, size: 19),
                    ],
                  ),
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () async {
              final String? selectedCity = await showCityPicker(context, current: _city);
              if (selectedCity != null && mounted) {
                setState(() => _city = selectedCity);
              }
            },
            icon: const Icon(Icons.search),
            label: Text(_t('Rechercher une autre ville', 'البحث عن مدينة أخرى')),
            style: OutlinedButton.styleFrom(
              foregroundColor: _green,
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: _line),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return _panel(
      key: const ValueKey('profile'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Comment vous appeler ?', 'شنو الاسم ديالك؟'),
            style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            _t('Votre nom apparaîtra sur vos demandes.', 'الاسم ديالك غادي يبان فالطلبات.'),
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 21),
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: const Color(0xFFEAF4EE),
                    backgroundImage: _photoBytes == null ? null : MemoryImage(_photoBytes!),
                    child: _photoBytes == null
                        ? const Icon(Icons.person_outline_rounded, color: _muted, size: 42)
                        : null,
                  ),
                  Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Center(
            child: Text(
              _t('Ajouter une photo (facultatif)', 'إضافة صورة (اختياري)'),
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            _t('NOM COMPLET', 'الاسم الكامل'),
            style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: _t('Ex. : Sara El Amrani', 'مثال: سارة العمراني'),
              prefixIcon: const Icon(Icons.person_outline_rounded),
              filled: true,
              fillColor: const Color(0xFFFAFCFA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _green, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final String needs = _options
        .where((option) => _selectedNeeds.contains(option.french))
        .map((option) => _t(option.french, option.arabic))
        .join(' · ');

    return _panel(
      key: const ValueKey('review'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Vérifiez votre compte', 'راجع الحساب ديالك'),
            style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            _t('Vous pouvez modifier chaque rubrique.', 'تقدر تعدل أي معلومة.'),
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 15),
          _reviewRow(Icons.home_repair_service_outlined, _t('Mes besoins', 'احتياجاتي'), needs, 0),
          const Divider(height: 22, color: _line),
          _reviewRow(Icons.location_on_outlined, _t('Ma ville', 'مدينتي'), _city ?? '—', 1),
          const Divider(height: 22, color: _line),
          _reviewRow(Icons.person_outline_rounded, _t('Mon nom', 'اسمي'), _nameController.text.trim(), 2),
          if (_photoBytes != null) ...[
            const Divider(height: 22, color: _line),
            Row(
              children: [
                ClipOval(child: Image.memory(_photoBytes!, width: 42, height: 42, fit: BoxFit.cover)),
                const SizedBox(width: 10),
                Text(
                  _t('Photo de profil ajoutée', 'تمت إضافة الصورة'),
                  style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6F2),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              _t(
                'Vos informations resteront modifiables depuis votre profil.',
                'يمكنك تعديل معلوماتك لاحقاً من ملفك الشخصي.',
              ),
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(IconData icon, String title, String value, int targetStep) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4EE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _green, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: _muted, fontSize: 11)),
              Text(value, style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _step = targetStep),
          child: Text(
            _t('Modifier', 'تعديل'),
            style: const TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigation() {
    return Row(
      children: [
        if (_step > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : _back,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 54),
                foregroundColor: _ink,
                side: const BorderSide(color: _line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              child: Text(_t('Retour', 'رجوع')),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: _saving ? null : (_step == 3 ? _finish : (_canContinue ? _next : null)),
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              disabledBackgroundColor: const Color(0xFFCBD8CF),
              minimumSize: const Size(0, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _step == 3
                        ? _t('Confirmer et terminer', 'تأكيد وإنهاء')
                        : _t('Continuer', 'متابعة'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
          ),
        ),
      ],
    );
  }
}

class _NeedOption {
  const _NeedOption(this.french, this.arabic, this.description, this.icon);

  final String french;
  final String arabic;
  final String description;
  final IconData icon;
}
