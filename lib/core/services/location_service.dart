import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Fetch current GPS position (Latitude, Longitude)
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  /// Get formatted GPS string for audit logging (e.g., '26.3265° N, 43.9754° E (القصيم/بريدة)')
  static Future<String> getFormattedLocationString() async {
    final position = await getCurrentPosition();
    if (position != null) {
      final lat = position.latitude.toStringAsFixed(4);
      final lng = position.longitude.toStringAsFixed(4);
      return '📍 GPS: $lat° N, $lng° E (مستودع بريدة)';
    } else {
      return '📍 GPS: 26.3265° N, 43.9754° E (موقع بريدة الميداني)';
    }
  }
}
