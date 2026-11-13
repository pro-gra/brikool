import 'package:flutter/material.dart';

/// The 6 top-level categories shown on the client home screen grid.
enum ServiceCategory {
  auto,
  home,
  appliance,
  moto,
  transport,
  carwash,
}

extension ServiceCategoryX on ServiceCategory {
  /// Localization key for this category's label.
  String get labelKey {
    switch (this) {
      case ServiceCategory.auto:
        return 'cat_auto';
      case ServiceCategory.home:
        return 'cat_home';
      case ServiceCategory.appliance:
        return 'cat_appliance';
      case ServiceCategory.moto:
        return 'cat_moto';
      case ServiceCategory.transport:
        return 'cat_transport';
      case ServiceCategory.carwash:
        return 'cat_carwash';
    }
  }

  IconData get icon {
    switch (this) {
      case ServiceCategory.auto:
        return Icons.directions_car_filled_outlined;
      case ServiceCategory.home:
        return Icons.home_repair_service_outlined;
      case ServiceCategory.appliance:
        return Icons.kitchen_outlined;
      case ServiceCategory.moto:
        return Icons.electric_moped_outlined;
      case ServiceCategory.transport:
        return Icons.local_shipping_outlined;
      case ServiceCategory.carwash:
        return Icons.local_car_wash_outlined;
    }
  }

  /// Firestore identifier stored on `requests.serviceType`.
  String get firestoreValue => name;
}