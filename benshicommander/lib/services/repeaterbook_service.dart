import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import '../models/repeater.dart';

class RepeaterBookService {
  final String _baseUrl = "https://www.repeaterbook.com/api/export.php";

  /// Given a latitude/longitude, fetch up to 32 closest 2m/70cm repeaters from RepeaterBook for the correct state.
  Future<List<Repeater>> getRepeatersNearby({
    required double latitude,
    required double longitude,
  }) async {
    // Reverse geocode to get state and country
    final placemarks = await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isEmpty) throw Exception("Could not find placemark for location");

    final Placemark place = placemarks.first;
    final String? state = place.administrativeArea;
    final String? country = place.country;
    if (state == null || country == null) throw Exception("Could not determine state/country from location");

    // Convert state name to FIPS code
    final String? stateFips = _stateNameToFips[state];
    if (stateFips == null) throw Exception("Unsupported state: $state");

    // Build API request
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'country': country,
      'state_id': stateFips,
    });

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'BenshiCommander (your@email.com)', // Use your real info!
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load repeaters (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (data['results'] == null || data['results'].isEmpty) {
      return [];
    }

    final List<dynamic> results = data['results'];
    // Filter to 2m/70cm, calculate distance, and take top 32
    final filtered = results
        .map((json) => Repeater.fromJson(json))
        .where((r) {
          final freq = r.outputFrequency; // use outputFrequency as per the model
          return (freq >= 144 && freq <= 148) || (freq >= 420 && freq <= 450);
        })
        .map((r) {
          final dist = _haversine(latitude, longitude, r.latitude, r.longitude);
          return MapEntry(r, dist);
        })
        .toList();

    filtered.sort((a, b) => a.value.compareTo(b.value));
    final top32 = filtered.take(32).map((e) => e.key).toList();

    return top32;
  }

  // Simple haversine formula for distance in miles
  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 3958.8; // Radius of Earth in miles
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180);

  /// Map US state name to FIPS code as required by RepeaterBook.
  static const Map<String, String> _stateNameToFips = {
    'Alabama': '01',
    'Alaska': '02',
    'Arizona': '04',
    'Arkansas': '05',
    'California': '06',
    'Colorado': '08',
    'Connecticut': '09',
    'Delaware': '10',
    'District of Columbia': '11',
    'Florida': '12',
    'Georgia': '13',
    'Hawaii': '15',
    'Idaho': '16',
    'Illinois': '17',
    'Indiana': '18',
    'Iowa': '19',
    'Kansas': '20',
    'Kentucky': '21',
    'Louisiana': '22',
    'Maine': '23',
    'Maryland': '24',
    'Massachusetts': '25',
    'Michigan': '26',
    'Minnesota': '27',
    'Mississippi': '28',
    'Missouri': '29',
    'Montana': '30',
    'Nebraska': '31',
    'Nevada': '32',
    'New Hampshire': '33',
    'New Jersey': '34',
    'New Mexico': '35',
    'New York': '36',
    'North Carolina': '37',
    'North Dakota': '38',
    'Ohio': '39',
    'Oklahoma': '40',
    'Oregon': '41',
    'Pennsylvania': '42',
    'Rhode Island': '44',
    'South Carolina': '45',
    'South Dakota': '46',
    'Tennessee': '47',
    'Texas': '48',
    'Utah': '49',
    'Vermont': '50',
    'Virginia': '51',
    'Washington': '53',
    'West Virginia': '54',
    'Wisconsin': '55',
    'Wyoming': '56',
    // Add more as needed
  };
}