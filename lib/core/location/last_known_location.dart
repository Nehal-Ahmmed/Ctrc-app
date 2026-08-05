import 'package:latlong2/latlong.dart';

import '../storage/local_store.dart';

class LastKnownLocation {
  LastKnownLocation._();

  static const maxAge = Duration(days: 3);

  static LatLng? read({LocalStore? store}) {
    final source = store ?? LocalStore.instance;
    final stamped = source.getStamped(StorageKeys.lastKnownLocation);
    if (stamped == null || stamped.isOlderThan(maxAge)) return null;

    final data = stamped.value;
    if (data is! Map) return null;

    final lat = data['lat'];
    final lng = data['lng'];
    if (lat is! num || lng is! num) return null;

    return LatLng(lat.toDouble(), lng.toDouble());
  }

  static Future<void> save(LatLng point, {LocalStore? store}) {
    return (store ?? LocalStore.instance).setStamped(
      StorageKeys.lastKnownLocation,
      {'lat': point.latitude, 'lng': point.longitude},
    );
  }
}
