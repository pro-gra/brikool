import 'package:flutter/material.dart';

/// A single SOS emergency issue type, with the icon, localization keys,
/// and base fixed price (MAD) shown in the quote step.
class SosIssue {
  const SosIssue({
    required this.id,
    required this.icon,
    required this.labelKey,
    required this.subLabelKey,
    required this.basePriceMad,
  });

  final String id;
  final IconData icon;
  final String labelKey;
  final String subLabelKey;
  final double basePriceMad;

  static const List<SosIssue> all = [
    SosIssue(
      id: 'battery',
      icon: Icons.battery_charging_full_outlined,
      labelKey: 'issue_battery',
      subLabelKey: 'issue_battery_sub',
      basePriceMad: 150,
    ),
    SosIssue(
      id: 'tire',
      icon: Icons.tire_repair_outlined,
      labelKey: 'issue_tire',
      subLabelKey: 'issue_tire_sub',
      basePriceMad: 120,
    ),
    SosIssue(
      id: 'towing',
      icon: Icons.local_shipping_outlined,
      labelKey: 'issue_towing',
      subLabelKey: 'issue_towing_sub',
      basePriceMad: 350,
    ),
    SosIssue(
      id: 'locksmith',
      icon: Icons.key_outlined,
      labelKey: 'issue_locksmith',
      subLabelKey: 'issue_locksmith_sub',
      basePriceMad: 180,
    ),
    SosIssue(
      id: 'plumbing',
      icon: Icons.plumbing_outlined,
      labelKey: 'issue_plumbing',
      subLabelKey: 'issue_plumbing_sub',
      basePriceMad: 200,
    ),
  ];
}