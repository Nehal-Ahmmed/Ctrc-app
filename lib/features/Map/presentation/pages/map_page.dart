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
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

}
