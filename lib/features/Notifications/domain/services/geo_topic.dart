import 'dart:math';

class GeoTopic {
  GeoTopic._();

  static const double cellSize = 0.1;

  static const int maxSteps = 2;

  static String of(double latitude, double longitude) =>
      'geo_${_part(latitude)}_${_part(longitude)}';

  static String _part(double value) {
    final cell = (value / cellSize).floor();
    return cell < 0 ? 'm${-cell}' : '$cell';
  }

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
    
    if (kmPerDegree < 1) return maxSteps;
    final steps = (radiusKm / kmPerDegree / cellSize).ceil();
    if (steps < 1) return 1;
    return steps > maxSteps ? maxSteps : steps;
  }
}
