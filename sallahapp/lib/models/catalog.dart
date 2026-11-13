import 'package:flutter/material.dart';
import 'service_category.dart';

/// A bookable service. No fixed price — the client proposes a budget
/// (suggestedBudget is only a starting hint) and technicians respond
/// with their own price offers (InDrive-style negotiation).
class ServiceOffer {
  const ServiceOffer({
    required this.skillId,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.suggestedBudget,
  });

  /// Matches TechnicianSkill.id — used to route requests to the right
  /// technicians' job feeds.
  final String skillId;
  final String label;
  final String sublabel;
  final IconData icon;
  final double suggestedBudget;
}

/// Emergency (SOS) quick offers.
List<ServiceOffer> sosOffers(String Function(String) t) => [
  ServiceOffer(skillId: 'battery',     label: t('sos_battery_label'),    sublabel: t('sos_battery_sub'),    icon: Icons.battery_charging_full_rounded, suggestedBudget: 150),
  ServiceOffer(skillId: 'tire',        label: t('sos_tire_label'),        sublabel: t('sos_tire_sub'),        icon: Icons.tire_repair_rounded,           suggestedBudget: 120),
  ServiceOffer(skillId: 'towing',      label: t('sos_towing_label'),      sublabel: t('sos_towing_sub'),      icon: Icons.local_shipping_rounded,        suggestedBudget: 350),
  ServiceOffer(skillId: 'locksmith',   label: t('sos_locksmith_label'),   sublabel: t('sos_locksmith_sub'),   icon: Icons.key_rounded,                   suggestedBudget: 180),
  ServiceOffer(skillId: 'plumbing',    label: t('sos_plumbing_label'),    sublabel: t('sos_plumbing_sub'),    icon: Icons.plumbing_rounded,              suggestedBudget: 200),
  ServiceOffer(skillId: 'electricity', label: t('sos_electricity_label'), sublabel: t('sos_electricity_sub'), icon: Icons.flash_on_rounded,              suggestedBudget: 200),
];

