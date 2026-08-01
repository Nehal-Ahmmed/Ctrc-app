import 'package:latlong2/latlong.dart';

import '../utils/geo_utils.dart';

/// A plain lat/lng rectangle. Kept independent of flutter_map so the domain
/// layer does not depend on the rendering package.
class GeoBounds {
  final double south;
  final double north;
  final double west;
  final double east;

  const GeoBounds({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
  });

  /// Nominatim returns `boundingbox` as `[south, north, west, east]` strings.
  static GeoBounds? fromNominatim(dynamic raw) {
    if (raw is! List || raw.length < 4) return null;
    final values = raw.map((e) => double.tryParse('$e')).toList();
    if (values.any((v) => v == null)) return null;
    return GeoBounds(
      south: values[0]!,
      north: values[1]!,
      west: values[2]!,
      east: values[3]!,
    );
  }

  LatLng get center => LatLng((south + north) / 2, (west + east) / 2);

  /// Radius of the circle that circumscribes this box, in meters.
  double get radiusMeters =>
      GeoUtils.metersBetween(center, LatLng(north, east));

  bool contains(LatLng point) =>
      point.latitude >= south &&
      point.latitude <= north &&
      point.longitude >= west &&
      point.longitude <= east;
}
