import 'dart:math';

/// Turns a point on the map into a Firebase topic name.
///
/// The whole nearby-alert feature rests on this one string. A phone subscribes
/// to the cells around itself; the backend publishes a new report to the single
/// cell it falls in; Firebase does the matching. Nothing about who is standing
/// where ever has to be stored on the server.
///
/// Mirrored by `GeoTopic.java` on the backend. Change one, change both, or the
/// two sides stop agreeing on what "near me" means.
class GeoTopic {
  GeoTopic._();

  /// A tenth of a degree — a little over 11 km north to south.
  static const double cellSize = 0.1;

  /// Keeps a wide radius from turning into hundreds of subscribe calls.
  static const int maxSteps = 2;

  /// The cell a single point falls in.
  static String of(double latitude, double longitude) =>
      'geo_${_part(latitude)}_${_part(longitude)}';

  /// Topic names may not contain a minus sign, so southern and western cells
  /// get an `m` instead.
  static String _part(double value) {
    final cell = (value / cellSize).floor();
    return cell < 0 ? 'm${-cell}' : '$cell';
  }

  /// Every cell within [radiusKm] of the point, the one it sits in included.
  ///
  /// Cells are square and a report only has to land in one of them, so the
  /// covered area is a little wider than the circle asked for. Erring outward
  /// is the right way round: a missed alert is worse than a slightly distant
  /// one.
  static Set<String> covering(
    double latitude,
    double longitude,
    double radiusKm,
  ) {
    const kmPerDegreeLatitude = 111.32;
    final kmPerDegreeLongitude =
        kmPerDegreeLatitude * cos(latitude * pi / 180).abs();

    final latitudeSteps = _steps(radiusKm, kmPerDegreeLatitude);
    final longitudeSteps = _steps(radiusKm, kmPerDegreeLongitude);

    final topics = <String>{};
    for (var i = -latitudeSteps; i <= latitudeSteps; i++) {
      for (var j = -longitudeSteps; j <= longitudeSteps; j++) {
        topics.add(of(latitude + i * cellSize, longitude + j * cellSize));
      }
    }
    return topics;
  }

  static int _steps(double radiusKm, double kmPerDegree) {
    // Near the poles a degree of longitude shrinks to nothing; fall back to the
    // cap rather than dividing by something close to zero.
    if (kmPerDegree < 1) return maxSteps;
    final steps = (radiusKm / kmPerDegree / cellSize).ceil();
    if (steps < 1) return 1;
    return steps > maxSteps ? maxSteps : steps;
  }
}
