import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../domain/models/map_scope.dart';

/// Map services that are also exposed as entries in the app drawer.
enum MapAction {
  recenter,
  openSearch,
  reportIncident,
  openRoutePlanner,
  openAreaAlerts,
  openRouteAlerts,
  clearRoute;

  String get title => switch (this) {
        MapAction.recenter => 'My current location',
        MapAction.openSearch => 'Search a place',
        MapAction.reportIncident => 'Report an incident',
        MapAction.openRoutePlanner => 'Plan a route',
        MapAction.openAreaAlerts => 'Alerts in this area',
        MapAction.openRouteAlerts => 'Alerts along my route',
        MapAction.clearRoute => 'Clear route',
      };

  String get subtitle => switch (this) {
        MapAction.recenter => 'Snap the pointer back to where you are',
        MapAction.openSearch => 'Jump to any place or institution',
        MapAction.reportIncident =>
          'File one here, or long-press the map to pick a spot',
        MapAction.openRoutePlanner => 'Road status from A to B',
        MapAction.openAreaAlerts => 'Incidents inside the selected radius',
        MapAction.openRouteAlerts => 'Incidents within 2 km of the road',
        MapAction.clearRoute => 'Remove the drawn route',
      };

  IconData get icon => switch (this) {
        MapAction.recenter => Icons.my_location,
        MapAction.openSearch => Icons.search,
        MapAction.reportIncident => Icons.add_alert,
        MapAction.openRoutePlanner => Icons.alt_route,
        MapAction.openAreaAlerts => Icons.notifications_active_outlined,
        MapAction.openRouteAlerts => Icons.report_gmailerrorred_outlined,
        MapAction.clearRoute => Icons.layers_clear,
      };
}

/// A one-shot instruction for the map page. [seq] makes every dispatch unique
/// so repeating the same action still fires.
class MapCommand {
  final MapAction action;
  final int seq;

  const MapCommand(this.action, this.seq);
}

class MapCommandController extends StateNotifier<MapCommand?> {
  MapCommandController() : super(null);

  int _seq = 0;

  void dispatch(MapAction action) {
    state = MapCommand(action, ++_seq);
  }

  void consume() => state = null;
}

/// Commands sent from the drawer (or anywhere else) to the map page.
final mapCommandProvider =
    StateNotifierProvider<MapCommandController, MapCommand?>(
  (ref) => MapCommandController(),
);

/// The currently selected area scope, shared between the map's option bar and
/// the drawer so both stay in sync.
///
/// Starts from the "Report Radius" preference in Settings; the scope bar can
/// still override it for the session.
final mapScopeProvider = StateProvider<MapScope>((ref) {
  final radiusKm = ref.read(settingsProvider).reportRadius;
  if (radiusKm <= 2) return MapScope.radius2km;
  if (radiusKm <= 5) return MapScope.radius5km;
  return MapScope.radius10km;
});

/// Number of alerts currently visible in the selected area — surfaced in the
/// drawer so the badge is readable without opening the map.
final mapAreaAlertCountProvider = StateProvider<int>((ref) => 0);

/// Number of alerts along the active route, or `null` when no route is drawn.
final mapRouteAlertCountProvider = StateProvider<int?>((ref) => null);
