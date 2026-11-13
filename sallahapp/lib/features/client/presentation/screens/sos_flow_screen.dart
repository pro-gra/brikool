import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../models/catalog.dart';
import '../bloc/language_cubit.dart';
import 'orders_screen.dart';

/// Budget-based request flow (InDrive-style): choose service ->
/// details -> propose YOUR price -> technicians accept or counter.
class SosFlowScreen extends StatefulWidget {
  const SosFlowScreen({super.key, this.preselected, this.preferredTechId});
  final ServiceOffer? preselected;
  final String? preferredTechId;

  @override
  State<SosFlowScreen> createState() => _SosFlowScreenState();
}

class _SosFlowScreenState extends State<SosFlowScreen> {
  final _firestoreService = FirestoreService();
  late int _step;
  ServiceOffer? _chosen;
  final _descriptionController = TextEditingController();
  late final TextEditingController _budgetController;
  final _promoController = TextEditingController();
  final _picker = ImagePicker();
  final _storageService = StorageService();
  final List<(XFile, Uint8List)> _photos = [];
  final _aiService = AiService();
  PhotoDiagnosis? _diagnosis;
  bool _diagnosing = false;
  String? _diagnosisError;

  Future<void> _runDiagnosis() async {
    if (_photos.isEmpty || _diagnosing) return;
    final t = context.read<LanguageCubit>().state.t;
    setState(() { _diagnosing = true; _diagnosisError = null; });
    try {
      final result = await _aiService.diagnosePhoto(
        imageBytes: _photos.first.$2,
        description: _descriptionController.text.trim(),
      );
      if (mounted) setState(() => _diagnosis = result);
    } catch (e) {
      if (mounted) setState(() => _diagnosisError = t('error'));
    } finally {
      if (mounted) setState(() => _diagnosing = false);
    }
  }

  DateTime? _scheduledAt;
  double _promoDiscount = 0;
  String? _validPromoCode;
  bool _dispatching = false;
  String? _dispatchError;

