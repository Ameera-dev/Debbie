import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationData {
  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;
}

enum LocationFailure { permissionDenied, permissionPermanentlyDenied, disabled, timeout, unknown }

class LocationService {
  /// Returns location data if permitted, or a [LocationFailure] if not.
  Future<({LocationData? data, LocationFailure? failure})> getCurrentLocation() async {
    // Check if location services are enabled on the device
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return (data: null, failure: LocationFailure.disabled);
    }

    // Check / request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return (data: null, failure: LocationFailure.permissionDenied);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return (data: null, failure: LocationFailure.permissionPermanentlyDenied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10));

      final label = await _reverseGeocode(position.latitude, position.longitude);

      return (
        data: LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          label: label,
        ),
        failure: null,
      );
    } on LocationServiceDisabledException {
      return (data: null, failure: LocationFailure.disabled);
    } catch (_) {
      return (data: null, failure: LocationFailure.timeout);
    }
  }

  /// Search for places by name/address using OpenStreetMap's Nominatim.
  /// This indexes points of interest (shops, restaurants, landmarks) which
  /// the platform-native geocoder typically misses.
  Future<List<LocationData>> searchPlaces(String query, {int limit = 8}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <LocationData>[];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '$limit',
      'addressdetails': '1',
    });

    try {
      final res = await http.get(
        uri,
        // Nominatim's usage policy requires an identifying User-Agent.
        headers: const {
          'User-Agent': 'Debbie/1.0 (mindful-money-companion)',
          'Accept-Language': 'id,en',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return const <LocationData>[];

      final decoded = jsonDecode(res.body);
      if (decoded is! List) return const <LocationData>[];

      final results = <LocationData>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final lat = double.tryParse(entry['lat']?.toString() ?? '');
        final lon = double.tryParse(entry['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final displayName = entry['display_name']?.toString() ?? trimmed;
        results.add(
          LocationData(
            latitude: lat,
            longitude: lon,
            label: _shortenDisplayName(displayName),
          ),
        );
      }
      return results;
    } catch (_) {
      return const <LocationData>[];
    }
  }

  String _shortenDisplayName(String displayName) {
    final parts = displayName
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return displayName;
    // Keep the venue name + up to 2 locality parts so it stays readable.
    return parts.take(3).join(', ');
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return _coordLabel(lat, lng);

      final p = placemarks.first;

      // Build a human-readable label relevant for Indonesian addresses
      final parts = <String>[];

      if (p.street != null && p.street!.isNotEmpty && p.street != p.subLocality) {
        parts.add(p.street!);
      }
      if (p.subLocality != null && p.subLocality!.isNotEmpty) {
        parts.add(p.subLocality!);
      } else if (p.locality != null && p.locality!.isNotEmpty) {
        parts.add(p.locality!);
      }
      if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) {
        parts.add(p.subAdministrativeArea!);
      } else if (parts.isEmpty && p.administrativeArea != null) {
        parts.add(p.administrativeArea!);
      }

      if (parts.isEmpty) return _coordLabel(lat, lng);
      return parts.take(2).join(', ');
    } catch (_) {
      return _coordLabel(lat, lng);
    }
  }

  String _coordLabel(double lat, double lng) {
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
