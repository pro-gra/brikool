/// Guided questions for the services Brikool is launching with.
/// The values are saved on each request so technicians can price the actual job.
class ServiceIntakeField {
  const ServiceIntakeField({
    required this.id,
    required this.labelKey,
    this.options = const [],
    this.hintKey,
    this.required = true,
  });

  final String id;
  final String labelKey;
  final List<String> options;
  final String? hintKey;
  final bool required;

  bool get isChoice => options.isNotEmpty;
}

List<ServiceIntakeField> serviceIntakeFields(String skillId) {
  switch (skillId) {
    case 'plumbing':
      return const [
        ServiceIntakeField(id: 'problem', labelKey: 'intake_plumbing_problem', options: ['intake_plumbing_leak', 'intake_plumbing_blockage', 'intake_plumbing_tap', 'intake_plumbing_toilet', 'intake_plumbing_heater', 'intake_plumbing_installation', 'intake_other']),
        ServiceIntakeField(id: 'room', labelKey: 'intake_room', options: ['intake_kitchen', 'intake_bathroom', 'intake_toilet_room', 'intake_outdoor', 'intake_multiple_rooms']),
        ServiceIntakeField(id: 'pipe_access', labelKey: 'intake_pipe_access', options: ['intake_visible', 'intake_hidden', 'intake_not_sure']),
        ServiceIntakeField(id: 'water_shutoff', labelKey: 'intake_water_shutoff', options: ['intake_yes', 'intake_no', 'intake_not_sure']),
        ServiceIntakeField(id: 'quantity', labelKey: 'intake_quantity', hintKey: 'intake_quantity_hint', required: false),
      ];
    case 'electricity':
      return const [
        ServiceIntakeField(id: 'problem', labelKey: 'intake_electric_problem', options: ['intake_power_outage', 'intake_socket', 'intake_switch', 'intake_lighting', 'intake_breaker', 'intake_wiring', 'intake_short_circuit', 'intake_other']),
        ServiceIntakeField(id: 'room', labelKey: 'intake_room', options: ['intake_kitchen', 'intake_bathroom', 'intake_living_room', 'intake_bedroom', 'intake_multiple_rooms']),
        ServiceIntakeField(id: 'power_status', labelKey: 'intake_power_status', options: ['intake_power_on', 'intake_power_off', 'intake_intermittent']),
        ServiceIntakeField(id: 'points', labelKey: 'intake_points_count', hintKey: 'intake_points_hint', required: false),
        ServiceIntakeField(id: 'building', labelKey: 'intake_building_type', options: ['intake_apartment', 'intake_house', 'intake_shop', 'intake_office']),
      ];
    case 'clim':
      return const [
        ServiceIntakeField(id: 'equipment', labelKey: 'intake_hvac_equipment', options: ['intake_split_ac', 'intake_central_ac', 'intake_heater', 'intake_boiler', 'intake_ventilation']),
        ServiceIntakeField(id: 'problem', labelKey: 'intake_hvac_problem', options: ['intake_no_cooling', 'intake_no_heating', 'intake_water_leak', 'intake_noise', 'intake_maintenance', 'intake_installation', 'intake_gas_refill', 'intake_other']),
        ServiceIntakeField(id: 'units', labelKey: 'intake_units_count', hintKey: 'intake_units_hint', required: false),
        ServiceIntakeField(id: 'brand', labelKey: 'intake_brand_model', hintKey: 'intake_brand_hint', required: false),
        ServiceIntakeField(id: 'access', labelKey: 'intake_unit_access', options: ['intake_easy_access', 'intake_high_wall', 'intake_roof_access', 'intake_not_sure']),
      ];
    case 'printing':
      return const [
        ServiceIntakeField(id: 'print_type', labelKey: 'intake_print_type', options: ['intake_documents', 'intake_photos', 'intake_flyers', 'intake_business_cards', 'intake_large_format', 'intake_binding', 'intake_lamination']),
        ServiceIntakeField(id: 'quantity', labelKey: 'intake_copies', hintKey: 'intake_copies_hint'),
        ServiceIntakeField(id: 'paper_size', labelKey: 'intake_paper_size', options: ['intake_a4', 'intake_a3', 'intake_a5', 'intake_custom_size']),
        ServiceIntakeField(id: 'color', labelKey: 'intake_print_color', options: ['intake_color', 'intake_black_white']),
        ServiceIntakeField(id: 'sides', labelKey: 'intake_print_sides', options: ['intake_single_sided', 'intake_double_sided']),
        ServiceIntakeField(id: 'finishing', labelKey: 'intake_finishing', options: ['intake_none', 'intake_stapling', 'intake_binding', 'intake_lamination']),
        ServiceIntakeField(id: 'delivery', labelKey: 'intake_delivery', options: ['intake_pickup', 'intake_delivery']),
      ];
    case 'appliance':
      return const [
        ServiceIntakeField(id: 'appliance', labelKey: 'intake_appliance_type', options: ['intake_washing_machine', 'intake_fridge', 'intake_freezer', 'intake_oven', 'intake_dishwasher', 'intake_water_heater', 'intake_microwave', 'intake_other_appliance']),
        ServiceIntakeField(id: 'problem', labelKey: 'intake_appliance_problem', options: ['intake_not_starting', 'intake_not_heating_cooling', 'intake_leaking', 'intake_strange_noise', 'intake_error_code', 'intake_broken_part', 'intake_other']),
        ServiceIntakeField(id: 'brand_model', labelKey: 'intake_brand_model', hintKey: 'intake_brand_hint', required: false),
        ServiceIntakeField(id: 'age', labelKey: 'intake_appliance_age', options: ['intake_under_year', 'intake_one_three_years', 'intake_three_seven_years', 'intake_over_seven_years', 'intake_not_sure']),
        ServiceIntakeField(id: 'error_code', labelKey: 'intake_error_code', hintKey: 'intake_error_hint', required: false),
      ];
    // Prepared for a future launch category; not displayed in the launch catalog.
    case 'painting':
      return const [
        ServiceIntakeField(id: 'surface', labelKey: 'intake_paint_surface', options: ['intake_walls', 'intake_ceiling', 'intake_doors', 'intake_facade', 'intake_full_room']),
        ServiceIntakeField(id: 'rooms', labelKey: 'intake_rooms_count', hintKey: 'intake_rooms_hint'),
        ServiceIntakeField(id: 'area', labelKey: 'intake_paint_area', hintKey: 'intake_area_hint', required: false),
        ServiceIntakeField(id: 'condition', labelKey: 'intake_wall_condition', options: ['intake_good_condition', 'intake_cracks', 'intake_peeling', 'intake_moisture']),
        ServiceIntakeField(id: 'materials', labelKey: 'intake_materials', options: ['intake_materials_client', 'intake_materials_technician', 'intake_materials_discuss']),
        ServiceIntakeField(id: 'paint_type', labelKey: 'intake_paint_type', options: ['intake_matte', 'intake_satin', 'intake_gloss', 'intake_not_sure']),
      ];
    default:
      return const [];
  }
}
