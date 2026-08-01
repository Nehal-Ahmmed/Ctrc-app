import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../Auth/presentation/providers/auth_provider.dart';
import '../../../Report/data/datasources/report_remote_datasource.dart';
import '../../../Report/domain/models/report_model.dart';
import '../../../Report/presentation/widgets/create_report_bottom_sheet.dart';
import '../../data/datasources/geo_request_cache.dart';
import '../../data/datasources/geocoding_datasource.dart';
import '../../data/datasources/routing_datasource.dart';
import '../../domain/models/map_scope.dart';
import '../../domain/models/place_suggestion.dart';
import '../../domain/models/route_models.dart';
import '../../domain/services/incident_severity.dart';
import '../../domain/services/route_hazard_analyzer.dart';
import '../../domain/utils/geo_utils.dart';
import '../providers/map_controls_provider.dart';
import '../widgets/alert_list_sheet.dart';
import '../widgets/live_location_pointer.dart';
import '../widgets/place_autocomplete_field.dart';
import '../widgets/route_planner_sheet.dart';
import '../widgets/route_summary_card.dart';
import '../widgets/scope_filter_bar.dart';

/// What the camera is currently glued to.
enum _CameraMode {
  /// Following the live GPS pointer (the default).
  followMe,

  /// Locked onto a place picked from the search bar.
  pinnedToPlace,

