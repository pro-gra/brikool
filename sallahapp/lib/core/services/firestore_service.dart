import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/technician_profile.dart';
import '../../models/technician_specialty.dart';
import '../../models/company_profile.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _requests => _db.collection('requests');
  CollectionReference<Map<String, dynamic>> get _technicians => _db.collection('technicians');
  CollectionReference<Map<String, dynamic>> get _walletTxns => _db.collection('wallet_transactions');

  static const List<String> activeStatuses = ['pending', 'accepted', 'en_route', 'in_progress'];
  static const double commissionRate = 0.0;
  static const double companyCommissionRate = 0.08;
  static const double minBalanceToGoOnline = 50;
  static const double lowBalanceBlockThreshold = 10;

  // ---------------------------------------------------------------
  // Users / profile
  // ---------------------------------------------------------------

  Future<void> ensureUserProfile(User user, {required String preferredLang}) async {
    final ref = _users.doc(user.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) return;
    await ref.set({
      'uid': user.uid,
      'phone': user.phoneNumber,
      'fullName': '',
      'city': '',
      'photoUrl': null,
      'referralSource': null,
      'clientOnboardingComplete': false,
      'preferredLang': preferredLang,
      'role': null,
      'createdAt': FieldValue.serverTimestamp(),
      'rating': 5.0,
    });
  }

  Future<void> setUserRole(String uid, String role) {
    return _users.doc(uid).set({'role': role}, SetOptions(merge: true));
  }

  Stream<String?> streamUserRole(String uid) {
    return _users.doc(uid).snapshots().map((doc) => doc.data()?['role'] as String?);
  }

  Stream<Map<String, dynamic>?> streamUserProfile(String uid) {
    return _users.doc(uid).snapshots().map((doc) => doc.data());
  }
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
  final doc = await _users.doc(uid).get();
  return doc.data();
  }

  Future<void> updateUserProfile(
    String uid, {
    String? fullName,
    String? city,
    String? photoUrl,
    String? referralSource,
    bool? clientOnboardingComplete,
  }) {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['fullName'] = fullName;
    if (city != null) updates['city'] = city;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (referralSource != null) updates['referralSource'] = referralSource;
    if (clientOnboardingComplete != null) {
      updates['clientOnboardingComplete'] = clientOnboardingComplete;
    }
    return _users.doc(uid).set(updates, SetOptions(merge: true));
  }

  Future<void> addUserAddress({
    required String uid,
    required String label,
    required double lat,
    required double lng,
    String details = '',
  }) {
    return _users.doc(uid).update({
      'addresses': FieldValue.arrayUnion([
        {'label': label, 'lat': lat, 'lng': lng, 'details': details}
      ]),
    });
  }

  Future<void> removeUserAddress(String uid, Map<String, dynamic> address) {
    return _users.doc(uid).update({
      'addresses': FieldValue.arrayRemove([address]),
    });
  }

  Future<void> toggleFavoriteTech(String uid, String techId, bool favorite) {
    return _users.doc(uid).update({
      'favoriteTechIds': favorite
          ? FieldValue.arrayUnion([techId])
          : FieldValue.arrayRemove([techId]),
    });
  }

  // ---------------------------------------------------------------
  // DELETE ACCOUNT
  // ---------------------------------------------------------------

  Future<void> requestAccountDeletion({
    required String uid,
    required String reason,
    required String userType,
  }) {
    return _db.collection('deletion_requests').doc(uid).set({
      'uid': uid,
      'userType': userType,
      'reason': reason,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelDeletionRequest(String uid) {
    return _db.collection('deletion_requests').doc(uid).delete();
  }

  Stream<Map<String, dynamic>?> streamDeletionRequest(String uid) {
    return _db
        .collection('deletion_requests')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists ? d.data() : null);
  }

Future<void> adminConfirmDeletion(String uid) async {
  final batch = _db.batch();
  batch.delete(_db.collection('deletion_requests').doc(uid));
  batch.delete(_users.doc(uid));
  batch.delete(_technicians.doc(uid));
  await batch.commit();
}

  Stream<List<Map<String, dynamic>>> streamPendingDeletionRequests() {
    return _db
        .collection('deletion_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {...d.data(), 'uid': d.id}).toList());
  }

  // ---------------------------------------------------------------
  // Technician profile & wallet
  // ---------------------------------------------------------------

  Future<void> saveTechnicianProfile(TechnicianProfile profile) {
    return _technicians.doc(profile.techId).set(profile.toMap(), SetOptions(merge: true));
  }

Stream<TechnicianProfile?> streamTechnicianProfile(String techId) {
  return _technicians.doc(techId).snapshots().map((doc) {
    if (!doc.exists) return null;
    return TechnicianProfile.fromMap(doc.id, doc.data()!);
  });
}

Future<TechnicianProfile?> getTechnicianProfile(String techId) async {
  final doc = await _technicians.doc(techId).get();
  if (!doc.exists) return null;
  return TechnicianProfile.fromMap(doc.id, doc.data()!);
}

  Future<void> setTechnicianOnline(String techId, bool isOnline) {
    return _technicians.doc(techId).update({'isOnline': isOnline});
  }

  Future<void> depositToWallet(
      {required String techId, required double amountMad, required String method}) async {
    final techRef = _technicians.doc(techId);
    final txnId = 'txn_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final batch = _db.batch();
    batch.set(techRef, {'walletBalance': FieldValue.increment(amountMad)}, SetOptions(merge: true));
    batch.set(_walletTxns.doc(txnId), {
      'txnId': txnId,
      'techId': techId,
      'amountMAD': amountMad,
      'type': 'topup',
      'description': 'Top-up via $method',
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> streamWalletTransactions(String techId) {
    return _walletTxns.where('techId', isEqualTo: techId).snapshots().map((snap) {
      final list = snap.docs.map((d) => d.data()).toList();
      list.sort((a, b) {
        final ta = a['timestamp'];
        final tb = b['timestamp'];
        if (ta is! Timestamp) return -1;
        if (tb is! Timestamp) return 1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  // ---------------------------------------------------------------
  // Requests — client side
  // ---------------------------------------------------------------

  Future<Map<String, dynamic>?> getActiveRequestForClient(String clientId) async {
    final snap = await _requests.where('clientId', isEqualTo: clientId).get();
    for (final doc in snap.docs) {
      final status = doc.data()['status'] as String? ?? '';
      if (activeStatuses.contains(status)) {
        return {...doc.data(), 'requestId': doc.id};
      }
    }
    return null;
  }

  Stream<Map<String, dynamic>?> streamActiveRequestForClient(String clientId) {
    return _requests.where('clientId', isEqualTo: clientId).snapshots().map((snap) {
      for (final doc in snap.docs) {
        final status = doc.data()['status'] as String? ?? '';
        if (activeStatuses.contains(status)) {
          return {...doc.data(), 'requestId': doc.id};
        }
      }
      return null;
    });
  }

  Stream<List<Map<String, dynamic>>> streamClientRequests(String clientId) {
    return _requests.where('clientId', isEqualTo: clientId).snapshots().map((snap) {
      final list = snap.docs.map((d) => {...d.data(), 'requestId': d.id}).toList();
      list.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Future<String> createRequest({
    required String clientId,
    required String clientName,
    required String skillId,
    required String serviceLabel,
    required double budgetMad,
    required String description,
    required double clientLat,
    required double clientLng,
    DateTime? scheduledAt,
    String? preferredTechId,
    String? promoCode,
    double discountMad = 0,
  }) async {
    if (scheduledAt == null) {
      final existing = await getActiveRequestForClient(clientId);
      if (existing != null) {
        throw StateError('active_order_exists');
      }
    }
    final otp = (1000 + Random().nextInt(8999)).toString();
    final doc = await _requests.add({
      'clientId': clientId,
      'clientName': clientName,
      'techId': null,
      'serviceType': 'sos_$skillId',
      'serviceLabel': serviceLabel,
      'description': description,
      'status': 'pending',
      'budgetMAD': budgetMad,
      'priceQuoteMAD': budgetMad,
      'commissionMAD': double.parse((budgetMad * commissionRate).toStringAsFixed(2)),
      'clientLocation': GeoPoint(clientLat, clientLng),
      'otpCode': otp,
      'clientRating': null,
      'clientReview': null,
      'mediaUrls': <String>[],
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt) : null,
      'preferredTechId': preferredTechId,
      'promoCode': promoCode,
      'discountMAD': discountMad,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> attachMediaToRequest(String requestId, List<String> urls) {
    return _requests.doc(requestId).update({'mediaUrls': urls});
  }

  Future<Map<String, dynamic>> validatePromoCode(String code) async {
    final doc = await _db.collection('promo_codes').doc(code.trim().toUpperCase()).get();
    final data = doc.data();
    if (data == null || data['active'] != true) {
      throw Exception('Code promo invalide ou expiré');
    }
    return {
      'code': doc.id,
      'amountMAD': (data['amountMAD'] as num?)?.toDouble() ?? 0,
    };
  }

  Future<void> increaseRequestPrice(String requestId, double newBudgetMad) {
    return _requests.doc(requestId).update({
      'budgetMAD': newBudgetMad,
      'priceQuoteMAD': newBudgetMad,
      'commissionMAD': double.parse((newBudgetMad * commissionRate).toStringAsFixed(2)),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRequest(String requestId) {
    return _requests.doc(requestId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamTechnician(String techId) {
    return _technicians.doc(techId).snapshots();
  }

  Future<void> cancelRequest(String requestId) {
    return _requests.doc(requestId).update({'status': 'cancelled'});
  }

  Future<void> rateCompletedRequest({
    required String requestId,
    required String techId,
    required int stars,
    String comment = '',
  }) async {
    assert(stars >= 1 && stars <= 5);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String clientName = '';
    if (uid != null) {
      try {
        final userDoc = await _users.doc(uid).get();
        clientName = userDoc.data()?['fullName'] as String? ?? '';
      } catch (_) {}
    }
    final batch = _db.batch();
    batch.update(_requests.doc(requestId), {
      'clientRating': stars,
      'clientReview': comment,
    });
    batch.set(
      _technicians.doc(techId).collection('reviews').doc(requestId),
      {
        'stars': stars,
        'comment': comment,
        'clientName': clientName.isEmpty ? 'Client Sallah' : clientName,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  Future<void> addJournalPhoto({
    required String requestId,
    required String url,
    required String phase,
  }) {
    return _requests.doc(requestId).update({
      'journal': FieldValue.arrayUnion([
        {'url': url, 'phase': phase, 'at': Timestamp.now()}
      ]),
    });
  }

  Future<void> awardClientCredit(String uid, double amountMad) {
    return _users.doc(uid).set(
        {'creditMAD': FieldValue.increment(amountMad)}, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> streamCityLeaderboard(String city) {
    return _technicians.where('city', isEqualTo: city).snapshots().map((snap) {
      final list = snap.docs.map((d) => {...d.data(), 'techId': d.id}).toList();
      list.sort((a, b) {
        final ja = (a['jobsDone'] as num?)?.toInt() ?? 0;
        final jb = (b['jobsDone'] as num?)?.toInt() ?? 0;
        if (jb != ja) return jb.compareTo(ja);
        final ra = (a['rating'] as num?)?.toDouble() ?? 0;
        final rb = (b['rating'] as num?)?.toDouble() ?? 0;
        return rb.compareTo(ra);
      });
      return list.take(10).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> streamTechnicianReviews(String techId) {
    return _technicians.doc(techId).collection('reviews').snapshots().map((snap) {
      final list = snap.docs.map((d) => d.data()).toList();
      list.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  // ---------------------------------------------------------------
  // Offers
  // ---------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _offers(String requestId) =>
      _requests.doc(requestId).collection('offers');

  static const double maxTransportFeeMad = 20;

  Future<void> makeOffer({
    required String requestId,
    required String techId,
    required String techName,
    required double techRating,
    required double priceMad,
    double transportFeeMad = 0,
  }) {
    final safeTransportFee = transportFeeMad.clamp(0, maxTransportFeeMad);
    return _offers(requestId).doc(techId).set({
      'techId': techId,
      'techName': techName,
      'techRating': techRating,
      'priceMAD': priceMad,
      'transportFeeMAD': safeTransportFee,
      'status': 'proposed',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamOffers(String requestId) {
    return _offers(requestId).snapshots().map((snap) {
      final list = snap.docs.map((d) => {...d.data(), 'offerId': d.id}).toList();
      list.sort((a, b) {
        final pa = (a['priceMAD'] as num?)?.toDouble() ?? 0;
        final pb = (b['priceMAD'] as num?)?.toDouble() ?? 0;
        return pa.compareTo(pb);
      });
      return list;
    });
  }

  Future<void> rejectOffer(String requestId, String offerId) {
    return _offers(requestId).doc(offerId).update({'status': 'rejected'});
  }

  Future<void> acceptOffer({
    required String requestId,
    required String offerId,
    required String techId,
    required double priceMad,
    double transportFeeMad = 0,
  }) async {
    final requestRef = _requests.doc(requestId);
    final safeTransportFee = transportFeeMad.clamp(0, maxTransportFeeMad);
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(requestRef);
      if (!snap.exists || snap.data()!['status'] != 'pending') {
        throw Exception('Cette demande n\'est plus disponible.');
      }
      transaction.update(requestRef, {
        'techId': techId,
        'priceQuoteMAD': priceMad,
        'transportFeeMAD': safeTransportFee,
        'commissionMAD': double.parse((priceMad * commissionRate).toStringAsFixed(2)),
        'status': 'accepted',
      });
      transaction.update(_offers(requestId).doc(offerId), {'status': 'accepted'});
    });
  }

  // ---------------------------------------------------------------
  // Requests — technician side
  // ---------------------------------------------------------------

  Stream<List<Map<String, dynamic>>> streamOpenRequestsForSkills(List<String> skills) {
    return _requests.where('status', isEqualTo: 'pending').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => {...d.data(), 'requestId': d.id})
          .where((r) => skills.any((s) => (r['serviceType'] as String? ?? '') == 'sos_$s'))
          .toList();
      list.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Stream<Map<String, dynamic>?> streamActiveJobForTechnician(String techId) {
    return _requests.where('techId', isEqualTo: techId).snapshots().map((snap) {
      for (final doc in snap.docs) {
        final status = doc.data()['status'] as String? ?? '';
        if (['accepted', 'en_route', 'in_progress'].contains(status)) {
          return {...doc.data(), 'requestId': doc.id};
        }
      }
      return null;
    });
  }

  Stream<List<Map<String, dynamic>>> streamTechnicianRequests(String techId) {
    return _requests.where('techId', isEqualTo: techId).snapshots().map((snap) {
      final list = snap.docs.map((d) => {...d.data(), 'requestId': d.id}).toList();
      list.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Future<void> updateTechnicianFields(String techId, Map<String, dynamic> fields) {
    return _technicians.doc(techId).set(fields, SetOptions(merge: true));
  }

  Future<void> techAcceptAtBudget({
    required String requestId,
    required String techId,
    double transportFeeMad = 0,
  }) async {
    final activeJob = await streamActiveJobForTechnician(techId).first;
    if (activeJob != null) {
      throw Exception('Vous avez déjà une commande en cours. Terminez-la avant d\'en accepter une autre.');
    }
    final requestRef = _requests.doc(requestId);
    final techRef = _technicians.doc(techId);
    final safeTransportFee = transportFeeMad.clamp(0, maxTransportFeeMad);
    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      final techSnap = await transaction.get(techRef);
      if (!requestSnap.exists || requestSnap.data()!['status'] != 'pending') {
        throw Exception('Cette demande n\'est plus disponible.');
      }
      final budget = (requestSnap.data()!['budgetMAD'] as num).toDouble();
      transaction.update(requestRef, {
        'techId': techId,
        'priceQuoteMAD': budget,
        'transportFeeMAD': safeTransportFee,
        'commissionMAD': 0,
        'status': 'accepted',
      });
    });
  }

  Future<void> techGoEnRoute({required String requestId, required String techId}) async {
    final requestRef = _requests.doc(requestId);
    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists || requestSnap.data()!['status'] != 'accepted') {
        throw Exception('Statut de la demande invalide.');
      }
      // Technician wallet and commission deductions are paused for launch.
      transaction.update(requestRef, {
        'status': 'en_route',
        'commissionMAD': 0,
      });
    });
  }

  Future<void> startJobWithOtp(String requestId, String enteredOtp) async {
    final doc = await _requests.doc(requestId).get();
    if (doc.data()?['otpCode'] != enteredOtp) {
      throw Exception('Code OTP incorrect');
    }
    await _requests.doc(requestId).update({'status': 'in_progress'});
  }

  Future<void> completeJob(String requestId, String techId) async {
    final batch = _db.batch();
    batch.update(_requests.doc(requestId), {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_technicians.doc(techId),
        {'jobsDone': FieldValue.increment(1)}, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> addJournalEntry({
    required String requestId,
    required String url,
    required String label,
  }) {
    return _requests.doc(requestId).update({
      'journal': FieldValue.arrayUnion([
        {'url': url, 'label': label, 'at': Timestamp.now()}
      ]),
    });
  }

  Future<void> addClientCredit(String uid, double amountMad) {
    return _users.doc(uid).set(
        {'creditMAD': FieldValue.increment(amountMad)}, SetOptions(merge: true));
  }

  Stream<List<TechnicianProfile>> streamTopTechnicians(String city, {int limit = 10}) {
    return _technicians.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => TechnicianProfile.fromMap(d.id, d.data()))
          .where((t) =>
              t.onboardingComplete &&
              (city.isEmpty || t.city.toLowerCase() == city.toLowerCase()))
          .toList();
      list.sort((a, b) {
        final byJobs = (b.jobsDone).compareTo(a.jobsDone);
        if (byJobs != 0) return byJobs;
        return b.rating.compareTo(a.rating);
      });
      return list.take(limit).toList();
    });
  }

  // ---------------------------------------------------------------
  // Companies
  // ---------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _companies => _db.collection('companies');

  Stream<List<CompanyProfile>> streamCompanies({String? categoryId, String? preferredCity}) {
    return _companies.where('isActive', isEqualTo: true).snapshots().map((snap) {
      var list = snap.docs.map((d) => CompanyProfile.fromMap(d.id, d.data())).toList();
      if (categoryId != null) {
        list = list.where((c) => c.categories.contains(categoryId)).toList();
      }
      list.sort((a, b) {
        if (preferredCity != null && preferredCity.isNotEmpty) {
          final aMatch = a.city.toLowerCase() == preferredCity.toLowerCase();
          final bMatch = b.city.toLowerCase() == preferredCity.toLowerCase();
          if (aMatch != bMatch) return aMatch ? -1 : 1;
        }
        if (a.isVerified != b.isVerified) return a.isVerified ? -1 : 1;
        return b.rating.compareTo(a.rating);
      });
      return list;
    });
  }

  Stream<CompanyProfile?> streamCompany(String companyId) {
    return _companies.doc(companyId).snapshots().map(
        (d) => d.exists ? CompanyProfile.fromMap(d.id, d.data()!) : null);
  }

  Future<void> saveMyCompanyProfile(CompanyProfile company) {
    return _companies.doc(company.companyId).set(company.toMap(), SetOptions(merge: true));
  }

  Future<void> adminSaveCompany(CompanyProfile company) {
    return _companies.doc(company.companyId).set(
        company.toMap()..['updatedAt'] = FieldValue.serverTimestamp(),
        SetOptions(merge: true));
  }

  Future<void> adminSetCompanyActive(String companyId, bool active) {
    return _companies.doc(companyId).update({'isActive': active});
  }

  Future<void> adminDeleteCompany(String companyId) {
    return _companies.doc(companyId).delete();
  }

  Future<void> submitCompanyQuoteRequest({
    required String companyId,
    required String companyName,
    required String clientId,
    required String clientName,
    required String clientPhone,
    required String categoryId,
    required String description,
    required DateTime preferredDate,
    required String preferredTime,
    required String address,
    List<String> mediaUrls = const [],
    String city = '',
  }) {
    return _db.collection('company_quote_requests').add({
      'companyId': companyId,
      'companyName': companyName,
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'categoryId': categoryId,
      'description': description,
      'preferredDate': Timestamp.fromDate(preferredDate),
      'preferredTime': preferredTime,
      'address': address,
      'mediaUrls': mediaUrls,
      'city': city,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamQuoteRequestsForCompany(String companyId) {
    return _db.collection('company_quote_requests')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => {...d.data(), '_id': d.id}).toList();
      list.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> streamMyQuoteRequests(String clientId) {
    return _db.collection('company_quote_requests')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => {...d.data(), '_id': d.id}).toList();
      list.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Future<({String companyName, String status})?> findActiveRequestForCategory(
      String clientId, String categoryId) async {
    final snap = await _db
        .collection('company_quote_requests')
        .where('clientId', isEqualTo: clientId)
        .where('categoryId', isEqualTo: categoryId)
        .get();
    for (final doc in snap.docs) {
      final status = doc.data()['status'] as String? ?? 'new';
      if (!['completed', 'declined'].contains(status)) {
        return (
          companyName: doc.data()['companyName'] as String? ?? 'une entreprise',
          status: status,
        );
      }
    }
    return null;
  }

  Stream<Map<String, dynamic>?> streamQuoteRequest(String requestId) {
    return _db.collection('company_quote_requests').doc(requestId).snapshots().map(
        (d) => d.exists ? {...d.data()!, '_id': d.id} : null);
  }

  Stream<List<Map<String, dynamic>>> streamAllQuoteRequests() {
    return _db.collection('company_quote_requests').snapshots().map((snap) {
      final list = snap.docs.map((d) => {...d.data(), '_id': d.id}).toList();
      list.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Future<void> adminUpdateQuoteRequestStatus(String requestId, String status) {
    return _db.collection('company_quote_requests').doc(requestId).update({'status': status});
  }

  Future<void> companySendQuote({
    required String requestId,
    required double priceMAD,
    required String notes,
    required bool materialsIncluded,
    required double durationValue,
    required String durationUnit,
    int teamSize = 0,
    double depositPercent = 0,
    int warrantyMonths = 0,
    int validityDays = 7,
    List<Map<String, dynamic>> lineItems = const [],
    DateTime? confirmedDate,
    String? confirmedTime,
  }) {
    return _db.collection('company_quote_requests').doc(requestId).update({
      'status': 'quoted',
      'quotedPriceMAD': priceMAD,
      'quotedNotes': notes,
      'materialsIncluded': materialsIncluded,
      'durationValue': durationValue,
      'durationUnit': durationUnit,
      'teamSize': teamSize,
      'depositPercent': depositPercent,
      'warrantyMonths': warrantyMonths,
      'validityDays': validityDays,
      'lineItems': lineItems,
      if (confirmedDate != null) 'preferredDate': Timestamp.fromDate(confirmedDate),
      if (confirmedTime != null) 'preferredTime': confirmedTime,
      'quotedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clientConfirmQuote(String requestId) {
    final otp = (1000 + Random().nextInt(8999)).toString();
    return _db.collection('company_quote_requests').doc(requestId).update({
      'status': 'confirmed',
      'otpCode': otp,
      'clientConfirmedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clientDeclineQuote(String requestId) {
    return _db.collection('company_quote_requests').doc(requestId).update({'status': 'declined'});
  }

  Future<void> companyStartWithOtp(String requestId, String enteredOtp) async {
    final requestRef = _db.collection('company_quote_requests').doc(requestId);
    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) throw Exception('Demande introuvable.');
      final data = requestSnap.data()!;
      if (data['otpCode'] != enteredOtp) throw Exception('Code OTP incorrect');
      if (data['status'] != 'confirmed') throw Exception('Statut de la demande invalide.');
      final companyId = data['companyId'] as String;
      final companyDocRef = _companies.doc(companyId);
      final companySnap = await transaction.get(companyDocRef);
      final price = (data['quotedPriceMAD'] as num?)?.toDouble() ?? 0;
      final commission = double.parse((price * companyCommissionRate).toStringAsFixed(2));
      final balance = (companySnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
      if (balance < commission) throw Exception('Solde insuffisant pour couvrir la commission.');
      final newBalance = double.parse((balance - commission).toStringAsFixed(2));
      transaction.update(requestRef, {
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'commissionMAD': commission,
      });
      transaction.update(companyDocRef, {'walletBalance': newBalance});
      final txnId = 'txn_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      transaction.set(_walletTxns.doc(txnId), {
        'txnId': txnId,
        'companyId': companyId,
        'amountMAD': commission,
        'type': 'commission_deduction',
        'description': 'Commission for project $requestId',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> companyDepositToWallet(
      {required String companyId, required double amountMad, required String method}) async {
    final companyRef = _companies.doc(companyId);
    final txnId = 'txn_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final batch = _db.batch();
    batch.set(companyRef, {'walletBalance': FieldValue.increment(amountMad)}, SetOptions(merge: true));
    batch.set(_walletTxns.doc(txnId), {
      'txnId': txnId,
      'companyId': companyId,
      'amountMAD': amountMad,
      'type': 'topup',
      'description': 'Top-up via $method',
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> streamCompanyWalletTransactions(String companyId) {
    return _walletTxns.where('companyId', isEqualTo: companyId).snapshots().map((snap) {
      final list = snap.docs.map((d) => d.data()).toList();
      list.sort((a, b) {
        final ta = a['timestamp'];
        final tb = b['timestamp'];
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  CollectionReference<Map<String, dynamic>> _companyMessages(String requestId) =>
      _db.collection('company_quote_requests').doc(requestId).collection('messages');

  Future<void> sendCompanyMessage({
    required String requestId,
    required String senderId,
    required String type,
    String? text,
    String? mediaUrl,
  }) async {
    final batch = _db.batch();
    batch.set(_companyMessages(requestId).doc(), {
      'senderId': senderId,
      'type': type,
      'text': text,
      'mediaUrl': mediaUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('company_quote_requests').doc(requestId), {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': type == 'image' ? '📷 Photo' : (text ?? ''),
      'lastMessageSenderId': senderId,
    });
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> streamCompanyMessages(String requestId) {
    return _companyMessages(requestId).orderBy('createdAt').snapshots().map(
          (snap) => snap.docs.map((d) => {...d.data(), 'messageId': d.id}).toList(),
        );
  }

  Future<void> markCompanyChatRead(String requestId, String uid) async {
    try {
      final ref = _db.collection('company_quote_requests').doc(requestId);
      final doc = await ref.get();
      final data = doc.data();
      if (data == null) return;
      final field = data['clientId'] == uid ? 'clientLastReadAt' : 'companyLastReadAt';
      await ref.update({field: FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  Future<void> companyCompleteProject({required String requestId}) {
    return _db.collection('company_quote_requests').doc(requestId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> attachInvoice({
    required String requestId,
    required String invoiceId,
    required String invoiceUrl,
  }) {
    return _db.collection('company_quote_requests').doc(requestId).update({
      'invoiceId': invoiceId,
      'invoiceUrl': invoiceUrl,
    });
  }

  Future<void> attachQuoteDocument({
    required String requestId,
    required String quoteDocumentId,
    required String quoteDocumentUrl,
  }) {
    return _db.collection('company_quote_requests').doc(requestId).update({
      'quoteDocumentId': quoteDocumentId,
      'quoteDocumentUrl': quoteDocumentUrl,
    });
  }

  Future<void> submitCompanyReview({
    required String companyId,
    required String requestId,
    required String clientId,
    required String clientName,
    required int stars,
    String reviewText = '',
  }) async {
    final companyRef = _companies.doc(companyId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(companyRef);
      final data = snap.data() ?? {};
      final currentRating = (data['rating'] as num?)?.toDouble() ?? 5.0;
      final currentCount = (data['reviewCount'] as num?)?.toInt() ?? 0;
      final newCount = currentCount + 1;
      final newRating = ((currentRating * currentCount) + stars) / newCount;
      txn.update(companyRef, {
        'rating': double.parse(newRating.toStringAsFixed(2)),
        'reviewCount': newCount,
      });
    });
    await companyRef.collection('reviews').add({
      'clientId': clientId,
      'clientName': clientName,
      'requestId': requestId,
      'stars': stars,
      'reviewText': reviewText,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('company_quote_requests').doc(requestId).update({'clientRated': true});
  }

  Future<void> companyUpdateQuoteRequestStatus(String requestId, String status) {
    return _db.collection('company_quote_requests').doc(requestId).update({'status': status});
  }

  // ---------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------

  Future<void> submitReport({
    required String requestId,
    required String clientId,
    required String techId,
    required String reason,
    String comment = '',
    bool urgent = false,
  }) {
    return _db.collection('reports').add({
      'requestId': requestId,
      'clientId': clientId,
      'techId': techId,
      'reason': reason,
      'comment': comment,
      'urgent': urgent,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<bool> streamHasReport(String requestId, String uid, {bool urgentOnly = false}) {
    return _db.collection('reports')
        .where('clientId', isEqualTo: uid)
        .where('requestId', isEqualTo: requestId)
        .where('urgent', isEqualTo: urgentOnly)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty);
  }

  Stream<bool> streamTechHasReport(String requestId, String techUid, {bool urgentOnly = true}) {
    return _db.collection('reports')
        .where('techId', isEqualTo: techUid)
        .where('requestId', isEqualTo: requestId)
        .where('urgent', isEqualTo: urgentOnly)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty);
  }

  Stream<List<Map<String, dynamic>>> streamAllReports() {
    return _db.collection('reports').snapshots().map((snap) {
      final list = snap.docs.map((d) => {...d.data(), '_reportId': d.id}).toList();
      list.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Future<void> resolveReport(String reportId) {
    return _db.collection('reports').doc(reportId).update({'status': 'resolved'});
  }

  // ---------------------------------------------------------------
  // ADMIN
  // ---------------------------------------------------------------

  Stream<bool> streamIsAdmin(String uid) {
    return _db.collection('admins').doc(uid).snapshots().map((d) => d.exists);
  }

  Stream<List<Map<String, dynamic>>> streamAllRequests() {
    return _requests.snapshots().map((snap) {
      final list = snap.docs.map((d) => {...d.data(), 'requestId': d.id}).toList();
      list.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Stream<List<TechnicianProfile>> streamAllTechnicians() {
    return _technicians.snapshots().map((snap) =>
        snap.docs.map((d) => TechnicianProfile.fromMap(d.id, d.data())).toList());
  }

  Stream<List<Map<String, dynamic>>> streamAllUsers() {
    return _users.snapshots().map(
        (snap) => snap.docs.map((d) => {...d.data(), 'uid': d.id}).toList());
  }

  Stream<List<TechnicianProfile>> streamPendingVerifications() {
    return streamAllTechnicians().map((list) =>
        list.where((t) => t.onboardingComplete && !t.isVerified).toList());
  }

  Future<void> adminSetVerified(String techId, bool verified) {
    return _technicians.doc(techId).update({'isVerified': verified});
  }

  Future<void> adminSetSuspended(String techId, bool suspended) {
    return _technicians.doc(techId).update({
      'isSuspended': suspended,
      if (suspended) 'isOnline': false,
    });
  }

  Future<void> adminRejectCin(String techId) {
    return _technicians.doc(techId).update({'cinPhotoUrl': null});
  }

Future<void> adminAdjustWallet(
    {required String techId, required double amountMad, required String note}) async {
  final batch = _db.batch();
  
  // update بدل set+merge
  batch.update(_technicians.doc(techId), {
    'walletBalance': FieldValue.increment(amountMad),
  });
  
  final txnId = 'txn_admin_${DateTime.now().millisecondsSinceEpoch}';
  batch.set(_walletTxns.doc(txnId), {
    'txnId': txnId,
    'techId': techId,
    'amountMAD': amountMad.abs(),
    'type': amountMad >= 0 ? 'admin_credit' : 'admin_debit',
    'note': note,
    'createdAt': FieldValue.serverTimestamp(),  // ← كان timestamp، صار createdAt
  });
  
  await batch.commit();
}

  Future<void> adminCancelRequest(String requestId) {
    return _requests.doc(requestId).update({'status': 'cancelled'});
  }

  Stream<List<Map<String, dynamic>>> streamPromoCodes() {
    return _db.collection('promo_codes').snapshots().map(
        (snap) => snap.docs.map((d) => {...d.data(), 'code': d.id}).toList());
  }

  Future<void> adminUpsertPromo(
      {required String code, required double amountMad, required bool active}) {
    return _db.collection('promo_codes').doc(code.trim().toUpperCase()).set({
      'amountMAD': amountMad,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> adminDeletePromo(String code) {
    return _db.collection('promo_codes').doc(code).delete();
  }

  // ---------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _messages(String requestId) =>
      _requests.doc(requestId).collection('messages');

  Future<void> sendMessage({
    required String requestId,
    required String senderId,
    required String type,
    String? text,
    String? mediaUrl,
    double? lat,
    double? lng,
    int? duration,
  }) async {
    final batch = _db.batch();
    batch.set(_messages(requestId).doc(), {
      'senderId': senderId,
      'type': type,
      'text': text,
      'mediaUrl': mediaUrl,
      'lat': lat,
      'lng': lng,
      if (duration != null) 'audioDuration': duration,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_requests.doc(requestId), {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': switch (type) {
        'image' => '📷 Photo',
        'video' => '🎬 Vidéo',
        'location' => '📍 Position',
        'audio' => '🎤 Vocal',
        _ => text ?? '',
      },
      'lastMessageSenderId': senderId,
    });
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> streamMessages(String requestId) {
    return _messages(requestId).orderBy('createdAt').snapshots().map(
          (snap) => snap.docs.map((d) => {...d.data(), 'messageId': d.id}).toList(),
        );
  }

  Future<void> markChatRead(String requestId, String uid) async {
    try {
      final doc = await _requests.doc(requestId).get();
      final data = doc.data();
      if (data == null) return;
      final field = data['clientId'] == uid ? 'clientLastReadAt' : 'techLastReadAt';
      await _requests.doc(requestId).update({field: FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  Stream<List<Map<String, dynamic>>> streamChatsForClient(String clientId) {
    return _requests.where('clientId', isEqualTo: clientId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => {...d.data(), 'requestId': d.id})
          .where((r) => r['techId'] != null && r['clientHiddenAt'] == null)
          .toList();
      list.sort((a, b) {
        final ta = (a['lastMessageAt'] ?? a['createdAt']);
        final tb = (b['lastMessageAt'] ?? b['createdAt']);
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Future<void> hideChatForClient(String requestId) {
    return _requests.doc(requestId).update({'clientHiddenAt': FieldValue.serverTimestamp()});
  }

  Future<void> hideChatForTechnician(String requestId) {
    return _requests.doc(requestId).update({'techHiddenAt': FieldValue.serverTimestamp()});
  }

  static bool hasUnread(Map<String, dynamic> requestData, String uid) {
    final lastAt = requestData['lastMessageAt'];
    if (lastAt is! Timestamp) return false;
    if (requestData['lastMessageSenderId'] == uid) return false;
    final readField = requestData['clientId'] == uid ? 'clientLastReadAt' : 'techLastReadAt';
    final readAt = requestData[readField];
    if (readAt is! Timestamp) return true;
    return lastAt.compareTo(readAt) > 0;
  }

  // ---------------------------------------------------------------
  // Specialties
  // ---------------------------------------------------------------

  Future<void> addSpecialtyToTechnician({
    required String techId,
    required TechnicianSpecialty specialty,
  }) async {
    final doc = await _technicians.doc(techId).get();
    final data = doc.data() ?? {};
    final rawSpecialties =
        (data['specialties'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (rawSpecialties.length >= 3) {
      throw Exception('Limite de 3 spécialités atteinte. Vous ne pouvez pas en ajouter davantage.');
    }
    final alreadyExists = rawSpecialties.any((s) => s['skillId'] == specialty.skillId);
    if (alreadyExists) {
      throw Exception('Vous avez déjà soumis une spécialité pour "${specialty.skillLabel}".');
    }
    final updated = [...rawSpecialties, specialty.toMap()];
    final legacyPending = updated
        .where((s) => s['status'] == 'pending')
        .map((s) => {
              'skillId': s['skillId'],
              'description': s['description'],
              'diplomaNote': s['details'],
              'diplomaPhotoUrl': s['diplomaImageUrl'],
            })
        .toList();
    await _technicians.doc(techId).update({
      'specialties': updated,
      'pendingSkills': legacyPending,
    });
  }

  Future<void> adminApproveSpecialtyV2({
    required String techId,
    required String skillId,
  }) async {
    final doc = await _technicians.doc(techId).get();
    final data = doc.data();
    if (data == null) return;
    final rawSpecialties =
        (data['specialties'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final updated = rawSpecialties.map((s) {
      if (s['skillId'] != skillId) return s;
      return {...s, 'status': 'approved', 'rejectionReason': null, 'reviewedAt': Timestamp.now()};
    }).toList();
    final approvedIds = updated
        .where((s) => s['status'] == 'approved')
        .map((s) => s['skillId'] as String)
        .toList();
    final legacyPending = updated
        .where((s) => s['status'] == 'pending')
        .map((s) => {
              'skillId': s['skillId'],
              'description': s['description'],
              'diplomaNote': s['details'],
              'diplomaPhotoUrl': s['diplomaImageUrl'],
            })
        .toList();
    await _technicians.doc(techId).update({
      'specialties': updated,
      'servicesProvided': approvedIds,
      'pendingSkills': legacyPending,
    });
  }

  Future<void> adminRejectSpecialtyV2({
    required String techId,
    required String skillId,
    required String reason,
  }) async {
    final doc = await _technicians.doc(techId).get();
    final data = doc.data();
    if (data == null) return;
    final rawSpecialties =
        (data['specialties'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final updated = rawSpecialties.map((s) {
      if (s['skillId'] != skillId) return s;
      return {...s, 'status': 'rejected', 'rejectionReason': reason, 'reviewedAt': Timestamp.now()};
    }).toList();
    final legacyPending = updated
        .where((s) => s['status'] == 'pending')
        .map((s) => {
              'skillId': s['skillId'],
              'description': s['description'],
              'diplomaNote': s['details'],
              'diplomaPhotoUrl': s['diplomaImageUrl'],
            })
        .toList();
    await _technicians.doc(techId).update({
      'specialties': updated,
      'pendingSkills': legacyPending,
    });
  }

  Stream<List<TechnicianProfile>> streamPendingSpecialtyRequests() {
    return streamAllTechnicians().map((list) =>
        list.where((t) => t.specialties.any((s) => s.isPending)).toList());
  }

  Future<void> requestNewSpecialty({
    required String techId,
    required String skillId,
    required String description,
    required String diplomaNote,
    String? diplomaPhotoUrl,
  }) async {
    final doc = await _technicians.doc(techId).get();
    final current =
        (doc.data()?['pendingSkills'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    current.add({
      'skillId': skillId,
      'description': description,
      'diplomaNote': diplomaNote,
      'diplomaPhotoUrl': diplomaPhotoUrl,
      'requestedAt': FieldValue.serverTimestamp(),
    });
    await _technicians.doc(techId).update({'pendingSkills': current});
  }

  Future<void> adminApproveSpecialty(String techId, String skillId) =>
      adminApproveSpecialtyV2(techId: techId, skillId: skillId);

  Future<void> adminRejectSpecialty(String techId, String skillId) =>
      adminRejectSpecialtyV2(techId: techId, skillId: skillId, reason: 'Refusé par l\'admin');

  Future<void> techCancelRequest({
    required String requestId,
    required String techId,
    required String reason,
  }) async {
    final requestRef = _requests.doc(requestId);
    final techRef = _technicians.doc(techId);
    await _db.runTransaction((txn) async {
      final requestSnap = await txn.get(requestRef);
      if (!requestSnap.exists) throw Exception('Commande introuvable');
      final status = requestSnap.data()!['status'] as String? ?? '';
      if (!['accepted', 'pending', 'en_route'].contains(status)) {
        throw Exception("Impossible d'annuler — le travail a déjà commencé.");
      }
      if (status == 'en_route') {
        final commission = (requestSnap.data()!['commissionMAD'] as num?)?.toDouble() ?? 0;
        if (commission > 0) {
          final techSnap = await txn.get(techRef);
          final currentBalance = (techSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
          txn.update(techRef, {'walletBalance': currentBalance + commission});
        }
      }
      txn.update(requestRef, {
        'status': 'cancelled',
        'cancelledBy': 'technician',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'techId': null,
      });
    });
  }

  Future<void> rateTechnicianRatesClient({
    required String requestId,
    required String clientId,
    required int stars,
    String comment = '',
  }) async {
    assert(stars >= 1 && stars <= 5);
    await _db.runTransaction((txn) async {
      final requestRef = _requests.doc(requestId);
      final userRef = _users.doc(clientId);
      final requestSnap = await txn.get(requestRef);
      if (!requestSnap.exists) return;
      if (requestSnap.data()!['status'] != 'completed') {
        throw Exception('La commande doit être terminée pour noter.');
      }
      if (requestSnap.data()!['techRating'] != null) {
        throw Exception('Vous avez déjà noté ce client.');
      }
      final userSnap = await txn.get(userRef);
      final currentRating = (userSnap.data()?['rating'] as num?)?.toDouble() ?? 5.0;
      final ratingCount = (userSnap.data()?['ratingCount'] as num?)?.toInt() ?? 0;
      final newCount = ratingCount + 1;
      final newRating = ((currentRating * ratingCount) + stars) / newCount;
      txn.update(requestRef, {'techRating': stars, 'techComment': comment});
      txn.update(userRef, {
        'rating': double.parse(newRating.toStringAsFixed(2)),
        'ratingCount': newCount,
      });
    });
  }

  Stream<List<Map<String, dynamic>>> streamPlannedOrdersForTechnician(String techId) {
    return _requests
        .where('techId', isEqualTo: techId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => {...d.data(), 'requestId': d.id})
          .where((r) => r['scheduledAt'] != null)
          .toList();
      list.sort((a, b) {
        final ta = a['scheduledAt'] as Timestamp?;
        final tb = b['scheduledAt'] as Timestamp?;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return ta.compareTo(tb);
      });
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> streamPlannedOrdersForClient(String clientId) {
    return _requests.where('clientId', isEqualTo: clientId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => {...d.data(), 'requestId': d.id})
          .where((r) =>
              r['scheduledAt'] != null &&
              ['accepted', 'pending'].contains(r['status'] as String? ?? ''))
          .toList();
      list.sort((a, b) {
        final ta = a['scheduledAt'] as Timestamp?;
        final tb = b['scheduledAt'] as Timestamp?;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return ta.compareTo(tb);
      });
      return list;
    });
  }

  static bool canRevealPlannedOrderCode(Map<String, dynamic> order) {
    final scheduledAt = order['scheduledAt'] as Timestamp?;
    if (scheduledAt == null) return true;
    final diff = scheduledAt.toDate().difference(DateTime.now());
    return diff.inMinutes <= 180;
  }

  Future<void> techGoEnRoutePlanned({
    required String requestId,
    required String techId,
  }) async {
    final snap = await _requests.doc(requestId).get();
    if (!snap.exists) throw Exception('Commande introuvable');
    if (!canRevealPlannedOrderCode({...snap.data()!, 'requestId': requestId})) {
      throw Exception("Vous pouvez vous mettre en route seulement dans les 3h précédant l'heure prévue.");
    }
    await techGoEnRoute(requestId: requestId, techId: techId);
  }

  Stream<List<Map<String, dynamic>>> streamCompletedJobsForTechnician(String techId) {
    return _requests.where('techId', isEqualTo: techId).snapshots().map((snap) {
      final list = snap.docs.map((d) => {...d.data(), 'requestId': d.id}).toList();
      list.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }
}