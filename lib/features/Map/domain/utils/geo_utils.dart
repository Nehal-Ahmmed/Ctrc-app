import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const double kEarthRadiusMeters = 6378137.0;

typedef PolylineProjection = ({double offsetMeters, double alongMeters});

class GeoUtils {
  GeoUtils._();

  static const Distance _distance = Distance();

  static double metersBetween(LatLng a, LatLng b) =>
      _distance.as(LengthUnit.Meter, a, b);

  static double distanceToSegment(LatLng p, LatLng a, LatLng b) {
    final lat0 = (a.latitude + b.latitude + p.latitude) / 3 * math.pi / 180;
    final cosLat = math.cos(lat0);

    double px(LatLng q) =>
        q.longitude * math.pi / 180 * cosLat * kEarthRadiusMeters;
    double py(LatLng q) => q.latitude * math.pi / 180 * kEarthRadiusMeters;

    final x = px(p), y = py(p);
    final ax = px(a), ay = py(a);
    final bx = px(b), by = py(b);

    final dx = bx - ax, dy = by - ay;
    final lengthSq = dx * dx + dy * dy;
    if (lengthSq == 0) {
      return math.sqrt((x - ax) * (x - ax) + (y - ay) * (y - ay));
    }

    var t = ((x - ax) * dx + (y - ay) * dy) / lengthSq;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    return math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
  }

  static PolylineProjection projectOnPolyline(LatLng p, List<LatLng> line) {
    if (line.isEmpty) return (offsetMeters: double.infinity, alongMeters: 0);
    if (line.length == 1) {
      return (offsetMeters: metersBetween(p, line.first), alongMeters: 0);
    }

    var best = double.infinity;
    var bestAlong = 0.0;
    var travelled = 0.0;

    for (var i = 0; i < line.length - 1; i++) {
      final a = line[i];
      final b = line[i + 1];
      final segmentLength = metersBetween(a, b);
      final d = distanceToSegment(p, a, b);
      if (d < best) {
        best = d;
        
        final da = metersBetween(p, a);
        final projected = math.sqrt(math.max(0, da * da - d * d));
        bestAlong = travelled + math.min(projected, segmentLength);
      }
      travelled += segmentLength;
    }

    return (offsetMeters: best, alongMeters: bestAlong);
  }

  static double distanceToPolyline(LatLng p, List<LatLng> line) =>
      projectOnPolyline(p, line).offsetMeters;

  static double polylineLength(List<LatLng> line) {
    var total = 0.0;
    for (var i = 0; i < line.length - 1; i++) {
      total += metersBetween(line[i], line[i + 1]);
    }
    return total;
  }

  static List<LatLng> sampleEvery(List<LatLng> line, double spacingMeters) {
    if (line.isEmpty) return const [];
    if (line.length == 1) return [line.first];

    final samples = <LatLng>[line.first];
    var sinceLast = 0.0;

    for (var i = 0; i < line.length - 1; i++) {
      sinceLast += metersBetween(line[i], line[i + 1]);
      if (sinceLast >= spacingMeters) {
        samples.add(line[i + 1]);
        sinceLast = 0;
      }
    }

    if (samples.last != line.last) samples.add(line.last);
    return samples;
  }

  static List<List<LatLng>> chunk(List<LatLng> line, double chunkMeters) {
    if (line.length < 2) return line.isEmpty ? const [] : [line];

    final chunks = <List<LatLng>>[];
    var current = <LatLng>[line.first];
    var accumulated = 0.0;

    for (var i = 0; i < line.length - 1; i++) {
      accumulated += metersBetween(line[i], line[i + 1]);
      current.add(line[i + 1]);
      if (accumulated >= chunkMeters && i < line.length - 2) {
        chunks.add(current);
        current = <LatLng>[line[i + 1]];
        accumulated = 0;
      }
    }

    if (current.length > 1) chunks.add(current);
    return chunks;
  }

  static double bearing(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final deg = math.atan2(y, x) * 180 / math.pi;
    return (deg + 360) % 360;
  }

  static double zoomForRadius(
    double radiusMeters,
    double latitude, {
    double viewportPixels = 360,
  }) {
    final metersPerPixelAtZoom0 =
        156543.03392 * math.cos(latitude * math.pi / 180);
    final required = (radiusMeters * 2.2) / viewportPixels;
    if (required <= 0) return 15;
    final zoom = math.log(metersPerPixelAtZoom0 / required) / math.ln2;
    return zoom.clamp(3.0, 18.0);
  }

  static String formatDistance(double meters) {
    if (meters < 950) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(meters < 9500 ? 1 : 0)} km';
  }

  static String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${d.inMinutes}m';
  }
}
