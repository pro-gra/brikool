import 'package:cloud_firestore/cloud_firestore.dart';
import 'technician_specialty.dart';

/// The technician's Firestore document. Two specialty lists coexist:
///
/// • [specialties] — every specialty this technician has submitted,
///   regardless of status (pending / approved / rejected). The app reads
///   this list everywhere:
///     - Clients only see entries whose status == approved.
///     - The technician's own profile shows all entries so they can track
///       what's waiting, what's live, and what was rejected.
///     - Admins see all entries in the approval dashboard.
///
/// • [skills] — kept as a simple String list derived from approved
///   specialties for backwards-compatible request routing (FirestoreService
///   .streamOpenRequestsForSkills still queries this field). It is updated
///   automatically whenever an admin approves or rejects a specialty.
///
/// Max 3 specialties total (all statuses combined). The UI enforces this
/// during submission and the FirestoreService checks it server-side too.
class TechnicianProfile {
  TechnicianProfile({
    required this.techId,
    required this.fullName,
    required this.phone,
    required this.city,
    required this.skills,
    required this.specialties,
    required this.bio,
    required this.yearsExperience,
    required this.hasDiploma,
    required this.diplomaNote,
    this.profilePhotoUrl,
    this.diplomaPhotoUrl,
    this.cinPhotoUrl,
    this.introVideoUrl,
    this.isSuspended = false,
    this.jobsDone = 0,
    this.isBlocked = false,
    this.location,
    this.walletBalance = 0,
    this.isOnline = false,
    this.isVerified = false,
    this.rating = 5.0,
    this.onboardingComplete = false,
    this.cin = '',
    this.age = 0,
    // Legacy field kept for any code that still reads pendingSkills directly.
    this.pendingSkills = const [],
  });

  final String techId;
  final String fullName;
  final String phone;
  final String city;

  /// Derived skill IDs from approved specialties — used for request routing.
  final List<String> skills;

  /// Full structured specialty list (all statuses).
  final List<TechnicianSpecialty> specialties;

  final String bio;
  final int yearsExperience;
  final bool hasDiploma;
  final String diplomaNote;
  final String? profilePhotoUrl;
  final String? diplomaPhotoUrl;
  final String? cinPhotoUrl;
  final String? introVideoUrl;
  final bool isSuspended;
  final int jobsDone;
  final bool isBlocked;
  final GeoPoint? location;
  final double walletBalance;
  final bool isOnline;
  final bool isVerified;
  final double rating;
  final bool onboardingComplete;
  final String cin;
  final int age;

  /// Legacy field — kept for backwards compatibility. New code should
  /// read [specialties] and filter by status instead.
  final List<Map<String, dynamic>> pendingSkills;

  // --------------- convenience getters ---------------

  List<TechnicianSpecialty> get approvedSpecialties =>
      specialties.where((s) => s.isApproved).toList();

  List<TechnicianSpecialty> get pendingSpecialties =>
      specialties.where((s) => s.isPending).toList();

  List<TechnicianSpecialty> get rejectedSpecialties =>
      specialties.where((s) => s.isRejected).toList();

  int get totalSpecialtyCount => specialties.length;

  bool get canAddMoreSpecialties => totalSpecialtyCount < 3;

  // --------------- serialisation ---------------

  Map<String, dynamic> toMap() {
    return {
      'techId': techId,
      'fullName': fullName,
      'phone': phone,
      'city': city,
      'servicesProvided': skills,
      'specialties': specialties.map((s) => s.toMap()).toList(),
      'bio': bio,
      'yearsExperience': yearsExperience,
      'hasDiploma': hasDiploma,
      'diplomaNote': diplomaNote,
      'profilePhotoUrl': profilePhotoUrl,
      'diplomaPhotoUrl': diplomaPhotoUrl,
      'cinPhotoUrl': cinPhotoUrl,
      'introVideoUrl': introVideoUrl,
      'isSuspended': isSuspended,
      'jobsDone': jobsDone,
      'isBlocked': isBlocked,
      'location': location,
      'walletBalance': walletBalance,
      'isOnline': isOnline,
      'isVerified': isVerified,
      'rating': rating,
      'onboardingComplete': onboardingComplete,
      'cin': cin,
      'age': age,
      // Write pendingSkills from pendingSpecialties for admin backwards compat.
      'pendingSkills': pendingSpecialties
          .map((s) => {
                'skillId': s.skillId,
                'description': s.description,
                'diplomaNote': s.details,
                'diplomaPhotoUrl': s.diplomaImageUrl,
              })
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static TechnicianProfile fromMap(String id, Map<String, dynamic> map) {
    // Parse structured specialties list.
    final rawSpecialties =
        (map['specialties'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final specialties =
        rawSpecialties.map(TechnicianSpecialty.fromMap).toList();

    // Derive approved skill IDs from specialties — fall back to legacy
    // servicesProvided field when specialties list is empty (old accounts).
    final derivedSkills = specialties
        .where((s) => s.isApproved)
        .map((s) => s.skillId)
        .toList();
    final legacySkills =
        List<String>.from(map['servicesProvided'] as List? ?? []);
    final skills = derivedSkills.isNotEmpty ? derivedSkills : legacySkills;

    return TechnicianProfile(
      techId: id,
      fullName: map['fullName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      city: map['city'] as String? ?? '',
      skills: skills,
      specialties: specialties,
      bio: map['bio'] as String? ?? '',
      yearsExperience: (map['yearsExperience'] as num?)?.toInt() ?? 0,
      hasDiploma: map['hasDiploma'] as bool? ?? false,
      diplomaNote: map['diplomaNote'] as String? ?? '',
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      diplomaPhotoUrl: map['diplomaPhotoUrl'] as String?,
      cinPhotoUrl: map['cinPhotoUrl'] as String?,
      introVideoUrl: map['introVideoUrl'] as String?,
      isSuspended: map['isSuspended'] as bool? ?? false,
      jobsDone: (map['jobsDone'] as num?)?.toInt() ?? 0,
      isBlocked: map['isBlocked'] as bool? ?? false,
      location: map['location'] as GeoPoint?,
      walletBalance: (map['walletBalance'] as num?)?.toDouble() ?? 0,
      isOnline: map['isOnline'] as bool? ?? false,
      isVerified: map['isVerified'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      onboardingComplete: map['onboardingComplete'] as bool? ?? false,
      cin: map['cin'] as String? ?? '',
      age: (map['age'] as num?)?.toInt() ?? 0,
      pendingSkills:
          (map['pendingSkills'] as List?)?.cast<Map<String, dynamic>>() ??
              const [],
    );
  }
}