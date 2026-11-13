import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../models/technician_profile.dart';
import '../../../../models/technician_specialty.dart';
import '../../../../models/technician_skill.dart';
import '../../../client/presentation/bloc/language_cubit.dart';

class SpecialtyManagerSection extends StatelessWidget {
  const SpecialtyManagerSection({super.key, required this.profile});
  final TechnicianProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final specialties = profile.specialties;
    final canAdd = profile.canAddMoreSpecialties;
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
          child: Row(children: [
            Expanded(child: Row(children: [
              Text(t('specialty_title'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: AppColors.textMuted)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: canAdd ? AppColors.primaryLight : AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${specialties.length}/3', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800,
                    color: canAdd ? AppColors.primaryDark : AppColors.danger)),
              ),
            ])),
            if (canAdd)
              TextButton.icon(
                onPressed: () => _openAddSheet(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(t('specialty_add_btn'), style: const TextStyle(fontSize: 12.5)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              )
            else
              Padding(padding: const EdgeInsets.only(right: 12),
                  child: Text(t('specialty_max_reached'),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.danger, fontWeight: FontWeight.w600))),
          ]),
        ),
        if (specialties.isEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(t('specialty_empty'), style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)))
        else
          ...specialties.map((s) => _SpecialtyTile(specialty: s)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_rounded, size: 14, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(child: Text(t('specialty_approval_info'),
                  style: const TextStyle(fontSize: 11, color: AppColors.primaryDark))),
            ]),
          ),
        ),
      ]),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _AddSpecialtySheet(existingSpecialties: profile.specialties, techId: profile.techId),
    );
  }
}

