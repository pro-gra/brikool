import 'package:flutter/material.dart';

/// A technician's skill domain. Requests carry a skillId so the job
/// feed can match technicians to compatible requests.
class TechnicianSkill {
  const TechnicianSkill({required this.id, required this.icon, required this.label});

  final String id;
  final IconData icon;
  final String label;

  static const List<TechnicianSkill> all = [
    // Auto & moto
    TechnicianSkill(id: 'battery', icon: Icons.battery_charging_full_rounded, label: 'Batterie'),
    TechnicianSkill(id: 'tire', icon: Icons.tire_repair_rounded, label: 'Pneu'),
    TechnicianSkill(id: 'towing', icon: Icons.local_shipping_rounded, label: 'Remorquage'),
    TechnicianSkill(id: 'mecanique', icon: Icons.build_rounded, label: 'Mécanique auto'),
    TechnicianSkill(id: 'moto', icon: Icons.electric_moped_rounded, label: 'Moto & Scooter'),
    TechnicianSkill(id: 'carwash', icon: Icons.local_car_wash_rounded, label: 'Lavage auto'),
    // Maison
    TechnicianSkill(id: 'plumbing', icon: Icons.plumbing_rounded, label: 'Plomberie'),
    TechnicianSkill(id: 'electricity', icon: Icons.electrical_services_rounded, label: 'Électricité'),
    TechnicianSkill(id: 'locksmith', icon: Icons.key_rounded, label: 'Serrurerie'),
    TechnicianSkill(id: 'carpentry', icon: Icons.carpenter_rounded, label: 'Menuiserie'),
    TechnicianSkill(id: 'painting', icon: Icons.format_paint_rounded, label: 'Peinture'),
    TechnicianSkill(id: 'masonry', icon: Icons.foundation_rounded, label: 'Maçonnerie'),
    TechnicianSkill(id: 'aluminium', icon: Icons.window_rounded, label: 'Alu & vitrerie'),
    // Équipements
    TechnicianSkill(id: 'appliance', icon: Icons.kitchen_rounded, label: 'Électroménager'),
    TechnicianSkill(id: 'clim', icon: Icons.ac_unit_rounded, label: 'Climatisation & froid'),
    TechnicianSkill(id: 'it', icon: Icons.computer_rounded, label: 'Informatique & TV'),
    TechnicianSkill(id: 'satellite', icon: Icons.satellite_alt_rounded, label: 'Parabole & caméras'),
    // Services
    TechnicianSkill(id: 'cleaning', icon: Icons.cleaning_services_rounded, label: 'Nettoyage'),
    TechnicianSkill(id: 'gardening', icon: Icons.grass_rounded, label: 'Jardinage'),
    TechnicianSkill(id: 'pest', icon: Icons.pest_control_rounded, label: 'Dératisation'),
    TechnicianSkill(id: 'transport', icon: Icons.local_shipping_rounded, label: 'Transport & déménagement'),
    TechnicianSkill(id: 'handyman', icon: Icons.handyman_rounded, label: 'Bricolage divers'),
  ];
}