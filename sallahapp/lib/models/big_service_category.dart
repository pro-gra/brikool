import 'package:flutter/material.dart';

/// Large-scale project categories — whole-building electrical wiring,
/// full-house painting, aluminum/window installation, construction —
/// handled by partner companies, not individual technicians.
class BigServiceCategory {
  const BigServiceCategory({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;

  static const all = <BigServiceCategory>[
    BigServiceCategory(
      id: 'vitrage_fenetres',
      label: 'Vitrage & Fenêtres',
      description: 'Installation ou remplacement complet de fenêtres, double vitrage',
      icon: Icons.window_rounded,
    ),
    BigServiceCategory(
      id: 'aluminium_menuiserie',
      label: 'Aluminium & Menuiserie',
      description: 'Portes, fenêtres, garde-corps en aluminium sur mesure',
      icon: Icons.door_sliding_rounded,
    ),
    BigServiceCategory(
      id: 'electricite_batiment',
      label: 'Électricité Bâtiment',
      description: 'Câblage complet, tableaux électriques, installations neuves',
      icon: Icons.electrical_services_rounded,
    ),
    BigServiceCategory(
      id: 'peinture',
      label: 'Peinture',
      description: 'Peinture intérieure/extérieure de maisons ou immeubles entiers',
      icon: Icons.format_paint_rounded,
    ),
    BigServiceCategory(
      id: 'plomberie_batiment',
      label: 'Plomberie Bâtiment',
      description: 'Installation sanitaire complète pour nouvelles constructions',
      icon: Icons.plumbing_rounded,
    ),
    BigServiceCategory(
      id: 'construction',
      label: 'Construction & Gros Œuvre',
      description: 'Construction, extension, ou rénovation complète',
      icon: Icons.construction_rounded,
    ),
    BigServiceCategory(
      id: 'climatisation_centrale',
      label: 'Climatisation Centralisée',
      description: 'Systèmes de climatisation pour immeubles ou grandes surfaces',
      icon: Icons.ac_unit_rounded,
    ),
    BigServiceCategory(
      id: 'etancheite',
      label: 'Étanchéité & Toiture',
      description: 'Terrasses, toitures, traitement d\'humidité à grande échelle',
      icon: Icons.roofing_rounded,
    ),
  ];

  static BigServiceCategory? byId(String id) {
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}