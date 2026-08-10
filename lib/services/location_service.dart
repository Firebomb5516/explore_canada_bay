import 'package:geolocator/geolocator.dart';

class LocalPosition {
  const LocalPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class LocationAccessException implements Exception {
  const LocationAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Provides foreground-only location access for sorting nearby local places.
class LocationService {
  const LocationService();

  Future<LocalPosition> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationAccessException(
        'Location services are off. Turn them on to sort places near you.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationAccessException(
        'Location access was not allowed. You can still browse every place.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationAccessException(
        'Location is blocked for this app. Enable it in device settings to use nearby sorting.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return LocalPosition(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  double distanceMetres(
    LocalPosition origin, {
    required double latitude,
    required double longitude,
  }) {
    return Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      latitude,
      longitude,
    );
  }
}
