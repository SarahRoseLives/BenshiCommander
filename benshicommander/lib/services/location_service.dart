import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  Future<geo.Position?> getCurrentLocation() async {
    if (!await _handlePermission()) {
      throw Exception('Location permission not granted.');
    }
    return await geo.Geolocator.getCurrentPosition(desiredAccuracy: geo.LocationAccuracy.high);
  }

  Stream<geo.Position> getLocationStream({int distanceFilter = 100}) {
    return geo.Geolocator.getPositionStream(
      locationSettings: geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }

  Future<bool> _handlePermission() async {
    PermissionStatus status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }
    return status.isGranted;
  }

  // Calculate distance in miles between two coordinates
  double getDistanceInMiles(double lat1, double lon1, double lat2, double lon2) {
    final distanceInMeters = geo.Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distanceInMeters * 0.000621371;
  }
}