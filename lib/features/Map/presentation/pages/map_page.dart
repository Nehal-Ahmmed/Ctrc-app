import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ctrc/features/Report/data/datasources/report_remote_datasource.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/presentation/widgets/create_report_bottom_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng? _selectedLocation;
  List<ReportModel> _nearbyReports = [];
  bool _isLoading = false;
  final ReportRemoteDataSource _remoteDataSource = ReportRemoteDataSourceImpl();

  final MapController _mapController = MapController();

  Future<void> _fetchNearbyReports(LatLng location) async {
    setState(() {
      _isLoading = true;
      _selectedLocation = location;
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
              onTap: (tapPosition, point) {
                _fetchNearbyReports(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ctrc.app', // Adjusted based on standard convention
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    // The selected location marker
                    Marker(
                      point: _selectedLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 50,
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
                    }).whereType<Marker>().toList(),
                  ],
                ),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          // Helper text container
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: const Text(
                'Tap anywhere on the map to find reports within a 5km radius.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          )
        ],
      ),
      floatingActionButton: _selectedLocation != null
          ? FloatingActionButton.extended(
              onPressed: _onFabPressed,
              icon: const Icon(Icons.add_alert),
              label: const Text('Create Report Here'),
            )
          : null,
    );
  }

  void _onFabPressed() {
    if (_nearbyReports.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Incidents Nearby'),
          content: const Text(
              'There are already incidents reported nearby. Would you like to link your report to an existing incident or create a completely new one?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showParentSelectionDialog();
              },
              child: const Text('Link to Existing'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openCreateReportSheet(parentReportId: null);
              },
              child: const Text('Create New'),
            ),
          ],
        ),
      );
    } else {
      _openCreateReportSheet(parentReportId: null);
    }
  }

  void _showParentSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select Incident to Link'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _nearbyReports.length,
              itemBuilder: (context, index) {
                final report = _nearbyReports[index];
                return ListTile(
                  title: Text(report.title),
                  subtitle: Text(report.category),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openCreateReportSheet(parentReportId: report.reportId);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _openCreateReportSheet({int? parentReportId}) async {
    if (_selectedLocation == null) return;
    
    // Import needed dynamically or put at top. I will add the import at the top of the file.
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CreateReportBottomSheet(
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        parentReportId: parentReportId,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully!')),
      );
      _fetchNearbyReports(_selectedLocation!);
    }
  }
}