  Future<void> _addPhoto() async {
    if (_photos.length >= 3) return;
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _photos.add((file, bytes)));
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;
    setState(() => _scheduledAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _applyPromo() async {
    final t = context.read<LanguageCubit>().state.t;
    final code = _promoController.text.trim();
    if (code.isEmpty) return;
    try {
      final promo = await _firestoreService.validatePromoCode(code);
      setState(() {
        _validPromoCode = promo['code'] as String;
        _promoDiscount = promo['amountMAD'] as double;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${t('budget_discount')}: -${_promoDiscount.toStringAsFixed(0)} MAD ✓'),
        ));
      }
    } catch (e) {
      setState(() { _validPromoCode = null; _promoDiscount = 0; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _chosen = widget.preselected;
    _step = widget.preselected != null ? 1 : 0;
    _budgetController = TextEditingController(
      text: widget.preselected?.suggestedBudget.toStringAsFixed(0) ?? '',
    );
  }

  void _goTo(int step) => setState(() => _step = step);
  bool get _canGoBack => widget.preselected != null ? _step > 1 : _step > 0;

  Future<void> _confirmAndDispatch() async {
    if (_dispatching) return;
    final t = context.read<LanguageCubit>().state.t;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _dispatchError = t('error')); return; }

    final budget = double.tryParse(_budgetController.text.trim());
    if (budget == null || budget < 20) {
      setState(() => _dispatchError = t('budget_error_min'));
      return;
    }

    setState(() { _dispatching = true; _dispatchError = null; });

    try {
      double? lat;
      double? lng;
      final chosenAddress = ActiveLocation.selected.value;
      if (chosenAddress != null) {
        lat = (chosenAddress['lat'] as num?)?.toDouble();
        lng = (chosenAddress['lng'] as num?)?.toDouble();
      }
      if (lat == null || lng == null) {
        try {
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) await Geolocator.requestPermission();
          final position = await Geolocator.getCurrentPosition();
          lat = position.latitude;
          lng = position.longitude;
        } catch (_) {}
      }

      String clientName = '';
      try {
        final profile = await _firestoreService.streamUserProfile(user.uid).first;
        clientName = profile?['fullName'] as String? ?? '';
      } catch (_) {}

      final requestId = await _firestoreService.createRequest(
        clientId: user.uid,
        clientName: clientName,
        skillId: _chosen!.skillId,
        serviceLabel: _chosen!.label,
        budgetMad: budget,
        description: _descriptionController.text.trim(),
        clientLat: lat ?? 33.5731,
        clientLng: lng ?? -7.5898,
        scheduledAt: _scheduledAt,
        preferredTechId: widget.preferredTechId,
        promoCode: _validPromoCode,
        discountMad: _promoDiscount,
      );

      if (_photos.isNotEmpty) {
        try {
          final urls = <String>[];
          for (var i = 0; i < _photos.length; i++) {
            final url = await _storageService
                .upload(
                  path: 'requests/$requestId/photo_$i.jpg',
                  localPathOrIgnoredOnWeb: _photos[i].$1.path,
                  bytes: _photos[i].$2,
                  contentType: 'image/jpeg',
                )
                .timeout(const Duration(seconds: 12));
            urls.add(url);
          }
          await _firestoreService.attachMediaToRequest(requestId, urls);
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(requestId: requestId)),
      );
    } on StateError catch (e) {
      setState(() => _dispatching = false);
      if (e.message == 'active_order_exists' && mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t('order_cancel_confirm_title')),
            content: Text(t('active_order_negotiating')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('ok'))),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() { _dispatching = false; _dispatchError = t('budget_error_network'); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: _canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _goTo(_step - 1),
              )
            : null,
        title: Text(
          switch (_step) {
            0 => t('sos_flow_step0'),
            1 => t('sos_flow_step1'),
            _ => t('budget_title'),
          },
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_step) {
            0 => _ChooseStep(
                t: t,
                onSelected: (offer) {
                  _chosen = offer;
                  _budgetController.text = offer.suggestedBudget.toStringAsFixed(0);
                  _goTo(1);
                },
              ),
            1 => _DetailsStep(
                offer: _chosen!,
                descriptionController: _descriptionController,
                photos: _photos,
                onAddPhoto: _addPhoto,
                onRemovePhoto: (i) => setState(() { _photos.removeAt(i); _diagnosis = null; }),
                diagnosis: _diagnosis,
                diagnosing: _diagnosing,
                diagnosisError: _diagnosisError,
                onRunDiagnosis: _runDiagnosis,
                onContinue: () => _goTo(2),
              ),
            _ => _BudgetStep(
                offer: _chosen!,
                budgetController: _budgetController,
                promoController: _promoController,
                scheduledAt: _scheduledAt,
                promoDiscount: _promoDiscount,
                onPickSchedule: _pickSchedule,
                onClearSchedule: () => setState(() => _scheduledAt = null),
                onApplyPromo: _applyPromo,
                onConfirm: _confirmAndDispatch,
                dispatching: _dispatching,
                error: _dispatchError,
              ),
          },
        ),
      ),
    );
  }
}

// =================================================================
// STEP 0 — CHOOSE SERVICE
// =================================================================
class _ChooseStep extends StatelessWidget {
  const _ChooseStep({required this.t, required this.onSelected});
  final String Function(String) t;
  final ValueChanged<ServiceOffer> onSelected;