/// The full catalog — all real-life services, grouped by category.
Map<ServiceCategory, List<ServiceOffer>> categoryCatalog(String Function(String) t) => {
  ServiceCategory.auto: [
    ServiceOffer(skillId: 'battery',     label: t('auto_battery_label'),    sublabel: t('auto_battery_sub'),    icon: Icons.battery_charging_full_rounded, suggestedBudget: 150),
    ServiceOffer(skillId: 'tire',        label: t('auto_tire_label'),        sublabel: t('auto_tire_sub'),        icon: Icons.tire_repair_rounded,           suggestedBudget: 120),
    ServiceOffer(skillId: 'mecanique',   label: t('auto_oil_label'),         sublabel: t('auto_oil_sub'),         icon: Icons.opacity_rounded,               suggestedBudget: 250),
    ServiceOffer(skillId: 'mecanique',   label: t('auto_diagnostic_label'),  sublabel: t('auto_diagnostic_sub'),  icon: Icons.troubleshoot_rounded,          suggestedBudget: 150),
    ServiceOffer(skillId: 'mecanique',   label: t('auto_brakes_label'),      sublabel: t('auto_brakes_sub'),      icon: Icons.album_rounded,                 suggestedBudget: 300),
    ServiceOffer(skillId: 'mecanique',   label: t('auto_clutch_label'),      sublabel: t('auto_clutch_sub'),      icon: Icons.settings_rounded,              suggestedBudget: 500),
    ServiceOffer(skillId: 'mecanique',   label: t('auto_belt_label'),        sublabel: t('auto_belt_sub'),        icon: Icons.sync_rounded,                  suggestedBudget: 400),
    ServiceOffer(skillId: 'towing',      label: t('auto_towing_label'),      sublabel: t('auto_towing_sub'),      icon: Icons.local_shipping_rounded,        suggestedBudget: 350),
    ServiceOffer(skillId: 'locksmith',   label: t('auto_locksmith_label'),   sublabel: t('auto_locksmith_sub'),   icon: Icons.key_rounded,                   suggestedBudget: 180),
    ServiceOffer(skillId: 'electricity', label: t('auto_electric_label'),    sublabel: t('auto_electric_sub'),    icon: Icons.electrical_services_rounded,   suggestedBudget: 200),
  ],
  ServiceCategory.home: [
    ServiceOffer(skillId: 'plumbing',    label: t('home_plumbing_label'),    sublabel: t('home_plumbing_sub'),    icon: Icons.plumbing_rounded,              suggestedBudget: 200),
    ServiceOffer(skillId: 'plumbing',    label: t('home_drain_label'),       sublabel: t('home_drain_sub'),       icon: Icons.water_damage_rounded,          suggestedBudget: 250),
    ServiceOffer(skillId: 'electricity', label: t('home_electricity_label'), sublabel: t('home_electricity_sub'), icon: Icons.electrical_services_rounded,   suggestedBudget: 200),
    ServiceOffer(skillId: 'locksmith',   label: t('home_locksmith_label'),   sublabel: t('home_locksmith_sub'),   icon: Icons.key_rounded,                   suggestedBudget: 180),
    ServiceOffer(skillId: 'carpentry',   label: t('home_carpentry_label'),   sublabel: t('home_carpentry_sub'),   icon: Icons.carpenter_rounded,             suggestedBudget: 300),
    ServiceOffer(skillId: 'aluminium',   label: t('home_aluminium_label'),   sublabel: t('home_aluminium_sub'),   icon: Icons.window_rounded,                suggestedBudget: 250),
    ServiceOffer(skillId: 'painting',    label: t('home_painting_label'),    sublabel: t('home_painting_sub'),    icon: Icons.format_paint_rounded,          suggestedBudget: 400),
    ServiceOffer(skillId: 'masonry',     label: t('home_masonry_label'),     sublabel: t('home_masonry_sub'),     icon: Icons.foundation_rounded,            suggestedBudget: 500),
    ServiceOffer(skillId: 'handyman',    label: t('home_handyman_label'),    sublabel: t('home_handyman_sub'),    icon: Icons.handyman_rounded,              suggestedBudget: 150),
    ServiceOffer(skillId: 'gardening',   label: t('home_gardening_label'),   sublabel: t('home_gardening_sub'),   icon: Icons.grass_rounded,                 suggestedBudget: 200),
    ServiceOffer(skillId: 'pest',        label: t('home_pest_label'),        sublabel: t('home_pest_sub'),        icon: Icons.pest_control_rounded,          suggestedBudget: 300),
    ServiceOffer(skillId: 'cleaning',    label: t('home_cleaning_label'),    sublabel: t('home_cleaning_sub'),    icon: Icons.cleaning_services_rounded,     suggestedBudget: 250),
  ],
  ServiceCategory.appliance: [
    ServiceOffer(skillId: 'clim',        label: t('appliance_clim_label'),         sublabel: t('appliance_clim_sub'),         icon: Icons.ac_unit_rounded,               suggestedBudget: 300),
    ServiceOffer(skillId: 'clim',        label: t('appliance_fridge_label'),       sublabel: t('appliance_fridge_sub'),       icon: Icons.kitchen_rounded,               suggestedBudget: 250),
    ServiceOffer(skillId: 'appliance',   label: t('appliance_washer_label'),       sublabel: t('appliance_washer_sub'),       icon: Icons.local_laundry_service_rounded, suggestedBudget: 220),
    ServiceOffer(skillId: 'appliance',   label: t('appliance_oven_label'),         sublabel: t('appliance_oven_sub'),         icon: Icons.microwave_rounded,             suggestedBudget: 200),
    ServiceOffer(skillId: 'appliance',   label: t('appliance_dishwasher_label'),   sublabel: t('appliance_dishwasher_sub'),   icon: Icons.countertops_rounded,           suggestedBudget: 220),
    ServiceOffer(skillId: 'appliance',   label: t('appliance_water_heater_label'), sublabel: t('appliance_water_heater_sub'), icon: Icons.hot_tub_rounded,               suggestedBudget: 250),
    ServiceOffer(skillId: 'it',          label: t('appliance_tv_label'),           sublabel: t('appliance_tv_sub'),           icon: Icons.tv_rounded,                    suggestedBudget: 200),
    ServiceOffer(skillId: 'it',          label: t('appliance_it_label'),           sublabel: t('appliance_it_sub'),           icon: Icons.computer_rounded,              suggestedBudget: 150),
    ServiceOffer(skillId: 'satellite',   label: t('appliance_satellite_label'),    sublabel: t('appliance_satellite_sub'),    icon: Icons.satellite_alt_rounded,         suggestedBudget: 150),
    ServiceOffer(skillId: 'satellite',   label: t('appliance_camera_label'),       sublabel: t('appliance_camera_sub'),       icon: Icons.videocam_rounded,              suggestedBudget: 400),
  ],
  ServiceCategory.moto: [
    ServiceOffer(skillId: 'moto', label: t('moto_tire_label'),     sublabel: t('moto_tire_sub'),     icon: Icons.tire_repair_rounded,           suggestedBudget: 80),
    ServiceOffer(skillId: 'moto', label: t('moto_battery_label'),  sublabel: t('moto_battery_sub'),  icon: Icons.battery_charging_full_rounded, suggestedBudget: 100),
    ServiceOffer(skillId: 'moto', label: t('moto_mechanic_label'), sublabel: t('moto_mechanic_sub'), icon: Icons.build_rounded,                 suggestedBudget: 150),
    ServiceOffer(skillId: 'moto', label: t('moto_towing_label'),   sublabel: t('moto_towing_sub'),   icon: Icons.local_shipping_rounded,        suggestedBudget: 200),
  ],
  ServiceCategory.transport: [
    ServiceOffer(skillId: 'transport', label: t('transport_tricycle_label'), sublabel: t('transport_tricycle_sub'), icon: Icons.electric_rickshaw_rounded, suggestedBudget: 100),
    ServiceOffer(skillId: 'transport', label: t('transport_van_label'),      sublabel: t('transport_van_sub'),      icon: Icons.airport_shuttle_rounded,   suggestedBudget: 250),
    ServiceOffer(skillId: 'transport', label: t('transport_moving_label'),   sublabel: t('transport_moving_sub'),   icon: Icons.home_work_rounded,         suggestedBudget: 800),
    ServiceOffer(skillId: 'transport', label: t('transport_workers_label'),  sublabel: t('transport_workers_sub'),  icon: Icons.groups_rounded,            suggestedBudget: 300),
  ],
  ServiceCategory.carwash: [
    ServiceOffer(skillId: 'carwash', label: t('carwash_exterior_label'),  sublabel: t('carwash_exterior_sub'),  icon: Icons.local_car_wash_rounded,    suggestedBudget: 80),
    ServiceOffer(skillId: 'carwash', label: t('carwash_full_label'),      sublabel: t('carwash_full_sub'),      icon: Icons.cleaning_services_rounded, suggestedBudget: 150),
    ServiceOffer(skillId: 'carwash', label: t('carwash_detailing_label'), sublabel: t('carwash_detailing_sub'), icon: Icons.auto_awesome_rounded,      suggestedBudget: 400),
    ServiceOffer(skillId: 'carwash', label: t('carwash_seats_label'),     sublabel: t('carwash_seats_sub'),     icon: Icons.chair_rounded,             suggestedBudget: 200),
  ],
};