  /// The user panned away; nothing is auto-centred until they hit recenter.
  free,
}

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final MapController _mapController = MapController();
  final ReportRemoteDataSource _reports = ReportRemoteDataSourceImpl();
  final GeocodingDataSource _geocoder = GeocodingDataSource();
  final RoutingDataSource _router = RoutingDataSource();

  /// Id of the signed-in user, so the backend can return saved / vote state
  /// alongside each report. Null while browsing anonymously.
  int? get _viewerUserId {
    final user = ref.read(authProvider).user;
    if (user == null) return null;
    return int.tryParse(user.user_id);
  }

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // ---- live location -------------------------------------------------------
  StreamSubscription<Position>? _positionSub;
  LatLng? _currentLocation;
  double? _accuracyMeters;

  /// Unwrapped heading so the pointer animates the short way round 0°/360°.
  double? _smoothHeading;
  double _lastRawHeading = 0;
  bool _locationDenied = false;

  // ---- camera / anchor -----------------------------------------------------
  _CameraMode _cameraMode = _CameraMode.followMe;
  PlaceSuggestion? _pinnedPlace;
  bool _mapReady = false;

  // ---- area scope ----------------------------------------------------------
  ResolvedArea? _area;
  bool _isResolvingArea = false;
  bool _isLoadingAlerts = false;
  List<ReportModel> _areaReports = const [];
  int _areaRequestId = 0;

  // ---- routing -------------------------------------------------------------
  RouteAnalysis? _routeAnalysis;
  RouteRequest? _lastRouteRequest;
  bool _isRouting = false;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();

    // The drawer may have dispatched a command before this branch was first
    // built, in which case ref.listen would never see the transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(mapCommandProvider);
      if (pending != null) _handleCommand(pending);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Location
  // ===========================================================================

  Future<void> _startLocationTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _locationDenied = true);
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locationDenied = true);
      return;
    }

    if (mounted) setState(() => _locationDenied = false);

    try {
      final initial = await Geolocator.getCurrentPosition();
      _onPosition(initial, recenter: true);
    } catch (_) {
      // No fix yet; the stream below will deliver one when it arrives.
    }

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen(
      (position) => _onPosition(position),
      onError: (_) {},
    );
  }

  void _onPosition(Position position, {bool recenter = false}) {
    if (!mounted) return;

    final point = LatLng(position.latitude, position.longitude);
    final isFirstFix = _currentLocation == null;

    setState(() {
      _currentLocation = point;
      _accuracyMeters = position.accuracy;
      _updateHeading(position.heading);
    });

    if (recenter || isFirstFix) {
      _cameraMode = _CameraMode.followMe;
      _moveCamera(point, zoom: 15.5);
      _refreshArea(force: true);
      return;
    }

    if (_cameraMode == _CameraMode.followMe) {
      _moveCamera(point);
      // Re-query only once the pointer has drifted meaningfully inside the
      // current scope, so a slow walk does not hammer the backend.
      final area = _area;
      if (area == null ||
          GeoUtils.metersBetween(area.center, point) >
              (area.radiusMeters * 0.25).clamp(150, 4000)) {
        _refreshArea();
      }
    }
  }

  /// Keeps [_smoothHeading] continuous across the 359° → 1° wrap so the cone
  /// rotates the short way instead of spinning all the way round.
  void _updateHeading(double rawHeading) {
    if (rawHeading.isNaN || rawHeading < 0) return;

    final previous = _smoothHeading;
    if (previous == null) {
      _smoothHeading = rawHeading;
      _lastRawHeading = rawHeading;
      return;
    }

    var delta = rawHeading - _lastRawHeading;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;

    _smoothHeading = previous + delta;
    _lastRawHeading = rawHeading;
  }

  // ===========================================================================
  // Camera
  // ===========================================================================

  void _moveCamera(LatLng target, {double? zoom}) {
    if (!_mapReady) return;
    _mapController.move(target, zoom ?? _mapController.camera.zoom);
  }

  /// Where alerts and the blue circle are anchored: the pinned place if there
  /// is one, otherwise the live pointer.
  LatLng? get _anchor => _pinnedPlace?.point ?? _currentLocation;

  void _recenterOnMe() {
    final here = _currentLocation;
    if (here == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationDenied
              ? 'Location permission is off — enable it in settings'
              : 'Still waiting for a GPS fix...'),
        ),
      );
      _startLocationTracking();
      return;
    }

    setState(() {
      _pinnedPlace = null;
      _searchController.clear();
      _cameraMode = _CameraMode.followMe;
    });
    _moveCamera(here, zoom: 15.5);
    _refreshArea(force: true);
  }

  void _onPlaceSelected(PlaceSuggestion place) {
    setState(() {
      _pinnedPlace = place;
      _cameraMode = _CameraMode.pinnedToPlace;
    });
    _moveCamera(place.point, zoom: 14);
    _refreshArea(force: true);
  }

  void _onSearchCleared() {
    setState(() => _pinnedPlace = null);
    final here = _currentLocation;
    if (here != null) {
      setState(() => _cameraMode = _CameraMode.followMe);
      _moveCamera(here, zoom: 15.5);
    }
    _refreshArea(force: true);
  }

  void _onCameraChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture || _cameraMode == _CameraMode.free) return;

    final anchor = _anchor;
    if (anchor == null) return;

    // Pinching to zoom keeps the anchor centred, so only a real pan unlocks.
    if (GeoUtils.metersBetween(camera.center, anchor) > 60) {
      setState(() => _cameraMode = _CameraMode.free);
    }
  }

  // ===========================================================================
  // Area scope + alerts
  // ===========================================================================

  Future<void> _onScopeSelected(MapScope scope) async {
    ref.read(mapScopeProvider.notifier).state = scope;
    await _refreshArea(force: true, frameCamera: true);
  }

  Future<void> _refreshArea({
    bool force = false,
    bool frameCamera = false,
  }) async {
    final anchor = _anchor;
    if (anchor == null) return;

    final scope = ref.read(mapScopeProvider);
    final requestId = ++_areaRequestId;

    if (scope.isAdministrative) {
      setState(() => _isResolvingArea = true);
    }

    final area = scope.isAdministrative
        ? await _geocoder.resolveArea(at: anchor, scope: scope)
        : ResolvedArea(
            scope: scope,
            center: anchor,
            radiusMeters: scope.fixedRadiusMeters!,
          );

    if (!mounted || requestId != _areaRequestId) return;

    setState(() {
      _area = area;
      _isResolvingArea = false;
    });

    if (frameCamera) {
      _moveCamera(
        area.center,
        zoom: GeoUtils.zoomForRadius(
          area.radiusMeters,
          area.center.latitude,
          viewportPixels: MediaQuery.of(context).size.width,
        ),
      );
    }

    await _loadAreaAlerts(area, requestId: requestId, force: force);
  }

  Future<void> _loadAreaAlerts(
    ResolvedArea area, {
    required int requestId,
    bool force = false,
  }) async {
    setState(() => _isLoadingAlerts = true);

    try {
      final fetched = await _reports.getNearbyReports(
        lat: area.center.latitude,
        lng: area.center.longitude,
        radius: area.radiusKm,
        userId: _viewerUserId,
      );

      if (!mounted || requestId != _areaRequestId) return;

      final visible = fetched.where((report) {
        final location = report.location;
        if (location == null) return false;
        if (!IncidentSeverity.isActive(report)) return false;
        return area.includes(LatLng(location.latitude, location.longitude));
      }).toList();

      setState(() {
        _areaReports = visible;
        _isLoadingAlerts = false;
      });
      ref.read(mapAreaAlertCountProvider.notifier).state = visible.length;
    } catch (e) {
      if (!mounted || requestId != _areaRequestId) return;
      setState(() => _isLoadingAlerts = false);
      if (force) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load alerts: $e')),
        );
      }
    }
  }

  // ===========================================================================
  // Routing
  // ===========================================================================

  Future<void> _openRoutePlanner() async {
    final request = await RoutePlannerSheet.show(
      context,
      geocoder: _geocoder,
      currentLocation: _currentLocation,
      initial: _lastRouteRequest,
    );
    if (request == null || !mounted) return;
    await _buildRoute(request);
  }

  Future<void> _buildRoute(RouteRequest request) async {
    setState(() {
      _isRouting = true;
      _lastRouteRequest = request;
    });

    try {
      final plans = await _router.route(from: request.from, to: request.to);
      if (!mounted) return;

      // Built per request so it always carries the current signed-in user.
      final analyzer = RouteHazardAnalyzer(
        reports: _reports,
        viewerUserId: _viewerUserId,
      );

      final analysis = await analyzer.analyze(
        plan: plans.first,
        alternatives: plans.skip(1).toList(),
        fromLabel: request.fromLabel,
        toLabel: request.toLabel,
      );
      if (!mounted) return;

      setState(() {
        _routeAnalysis = analysis;
        _isRouting = false;
        _cameraMode = _CameraMode.free;
      });
      ref.read(mapRouteAlertCountProvider.notifier).state =
          analysis.hazards.length;

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(analysis.plan.points),
          padding: const EdgeInsets.fromLTRB(40, 160, 40, 260),
        ),
      );

      if (analysis.hazards.isNotEmpty) _showRouteAlerts();
    } on GeoServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isRouting = false);
      _showNotice(
        e.message,
        isTransient: e.isRateLimited,
        onRetry: () => _buildRoute(request),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRouting = false);
      _showNotice('Could not build the route: $e');
    }
  }

  /// One place for user-facing map notices, so a temporary rate limit reads as
  /// "try again in a moment" instead of looking like a failure.
  void _showNotice(
    String message, {
    bool isTransient = false,
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isTransient ? Icons.hourglass_bottom : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor:
              isTransient ? const Color(0xFFB26A00) : const Color(0xFF323232),
          duration: Duration(seconds: isTransient ? 6 : 4),
          action: onRetry == null
              ? null
              : SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: onRetry,
                ),
        ),
      );
  }

  void _clearRoute() {
    setState(() => _routeAnalysis = null);
    ref.read(mapRouteAlertCountProvider.notifier).state = null;
  }

  // ===========================================================================
  // Alert sheets
  // ===========================================================================

  void _showAreaAlerts() {
    final area = _area;
    final anchor = _anchor;
    if (anchor == null) return;

    final MapScope scope = area?.scope ?? ref.read(mapScopeProvider);

    final measured = _areaReports.map((report) {
      final point =
          LatLng(report.location!.latitude, report.location!.longitude);
      return (
        report: report,
        distance: GeoUtils.metersBetween(anchor, point),
      );
    }).toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    AlertListSheet.show(
      context,
      title: 'Alerts in this area',
      subtitle: area?.description ?? scope.label,
      entries: measured
          .map((e) => AlertEntry(
                report: e.report,
                level: IncidentSeverity.of(e.report),
                distanceLabel:
                    '${GeoUtils.formatDistance(e.distance)} away',
              ))
          .toList(),
      onOpenReport: _openReport,
      emptyMessage:
          'Nothing reported inside ${scope.label.toLowerCase()} right now.',
    );
  }

  void _showRouteAlerts() {
    final analysis = _routeAnalysis;
    if (analysis == null) return;

    AlertListSheet.show(
      context,
      title: 'Alerts along your route',
      subtitle: '${analysis.fromLabel} → ${analysis.toLabel} · '
          'within 2 km of the road',
      entries: analysis.hazards
          .map((hazard) => AlertEntry(
                report: hazard.report,
                level: hazard.level,
                distanceLabel: hazard.offsetLabel,
              ))
          .toList(),
      onOpenReport: _openReport,
      emptyMessage: 'No incidents reported within 2 km of this road.',
    );
  }

  void _openReport(ReportModel report) {
    Navigator.of(context).pop(); // close the alert sheet first
    context.push('/report/${report.reportId}', extra: {
      'report': report,
      'viewerLocation': _currentLocation,
    });
  }

  // ===========================================================================
  // Reporting
  // ===========================================================================

  /// Where a long-press dropped a pin, so an incident can be filed somewhere
  /// other than the reporter's own GPS position (the roadmap's "drop a pin to
  /// select a location").
  LatLng? _reportPin;

  void _onMapLongPress(TapPosition tapPosition, LatLng point) {
    setState(() => _reportPin = point);
    _openReportSheet(point);
  }

  Future<void> _openReportSheet(LatLng? at) async {
    final point = at ?? _reportPin ?? _currentLocation;
    if (point == null) {
      _showNotice(
        'No location yet — long-press the map to pick the spot, or wait for a '
        'GPS fix.',
      );
      return;
    }

    if (ref.read(authProvider).user == null) {
      _showNotice('Please log in to report an incident');
      return;
    }

    final result = await showModalBottomSheet<CreateReportResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CreateReportBottomSheet(
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );

    if (!mounted) return;
    setState(() => _reportPin = null);
    if (result == null) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    await _refreshArea(force: true);
  }

  // ===========================================================================
  // Drawer commands
  // ===========================================================================

  int _lastHandledSeq = 0;

  void _handleCommand(MapCommand command) {
    if (command.seq <= _lastHandledSeq) return;
    _lastHandledSeq = command.seq;

    switch (command.action) {
      case MapAction.recenter:
        _recenterOnMe();
      case MapAction.openSearch:
        _searchFocus.requestFocus();
      case MapAction.reportIncident:
        _openReportSheet(null);
      case MapAction.openRoutePlanner:
        _openRoutePlanner();
      case MapAction.openAreaAlerts:
        _showAreaAlerts();
      case MapAction.openRouteAlerts:
        if (_routeAnalysis == null) {
          _openRoutePlanner();
        } else {
          _showRouteAlerts();
        }
      case MapAction.clearRoute:
        _clearRoute();
    }
    ref.read(mapCommandProvider.notifier).consume();
  }

  // ===========================================================================
  // Build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    ref.listen<MapCommand?>(mapCommandProvider, (previous, next) {
      if (next == null || next.seq <= _lastHandledSeq) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleCommand(next);
      });
    });

    final scope = ref.watch(mapScopeProvider);
    final analysis = _routeAnalysis;

    return Scaffold(
      body: Stack(
        children: [
          _buildMap(analysis),
          if (_isRouting) _buildRoutingOverlay(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopControls(scope),
          ),
          if (analysis == null)
            Positioned(left: 12, bottom: 16, child: _buildAreaAlertPill()),
        ],
      ),
      // Handing the route card to `bottomSheet` lets Scaffold lift the FABs
      // above it automatically.
      bottomSheet: analysis == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: RouteSummaryCard(
                analysis: analysis,
                onShowAlerts: _showRouteAlerts,
                onClear: _clearRoute,
                onEdit: _openRoutePlanner,
              ),
            ),
      floatingActionButton: _buildFabColumn(),
    );
  }

  Widget _buildMap(RouteAnalysis? analysis) {
    final here = _currentLocation;
    final area = _area;
    final pinned = _pinnedPlace;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: here ?? const LatLng(23.8103, 90.4125),
        initialZoom: 13,
        maxZoom: 18,
        minZoom: 3,
        onMapReady: () {
          _mapReady = true;
          final anchor = _anchor;
          if (anchor != null) _mapController.move(anchor, 15.5);
          _refreshArea(force: true);
        },
        onPositionChanged: _onCameraChanged,
        onLongPress: _onMapLongPress,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ctrc.app',
        ),

        // The scope circle: this is the area alerts are pulled from.
        if (area != null && analysis == null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: area.center,
                radius: area.radiusMeters,
                useRadiusInMeter: true,
                color: const Color(0xFF1A73E8).withValues(alpha: 0.10),
                borderColor: const Color(0xFF1A73E8).withValues(alpha: 0.45),
                borderStrokeWidth: 2,
              ),
            ],
          ),

        // GPS accuracy halo.
        if (here != null && _accuracyMeters != null && _accuracyMeters! > 0)
          CircleLayer(
            circles: [
              CircleMarker(
                point: here,
                radius: _accuracyMeters!.clamp(10, 200),
                useRadiusInMeter: true,
                color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                borderStrokeWidth: 0,
                borderColor: Colors.transparent,
              ),
            ],
          ),

        if (analysis != null) ..._buildRouteLayers(analysis),

        MarkerLayer(
          markers: [
            ..._buildIncidentMarkers(analysis),
            if (_reportPin != null)
              Marker(
                point: _reportPin!,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: const Icon(
                  Icons.add_location_alt,
                  color: Color(0xFFD93025),
                  size: 40,
                ),
              ),
            if (pinned != null)
              Marker(
                point: pinned.point,
                width: 48,
                height: 48,
                alignment: Alignment.topCenter,
                child: const SearchedPlaceMarker(),
              ),
            if (here != null)
              Marker(
                point: here,
                width: 72,
                height: 72,
                child: LiveLocationPointer(
                  headingDegrees: _smoothHeading,
                  isStale: _cameraMode == _CameraMode.pinnedToPlace,
                ),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildRouteLayers(RouteAnalysis analysis) {
    return [
      // Discarded alternatives, drawn faintly underneath.
      if (analysis.alternatives.isNotEmpty)
        PolylineLayer(
          polylines: analysis.alternatives
              .map((plan) => Polyline(
                    points: plan.points,
                    color: Colors.grey.withValues(alpha: 0.55),
                    strokeWidth: 5,
                    borderColor: Colors.white.withValues(alpha: 0.6),
                    borderStrokeWidth: 1,
                  ))
              .toList(),
        ),
      // The chosen route, one polyline per congestion-coloured chunk.
      PolylineLayer(
        polylines: analysis.segments
            .map((segment) => Polyline(
                  points: segment.points,
                  color: segment.level.color,
                  strokeWidth: 7,
                  borderColor: Colors.white,
                  borderStrokeWidth: 1.5,
                ))
            .toList(),
      ),
    ];
  }

  List<Marker> _buildIncidentMarkers(RouteAnalysis? analysis) {
    // While routing, the corridor hazards replace the radius alerts so the
    // map does not show two competing incident sets.
    final entries = analysis != null
        ? analysis.hazards
            .map((h) => (report: h.report, level: h.level))
            .toList()
        : _areaReports
            .map((r) => (report: r, level: IncidentSeverity.of(r)))
            .toList();

    return entries
        .where((e) => e.report.location != null)
        .map((entry) {
      final location = entry.report.location!;
      return Marker(
        point: LatLng(location.latitude, location.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => context.push(
            '/report/${entry.report.reportId}',
            extra: {
              'report': entry.report,
              'viewerLocation': _currentLocation,
            },
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: entry.level.color, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(entry.level.icon, color: entry.level.color, size: 20),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTopControls(MapScope scope) {
    return SafeArea(
      bottom: false,
      child: Column(
        // Keep the column tight so the rest of the map stays touchable.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Material(
              elevation: 5,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(28),
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              child: PlaceAutocompleteField(
                controller: _searchController,
                focusNode: _searchFocus,
                geocoder: _geocoder,
                hintText: 'Search a place or institution',
                biasTowards: _currentLocation,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.search, color: Color(0xFF1A73E8)),
                ),
                onSelected: _onPlaceSelected,
                onCleared: _onSearchCleared,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ScopeFilterBar(
            selected: scope,
            onSelected: _onScopeSelected,
            isResolving: _isResolvingArea,
          ),
        ],
      ),
    );
  }

  Widget _buildAreaAlertPill() {
    final count = _areaReports.length;
    final worst = _areaReports.isEmpty
        ? CongestionLevel.clear
        : _areaReports
            .map(IncidentSeverity.of)
            .reduce((a, b) => a.rank >= b.rank ? a : b);

    return Material(
      elevation: 6,
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _showAreaAlerts,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoadingAlerts)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(worst.icon, size: 20, color: worst.color),
              const SizedBox(width: 8),
              Text(
                _isLoadingAlerts
                    ? 'Loading alerts...'
                    : '$count alert${count == 1 ? '' : 's'} · '
                        '${_area?.scope.chipLabel ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.25),
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Finding the road and checking incidents...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFabColumn() {
    final isFollowing = _cameraMode == _CameraMode.followMe;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'map-report',
          onPressed: () => _openReportSheet(null),
          backgroundColor: const Color(0xFFD93025),
          foregroundColor: Colors.white,
          tooltip: 'Report an incident (long-press the map to pick a spot)',
          child: const Icon(Icons.add_alert),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'map-directions',
          onPressed: _openRoutePlanner,
          backgroundColor: const Color(0xFF1A73E8),
          foregroundColor: Colors.white,
          tooltip: 'Plan a route',
          child: const Icon(Icons.directions),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'map-recenter',
          onPressed: _recenterOnMe,
          backgroundColor: Colors.white,
          tooltip: 'Centre on my location',
          child: Icon(
            isFollowing ? Icons.my_location : Icons.location_searching,
            color: isFollowing ? const Color(0xFF1A73E8) : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