  @override
  Widget build(BuildContext context) {
    final offers = sosOffers(t);
    return ListView.separated(
      itemCount: offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final offer = offers[i];
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelected(offer),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(offer.icon, color: AppColors.danger, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(offer.label,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(offer.sublabel,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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
// STEP 1 — DETAILS
// =================================================================
class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.offer,
    required this.descriptionController,
    required this.photos,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.diagnosis,
    required this.diagnosing,
    required this.diagnosisError,
    required this.onRunDiagnosis,
    required this.onContinue,
  });
  final ServiceOffer offer;
  final TextEditingController descriptionController;
  final List<(XFile, Uint8List)> photos;
  final VoidCallback onAddPhoto;
  final ValueChanged<int> onRemovePhoto;
  final PhotoDiagnosis? diagnosis;
  final bool diagnosing;
  final String? diagnosisError;
  final VoidCallback onRunDiagnosis;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(offer.icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(offer.label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(t('sos_describe'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: descriptionController,
          maxLines: 4,
          decoration: InputDecoration(hintText: t('sos_describe_hint')),
        ),
        const SizedBox(height: 18),
        Text(t('sos_photos'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(t('sos_photos_sub'),
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        Row(
          children: [
            ...List.generate(photos.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(photos[i].$2, width: 64, height: 64, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: -6, top: -6,
                      child: GestureDetector(
                        onTap: () => onRemovePhoto(i),
                        child: Container(
                          width: 20, height: 20,
                          decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (photos.length < 3)
              GestureDetector(
                onTap: onAddPhoto,
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.add_a_photo_rounded, size: 22, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 14),
          if (diagnosis == null)
            OutlinedButton.icon(
              onPressed: diagnosing ? null : onRunDiagnosis,
              icon: diagnosing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(diagnosing ? t('invoice_generating') : t('account_assistant')),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('${t('account_assistant')} — ${diagnosis!.category}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 6),
                  Text(diagnosis!.problemSummary,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                    '${t('order_budget_label')}: '
                    '${diagnosis!.estimatedPriceMin.toStringAsFixed(0)}–'
                    '${diagnosis!.estimatedPriceMax.toStringAsFixed(0)} MAD',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(diagnosis!.confidenceNote,
                      style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                ],
              ),
            ),
          if (diagnosisError != null) ...[
            const SizedBox(height: 8),
            Text(diagnosisError!, style: const TextStyle(fontSize: 11.5, color: AppColors.danger)),
          ],
        ],
        const SizedBox(height: 28),
        ElevatedButton(onPressed: onContinue, child: Text(t('continue'))),
      ],
    );
  }
}

// =================================================================
// STEP 2 — BUDGET
// =================================================================
class _BudgetStep extends StatelessWidget {
  const _BudgetStep({
    required this.offer,
    required this.budgetController,
    required this.promoController,
    required this.scheduledAt,
    required this.promoDiscount,
    required this.onPickSchedule,
    required this.onClearSchedule,
    required this.onApplyPromo,
    required this.onConfirm,
    required this.dispatching,
    required this.error,
  });
  final ServiceOffer offer;
  final TextEditingController budgetController;
  final TextEditingController promoController;
  final DateTime? scheduledAt;
  final double promoDiscount;
  final VoidCallback onPickSchedule;
  final VoidCallback onClearSchedule;
  final VoidCallback onApplyPromo;
  final VoidCallback onConfirm;
  final bool dispatching;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return ListView(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
          child: const Icon(Icons.handshake_rounded, color: AppColors.primary, size: 30),
        ),
        const SizedBox(height: 16),
        Text(t('budget_title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(t('budget_sub'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        TextField(
          controller: budgetController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          decoration: const InputDecoration(suffixText: 'MAD', hintText: '0'),
        ),
        const SizedBox(height: 10),
        Text(
          '${t('budget_sub')} "${offer.label}" : ~${offer.suggestedBudget.toStringAsFixed(0)} MAD',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: scheduledAt == null ? AppColors.primaryLight : null,
                ),
                onPressed: onClearSchedule,
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: Text(t('budget_now'), style: const TextStyle(fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: scheduledAt != null ? AppColors.primaryLight : null,
                ),
                onPressed: onPickSchedule,
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: Text(
                  scheduledAt == null
                      ? t('budget_schedule')
                      : DateFormat('dd/MM HH:mm').format(scheduledAt!),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: promoController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: t('budget_promo_hint'),
                  prefixIcon: const Icon(Icons.local_offer_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(onPressed: onApplyPromo, child: Text(t('budget_promo_apply'))),
          ],
        ),
        if (promoDiscount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${t('budget_discount')}: -${promoDiscount.toStringAsFixed(0)} MAD 🎉',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
          ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
        ],
        const SizedBox(height: 22),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: dispatching ? null : onConfirm,
          child: dispatching
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(t('budget_publish')),
        ),
      ],
    );
  }
}