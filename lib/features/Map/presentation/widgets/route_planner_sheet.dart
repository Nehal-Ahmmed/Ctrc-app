import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../data/datasources/geocoding_datasource.dart';
import 'place_autocomplete_field.dart';

/// A confirmed from → to pair, handed back to the map to be routed.
class RouteRequest {
  final LatLng from;
  final String fromLabel;
  final LatLng to;
  final String toLabel;

  const RouteRequest({
    required this.from,
    required this.fromLabel,
    required this.to,
    required this.toLabel,
  });
}

/// Google-Maps style directions sheet: pick a start and a destination (both
/// with suggestions), then hit Done to draw the road.
class RoutePlannerSheet extends StatefulWidget {
  final GeocodingDataSource geocoder;
  final LatLng? currentLocation;
  final RouteRequest? initial;

  const RoutePlannerSheet({
    super.key,
    required this.geocoder,
    this.currentLocation,
    this.initial,
  });

  static Future<RouteRequest?> show(
    BuildContext context, {
    required GeocodingDataSource geocoder,
    LatLng? currentLocation,
    RouteRequest? initial,
  }) {
    return showModalBottomSheet<RouteRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoutePlannerSheet(
        geocoder: geocoder,
        currentLocation: currentLocation,
        initial: initial,
      ),
    );
  }

  @override
  State<RoutePlannerSheet> createState() => _RoutePlannerSheetState();
}

class _RoutePlannerSheetState extends State<RoutePlannerSheet> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  LatLng? _from;
  LatLng? _to;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _from = initial.from;
      _to = initial.to;
      _fromController.text = initial.fromLabel;
      _toController.text = initial.toLabel;
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _useCurrentLocation() {
    final here = widget.currentLocation;
    if (here == null) {
      AppToast.warning(context, 'Still waiting for a GPS fix');
      return;
    }
    setState(() => _from = here);
    _fromController.text = 'My current location';
    FocusScope.of(context).unfocus();
  }

  void _swap() {
    final fromPoint = _from;
    final fromText = _fromController.text;
    setState(() {
      _from = _to;
      _to = fromPoint;
    });
    _fromController.text = _toController.text;
    _toController.text = fromText;
  }

  void _submit() {
    if (_from == null || _to == null) return;
    Navigator.pop(
      context,
      RouteRequest(
        from: _from!,
        fromLabel: _fromController.text.trim().isEmpty
            ? 'Start'
            : _fromController.text.trim(),
        to: _to!,
        toLabel: _toController.text.trim().isEmpty
            ? 'Destination'
            : _toController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _from != null && _to != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[350],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Text(
                    'Plan your route',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 2, 20, 10),
                  child: Text(
                    'We check reported incidents within 2 km of the road and '
                    'colour it accordingly.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _fieldShell(
                              child: PlaceAutocompleteField(
                                controller: _fromController,
                                geocoder: widget.geocoder,
                                hintText: 'Choose starting point',
                                biasTowards: widget.currentLocation,
                                prefixIcon: const Icon(
                                  Icons.trip_origin,
                                  color: Color(0xFF1A73E8),
                                  size: 20,
                                ),
                                onSelected: (place) =>
                                    setState(() => _from = place.point),
                                onCleared: () => setState(() => _from = null),
                                leadingShortcut: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                    child: ActionChip(
                                      avatar: const Icon(Icons.my_location,
                                          size: 16),
                                      label: const Text('Use my location'),
                                      onPressed: _useCurrentLocation,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _fieldShell(
                              child: PlaceAutocompleteField(
                                controller: _toController,
                                geocoder: widget.geocoder,
                                hintText: 'Choose destination',
                                biasTowards: widget.currentLocation,
                                prefixIcon: const Icon(
                                  Icons.location_on,
                                  color: Color(0xFFD93025),
                                  size: 20,
                                ),
                                onSelected: (place) =>
                                    setState(() => _to = place.point),
                                onCleared: () => setState(() => _to = null),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Swap',
                        onPressed: _swap,
                        icon: const Icon(Icons.swap_vert),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: canSubmit ? _submit : null,
                          icon: const Icon(Icons.directions),
                          label: const Text('Done'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
