import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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
