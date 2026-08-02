import 'package:latlong2/latlong.dart';

import '../storage/local_store.dart';

/// The last position the device reported, kept between launches.
///
/// A GPS fix takes seconds to arrive, and on a cold start indoors it can take a
/// lot longer than that. Everything on the feed and the map is anchored to
/// "where you are", so without this the app has nothing to ask the backend for
/// until the radio answers. Starting from the last known point means the first
/// screen is already populated, and the real fix just corrects it.
///
/// This is a device fact, not an account one: it stays put across sign-out,
/// the same way the phone's own location does.
class LastKnownLocation {
  LastKnownLocation._();

  /// Older than this and the point is treated as unknown. A week-old position
  /// is more likely to be a different city than a useful starting guess.
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
