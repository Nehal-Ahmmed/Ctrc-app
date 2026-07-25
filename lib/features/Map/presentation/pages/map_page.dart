
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ctrc/features/Report/data/datasources/report_remote_datasource.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng? _currentLocation;
  List<ReportModel> _nearbyReports = [];
  bool _isLoading = false;
  final ReportRemoteDataSource _remoteDataSource = ReportRemoteDataSourceImpl();

  final MapController _mapController = MapController();

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  List<LatLng> _routePoints = [];
  bool _isRouting = false;
  String _transportMode = 'driving'; // driving or train (mocked)

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
    
    // Automatically center map and fetch reports for current location
    _mapController.move(_currentLocation!, 13.0);
    _fetchNearbyReports(_currentLocation!);
  }

  Future<void> _fetchNearbyReports(LatLng location) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reports = await _remoteDataSource.getNearbyReports(
        lat: location.latitude,
        lng: location.longitude,
        radius: 5.0, // 5km radius
      );

      setState(() {
        _nearbyReports = reports;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${reports.length} nearby reports within 5km.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching reports: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _calculateRoute() async {
    final startStr = _startController.text.trim();
    final destStr = _destController.text.trim();

    if (startStr.isEmpty || destStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both starting point and destination')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Geocode Start (using simple Nominatim API)
      final startCoords = await _geocode(startStr);
      if (startCoords == null) throw Exception('Could not find starting point');

      // 2. Geocode Dest
      final destCoords = await _geocode(destStr);
      if (destCoords == null) throw Exception('Could not find destination');

      // 3. Fetch Route from OSRM
      final dio = Dio();
      final url = 'http://router.project-osrm.org/route/v1/$_transportMode/${startCoords.longitude},${startCoords.latitude};${destCoords.longitude},${destCoords.latitude}?geometries=geojson';
      
      final response = await dio.get(url);
      if (response.statusCode == 200 && response.data['routes'] != null && response.data['routes'].isNotEmpty) {
        final geometry = response.data['routes'][0]['geometry'];
        final List coordinates = geometry['coordinates'];
        
        setState(() {
          _routePoints = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
          _isRouting = true;
        });

        // Fit bounds
        final bounds = LatLngBounds.fromPoints(_routePoints);
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
      } else {
        throw Exception('No route found');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<LatLng?> _geocode(String query) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 1,
        },
        options: Options(headers: {'User-Agent': 'com.ctrc.app'}),
      );

      if (response.statusCode == 200 && response.data != null && response.data.isNotEmpty) {
        final lat = double.parse(response.data[0]['lat']);
        final lon = double.parse(response.data[0]['lon']);
        return LatLng(lat, lon);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidents Map'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // Initial center on Dhaka
              initialCenter: const LatLng(23.8103, 90.4125),
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ctrc.app', // Adjusted based on standard convention
              ),
              if (_currentLocation != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _currentLocation!,
                      radius: 5000,
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.15),
                      borderColor: Colors.blue.withOpacity(0.5),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Current user location marker (Google Maps style blue dot)
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 5,
                            )
                          ]
                        ),
                      ),
                    ),
                  // Nearby reports markers
                  ..._nearbyReports.map((report) {
                    final lat = report.location?.latitude;
                    final lng = report.location?.longitude;
                    if (lat == null || lng == null) return null;

                    return Marker(
                      point: LatLng(lat, lng),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(report.title),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Category: ${report.category}'),
                                  const SizedBox(height: 8),
                                  Text(report.description ?? 'No description provided.'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                )
                              ],
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.warning_rounded,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    );
                  }).whereType<Marker>(),
                ],
              ),
              if (_isRouting && _routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          
          // Top Routing Panel (Google Maps Style)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _startController,
                      decoration: InputDecoration(
                        hintText: 'Choose starting point',
                        prefixIcon: const Icon(Icons.my_location, color: Colors.blue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.gps_fixed),
                          onPressed: () {
                            if (_currentLocation != null) {
                              _startController.text = '${_currentLocation!.latitude}, ${_currentLocation!.longitude}';
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Waiting for GPS...')));
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _destController,
                      decoration: InputDecoration(
                        hintText: 'Choose destination',
                        prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _transportMode = 'driving';
                              });
                              _calculateRoute();
                            },
                            icon: const Icon(Icons.directions_car),
                            label: const Text('Car'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _transportMode == 'driving' ? Colors.blue : Colors.grey[200],
                              foregroundColor: _transportMode == 'driving' ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _transportMode = 'driving'; // OSRM train not universally supported, fallback to driving for mock
                              });
                              _calculateRoute();
                            },
                            icon: const Icon(Icons.train),
                            label: const Text('Train'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _transportMode == 'train' ? Colors.blue : Colors.grey[200],
                              foregroundColor: _transportMode == 'train' ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentLocation != null) {
            _mapController.move(_currentLocation!, 15.0);
          } else {
            _determinePosition();
          }
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.blue),
      ),
    );
  }
}
