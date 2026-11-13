import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a technician specialty submission.
enum SpecialtyStatus { pending, approved, rejected }

extension SpecialtyStatusX on SpecialtyStatus {
  String get value {
    switch (this) {
      case SpecialtyStatus.pending:
        return 'pending';
      case SpecialtyStatus.approved:
        return 'approved';
      case SpecialtyStatus.rejected:
        return 'rejected';
    }
  }

  static SpecialtyStatus fromString(String? v) {
    switch (v) {
      case 'approved':
        return SpecialtyStatus.approved;
      case 'rejected':
        return SpecialtyStatus.rejected;
      default:
        return SpecialtyStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case SpecialtyStatus.pending:
        return 'En attente';
      case SpecialtyStatus.approved:
        return 'Approuvée';
      case SpecialtyStatus.rejected:
        return 'Refusée';
    }
  }
}

/// A single specialty submitted by a technician.
///
/// IMPORTANT: toMap() uses Timestamp.now() — NOT FieldValue.serverTimestamp().
/// Firestore does NOT support FieldValue.serverTimestamp() inside arrays
/// (it throws [cloud_firestore/invalid-argument]). Timestamp.now() is the
/// correct approach when the value will be stored inside a list field.
class TechnicianSpecialty {
  const TechnicianSpecialty({
    required this.skillId,
    required this.skillLabel,
    required this.description,
    required this.details,
    this.diplomaImageUrl,
    this.status = SpecialtyStatus.pending,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });

  final String skillId;
  final String skillLabel;
  final String description;
  final String details;
  final String? diplomaImageUrl;
  final SpecialtyStatus status;
  final String? rejectionReason;
  final Timestamp? submittedAt;
  final Timestamp? reviewedAt;

  bool get isApproved => status == SpecialtyStatus.approved;
  bool get isPending => status == SpecialtyStatus.pending;
  bool get isRejected => status == SpecialtyStatus.rejected;

  Map<String, dynamic> toMap() => {
        'skillId': skillId,
        'skillLabel': skillLabel,
        'description': description,
        'details': details,
        'diplomaImageUrl': diplomaImageUrl,
        'status': status.value,
        'rejectionReason': rejectionReason,
        // ✅ Timestamp.now() — safe inside Firestore arrays.
        // ❌ FieldValue.serverTimestamp() crashes inside arrays.
        'submittedAt': submittedAt ?? Timestamp.now(),
        'reviewedAt': reviewedAt,
      };

  static TechnicianSpecialty fromMap(Map<String, dynamic> map) {
    return TechnicianSpecialty(
      skillId: map['skillId'] as String? ?? '',
      skillLabel: map['skillLabel'] as String? ?? '',
      description: map['description'] as String? ?? '',
      details: map['details'] as String? ?? '',
      diplomaImageUrl: map['diplomaImageUrl'] as String?,
      status: SpecialtyStatusX.fromString(map['status'] as String?),
      rejectionReason: map['rejectionReason'] as String?,
      submittedAt: map['submittedAt'] as Timestamp?,
      reviewedAt: map['reviewedAt'] as Timestamp?,
    );
  }

  TechnicianSpecialty copyWith({
    String? skillId,
    String? skillLabel,
    String? description,
    String? details,
    String? diplomaImageUrl,
    SpecialtyStatus? status,
    String? rejectionReason,
    Timestamp? submittedAt,
    Timestamp? reviewedAt,
  }) {
    return TechnicianSpecialty(
      skillId: skillId ?? this.skillId,
      skillLabel: skillLabel ?? this.skillLabel,
      description: description ?? this.description,
      details: details ?? this.details,
      diplomaImageUrl: diplomaImageUrl ?? this.diplomaImageUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}