class _SpecialtyTile extends StatelessWidget {
  const _SpecialtyTile({required this.specialty});
  final TechnicianSpecialty specialty;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final (badgeColor, badgeBg, badgeLabel) = switch (specialty.status) {
      SpecialtyStatus.approved => (AppColors.success, AppColors.successLight, t('specialty_status_approved')),
      SpecialtyStatus.pending => (const Color(0xFF9A6A00), const Color(0xFFFBF1DD), t('specialty_status_pending')),
      SpecialtyStatus.rejected => (AppColors.danger, AppColors.dangerLight, t('specialty_status_rejected')),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: specialty.isRejected ? AppColors.danger.withOpacity(0.4) : AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 32, height: 32,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(9)),
                child: Icon(TechnicianSkill.all.where((s) => s.id == specialty.skillId).map((s) => s.icon).firstOrNull ?? Icons.build_rounded,
                    size: 16, color: AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: Text(specialty.skillLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(10)),
                child: Text(badgeLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: badgeColor))),
          ]),
          if (specialty.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(specialty.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          if (specialty.isRejected && specialty.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t('specialty_rejected_reason').replaceAll('{reason}', specialty.rejectionReason!),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.dangerDark))),
                ])),
          ],
          if (specialty.diplomaImageUrl != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.workspace_premium_rounded, size: 13, color: AppColors.gold),
              const SizedBox(width: 4),
              Text(t('specialty_diploma_attached'), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _AddSpecialtySheet extends StatefulWidget {
  const _AddSpecialtySheet({required this.existingSpecialties, required this.techId});
  final List<TechnicianSpecialty> existingSpecialties;
  final String techId;
  @override
  State<_AddSpecialtySheet> createState() => _AddSpecialtySheetState();
}

class _AddSpecialtySheetState extends State<_AddSpecialtySheet> {
  final _fs = FirestoreService();
  final _storage = StorageService();
  final _picker = ImagePicker();
  TechnicianSkill? _selectedSkill;
  final _descriptionCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  XFile? _diplomaFile;
  Uint8List? _diplomaBytes;
  bool _saving = false;
  String? _error;

  bool get _canSubmit => _selectedSkill != null && _descriptionCtrl.text.trim().isNotEmpty && _detailsCtrl.text.trim().isNotEmpty;
  Set<String> get _usedSkillIds => widget.existingSpecialties.map((s) => s.skillId).toSet();

  Future<void> _pickDiploma() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() { _diplomaFile = file; _diplomaBytes = bytes; });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final t = context.read<LanguageCubit>().state.t;
    setState(() { _saving = true; _error = null; });
    try {
      String? diplomaUrl;
      if (_diplomaFile != null && _diplomaBytes != null) {
        try {
          diplomaUrl = await _storage.upload(
              path: 'technicians/${widget.techId}/diploma_${_selectedSkill!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
              localPathOrIgnoredOnWeb: _diplomaFile!.path, bytes: _diplomaBytes!, contentType: 'image/jpeg')
              .timeout(const Duration(seconds: 20));
        } catch (_) {}
      }
      final specialty = TechnicianSpecialty(
        skillId: _selectedSkill!.id, skillLabel: _selectedSkill!.label,
        description: _descriptionCtrl.text.trim(), details: _detailsCtrl.text.trim(),
        diplomaImageUrl: diplomaUrl, status: SpecialtyStatus.pending, submittedAt: Timestamp.now(),
      );
      await _fs.addSpecialtyToTechnician(techId: widget.techId, specialty: specialty);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _saving = false; _error = '${context.read<LanguageCubit>().state.t('specialty_error_prefix')}$e'; });
    }
  }

  Future<void> _pickSkill() async {
    final t = context.read<LanguageCubit>().state.t;
    final usedIds = _usedSkillIds;
    final result = await showModalBottomSheet<TechnicianSkill>(
      context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(children: [
          const SizedBox(height: 16),
          Text(t('specialty_pick_sheet_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: TechnicianSkill.all.map((skill) {
              final isUsed = usedIds.contains(skill.id);
              return ListTile(
                dense: true, enabled: !isUsed,
                leading: Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: isUsed ? AppColors.background : AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                    child: Icon(skill.icon, size: 18, color: isUsed ? AppColors.textMuted : AppColors.primary)),
                title: Text(skill.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                    color: isUsed ? AppColors.textMuted : AppColors.textPrimary)),
                subtitle: isUsed ? Text(t('specialty_already_submitted'), style: const TextStyle(fontSize: 11)) : null,
                onTap: isUsed ? null : () => Navigator.pop(ctx, skill),
              );
            }).toList(),
          )),
        ]),
      ),
    );
    if (result != null) setState(() => _selectedSkill = result);
  }

  @override
  void dispose() { _descriptionCtrl.dispose(); _detailsCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text(t('specialty_new_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            Text('${widget.existingSpecialties.length}/3', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 4),
          Text(t('specialty_new_sub'), style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Text(t('specialty_type_label'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickSkill,
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                icon: Icon(_selectedSkill?.icon ?? Icons.handyman_rounded, size: 17),
                label: Text(_selectedSkill == null ? t('specialty_pick_btn') : _selectedSkill!.label),
              )),
          const SizedBox(height: 18),
          Text(t('specialty_description_label'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(controller: _descriptionCtrl, maxLines: 4, onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: t('specialty_description_hint'))),
          const SizedBox(height: 4),
          Text(t('specialty_chars').replaceAll('{n}', '${_descriptionCtrl.text.trim().length}'),
              style: TextStyle(fontSize: 11, color: _descriptionCtrl.text.trim().isNotEmpty ? AppColors.success : AppColors.textMuted)),
          const SizedBox(height: 16),
          Text(t('specialty_details_label'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(t('specialty_details_sub'), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(controller: _detailsCtrl, maxLines: 3, onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: t('specialty_details_hint'))),
          const SizedBox(height: 4),
          Text(t('specialty_chars').replaceAll('{n}', '${_detailsCtrl.text.trim().length}'),
              style: TextStyle(fontSize: 11, color: _detailsCtrl.text.trim().isNotEmpty ? AppColors.success : AppColors.textMuted)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('specialty_diploma_label'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(t('specialty_diploma_sub'), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ])),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _pickDiploma,
              child: Container(width: 72, height: 60,
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _diplomaBytes != null ? AppColors.primary : AppColors.border)),
                  child: _diplomaBytes != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.memory(_diplomaBytes!, fit: BoxFit.cover))
                      : const Icon(Icons.upload_file_rounded, color: AppColors.textMuted, size: 22)),
            ),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.danger)),
          ],
          const SizedBox(height: 22),
          SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: (_canSubmit && !_saving) ? _submit : null,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(t('specialty_submit_btn')),
              )),
        ]),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull { final iter = iterator; return iter.moveNext() ? iter.current : null; }
}