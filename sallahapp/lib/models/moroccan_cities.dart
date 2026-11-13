import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// All principal Moroccan cities, alphabetically sorted.
const List<String> moroccanCities = [
  'Agadir', 'Ahfir', 'Aït Melloul', 'Al Hoceïma', 'Assilah', 'Azemmour',
  'Azrou', 'Béni Mellal', 'Benslimane', 'Berkane', 'Berrechid', 'Boujdour',
  'Bouskoura', 'Casablanca', 'Chefchaouen', 'Dakhla', 'Dcheira', 'Drarga',
  'El Aïoun', 'El Hajeb', 'El Jadida', 'El Kelâa des Sraghna', 'Errachidia',
  'Essaouira', 'Fès', 'Fnideq', 'Fquih Ben Salah', 'Guelmim', 'Guercif',
  'Ifrane', 'Imzouren', 'Inezgane', 'Jerada', 'Kénitra', 'Khémisset',
  'Khénifra', 'Khouribga', 'Ksar El Kébir', 'Laâyoune', 'Larache',
  'Marrakech', 'Martil', 'Meknès', 'Midelt', 'Mohammédia', 'Nador',
  'Ouarzazate', 'Oued Zem', 'Oujda', 'Rabat', 'Safi', 'Salé', 'Sefrou',
  'Settat', 'Sidi Bennour', 'Sidi Ifni', 'Sidi Kacem', 'Sidi Slimane',
  'Skhirat', 'Souk El Arbaa', 'Tamesna', 'Tan-Tan', 'Tanger', 'Taourirt',
  'Taroudant', 'Taza', 'Témara', 'Tétouan', 'Tiflet', 'Tinghir', 'Tiznit',
  'Youssoufia', 'Zagora',
];

/// Opens a searchable, alphabetical city picker. Returns the chosen
/// city, or null if dismissed.
Future<String?> showCityPicker(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _CityPickerSheet(current: current),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({this.current});
  final String? current;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = moroccanCities
        .where((c) => c.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Text('Choisissez votre ville',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Rechercher une ville…',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Aucune ville trouvée',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final city = filtered[i];
                        final selected = city == widget.current;
                        return ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          leading: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.location_city_rounded,
                            size: 20,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          title: Text(city,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              )),
                          onTap: () => Navigator.pop(context, city),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}