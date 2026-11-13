import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Detects GPS position and reverse-geocodes to a Moroccan city name.
class LocationService {
  static const _nominatimBase = 'https://nominatim.openstreetmap.org/reverse';

  /// Used by home_screen.dart — returns a simple label record or null.
  Future<({String label})?> getCurrentLocation() async {
    final city = await _detectCityName();
    if (city == null || city.isEmpty) return null;
    return (label: city);
  }

  /// Full detection — returns position + city name.
  Future<_CityResult?> detectCity() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10));

      final city = await _reverseGeocode(position.latitude, position.longitude);
      return _CityResult(position: position, city: city);
    } catch (e) {
      debugPrint('LocationService.detectCity error: $e');
      return null;
    }
  }

  Future<String?> _detectCityName() async {
    final result = await detectCity();
    if (result == null || result.city.isEmpty) return null;
    return result.city;
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        '$_nominatimBase?lat=$lat&lon=$lng&format=json&accept-language=fr',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'brikol-ma-app/1.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return '';

      final data = json.decode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>? ?? {};

      final city = address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String? ??
          address['municipality'] as String? ??
          address['county'] as String? ??
          '';

      return _cleanCityName(city);
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
      return '';
    }
  }

  String _cleanCityName(String raw) {
    if (raw.isEmpty) return raw;
    final prefixes = [
      'Province de ', 'Préfecture de ', 'Commune de ',
      'Cercle de ', 'Arrondissement de ',
    ];
    var cleaned = raw;
    for (final prefix in prefixes) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length);
        break;
      }
    }
    return cleaned.trim();
  }
}

/// Plain class instead of a record type — avoids the Position type mismatch.
class _CityResult {
  const _CityResult({required this.position, required this.city});
  final Position position;
  final String city;
}

/// Global notifier for the user's selected/detected location.
/// null = use current GPS position
/// non-null = a saved address the user explicitly selected
class ActiveLocation {
  ActiveLocation._();
  static final ValueNotifier<Map<String, dynamic>?> selected =
      ValueNotifier<Map<String, dynamic>?>(null);
}

/// Widget that auto-detects GPS city and calls onCityDetected with the result.
class AutoCityDetector extends StatefulWidget {
  const AutoCityDetector({
    super.key,
    required this.onCityDetected,
    this.currentCity,
  });

  final ValueChanged<String> onCityDetected;
  final String? currentCity;

  @override
  State<AutoCityDetector> createState() => _AutoCityDetectorState();
}

class _AutoCityDetectorState extends State<AutoCityDetector> {
  bool _detecting = false;
  String? _detectedCity;
  String? _error;

  Future<void> _detect() async {
    setState(() { _detecting = true; _error = null; });

    final result = await LocationService().detectCity();

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _detecting = false;
        _error = 'GPS non disponible — choisissez votre ville manuellement.';
      });
      return;
    }

    if (result.city.isEmpty) {
      setState(() {
        _detecting = false;
        _error = 'Ville non détectée — choisissez manuellement.';
      });
      return;
    }

    setState(() { _detecting = false; _detectedCity = result.city; });
    widget.onCityDetected(result.city);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _detecting ? null : _detect,
            icon: _detecting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded, size: 17),
            label: Text(_detecting
                ? 'Détection en cours…'
                : _detectedCity != null
                    ? 'Détecté: $_detectedCity ✓'
                    : 'Détecter ma ville automatiquement'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor:
                  _detectedCity != null ? Colors.green.shade700 : null,
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!,
                style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
          ),
      ],
    );
  }
}