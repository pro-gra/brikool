import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus {
  pending,
  accepted,
  enRoute,
  inProgress,
  completed,
  cancelled,
}

extension RequestStatusX on RequestStatus {
  String get firestoreValue {
    switch (this) {
      case RequestStatus.pending:
        return 'pending';
      case RequestStatus.accepted:
        return 'accepted';
      case RequestStatus.enRoute:
        return 'en_route';
      case RequestStatus.inProgress:
        return 'in_progress';
      case RequestStatus.completed:
        return 'completed';
      case RequestStatus.cancelled:
        return 'cancelled';
    }
  }

  static RequestStatus fromFirestore(String value) {
    return RequestStatus.values.firstWhere(
      (s) => s.firestoreValue == value,
      orElse: () => RequestStatus.pending,
    );
  }
}

/// Maps 1:1 to the `requests` collection documented in the schema:
/// { requestId, clientId, techId, serviceType, status, priceQuoteMAD,
///   commissionMAD, clientLocation, otpCode, createdAt }
class RequestModel {
  RequestModel({
    required this.requestId,
    required this.clientId,
    this.techId,
    required this.serviceType,
    required this.status,
    required this.priceQuoteMad,
    required this.commissionMad,
    required this.clientLocation,
    required this.otpCode,
    required this.createdAt,
  });

  final String requestId;
  final String clientId;
  final String? techId;
  final String serviceType;
  final RequestStatus status;
  final double priceQuoteMad;
  final double commissionMad;
  final GeoPoint clientLocation;
  final String otpCode;
  final DateTime createdAt;

  factory RequestModel.fromMap(String id, Map<String, dynamic> map) {
    return RequestModel(
      requestId: id,
      clientId: map['clientId'] as String,
      techId: map['techId'] as String?,
      serviceType: map['serviceType'] as String,
      status: RequestStatusX.fromFirestore(map['status'] as String? ?? 'pending'),
      priceQuoteMad: (map['priceQuoteMAD'] as num).toDouble(),
      commissionMad: (map['commissionMAD'] as num).toDouble(),
      clientLocation: map['clientLocation'] as GeoPoint,
      otpCode: map['otpCode'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'techId': techId,
      'serviceType': serviceType,
      'status': status.firestoreValue,
      'priceQuoteMAD': priceQuoteMad,
      'commissionMAD': commissionMad,
      'clientLocation': clientLocation,
      'otpCode': otpCode,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}