import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'geo_bounds.dart';

class PlaceSuggestion {
  
  final String title;

  final String subtitle;
  final LatLng point;
  final GeoBounds? bounds;

  final String? category;
  final String? kind;

  const PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.point,
    this.bounds,
    this.category,
    this.kind,
  });

  factory PlaceSuggestion.fromNominatim(Map<String, dynamic> json) {
    final display = (json['display_name'] as String?) ?? '';
    final parts = display.split(',').map((e) => e.trim()).toList();
    final explicitName = (json['name'] as String?)?.trim();

    final title = (explicitName != null && explicitName.isNotEmpty)
        ? explicitName
        : (parts.isNotEmpty ? parts.first : display);

    return PlaceSuggestion(
      title: title.isEmpty ? display : title,
      subtitle: display,
      point: LatLng(
        double.parse('${json['lat']}'),
        double.parse('${json['lon']}'),
      ),
      bounds: GeoBounds.fromNominatim(json['boundingbox']),
      category: json['class'] as String?,
      kind: json['type'] as String?,
    );
  }

  static PlaceSuggestion? tryParseCoordinates(String input) {
    final match = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*[, ]\s*(-?\d+(?:\.\d+)?)\s*$')
        .firstMatch(input);
    if (match == null) return null;

    final lat = double.parse(match.group(1)!);
    final lng = double.parse(match.group(2)!);
    if (lat.abs() > 90 || lng.abs() > 180) return null;

    return PlaceSuggestion(
      title: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
      subtitle: 'Coordinates',
      point: LatLng(lat, lng),
      category: 'coordinates',
    );
  }

  IconData get icon => switch (category) {
        'coordinates' => Icons.gps_fixed,
        'amenity' => Icons.storefront,
        'building' => Icons.apartment,
        'highway' => Icons.route,
        'railway' => Icons.train,
        'aeroway' => Icons.flight,
        'shop' => Icons.shopping_bag,
        'tourism' => Icons.photo_camera,
        'place' => Icons.location_city,
        'boundary' => Icons.map,
        _ => Icons.place_outlined,
      };
}
