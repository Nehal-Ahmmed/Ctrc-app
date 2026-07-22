import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:ctrc/features/Report/data/datasources/report_remote_datasource.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/presentation/widgets/create_report_bottom_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LatLng? _currentLocation;
  List<ReportModel> _feedReports = [];
  bool _isLoading = false;
  final ReportRemoteDataSource _remoteDataSource = ReportRemoteDataSourceImpl();
  StreamSubscription<Position>? _positionStreamSub;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // Fetch initial position immediately
    Position initialPosition = await Geolocator.getCurrentPosition();
    _updateLocationAndFetch(initialPosition);

    // Listen to changes (e.g. moving in a car). 
    // distanceFilter: 50 means we only get an update if the user moves > 50 meters
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((Position position) {
      _updateLocationAndFetch(position);
    });
  }

  void _updateLocationAndFetch(Position position) {
    if (!mounted) return;
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
    _fetchFeedData();
  }

  Future<void> _fetchFeedData() async {
    if (_currentLocation == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final reports = await _remoteDataSource.getNearbyReports(
        lat: _currentLocation!.latitude,
        lng: _currentLocation!.longitude,
        radius: 5.0, // 5km
      );
      
      if (mounted) {
        setState(() {
          _feedReports = reports;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching feed: $e')),
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

  void _openCreateReportSheet() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for GPS location...')),
      );
      return;
    }

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CreateReportBottomSheet(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        parentReportId: null, // Initial report
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully!')),
      );
      _fetchFeedData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Local Feed'),
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFeedData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildCreatePostHeader(),
            ),
            if (_isLoading && _feedReports.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_feedReports.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('No incidents reported in your 5km radius.')),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final report = _feedReports[index];
                    return _buildReportCard(report);
                  },
                  childCount: _feedReports.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePostHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[100],
            child: const Icon(Icons.person, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: _openCreateReportSheet,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'What\'s happening nearby?',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(ReportModel report) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red[100],
                  child: const Icon(Icons.warning, color: Colors.red),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Category: ${report.category}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDistance(report),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            if (report.description != null && report.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                report.description!,
                style: const TextStyle(fontSize: 15),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 20),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                    Text('${report.upvoteCount}'),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 20),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                    Text('${report.downvoteCount}'),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.comment_outlined, size: 20),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                    Text('${report.commentCount}'),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(ReportModel report) {
    if (_currentLocation == null || report.location == null) return '';
    final distance = const Distance().as(
      LengthUnit.Meter,
      _currentLocation!,
      LatLng(report.location!.latitude, report.location!.longitude),
    );
    if (distance < 1000) {
      return '${distance.toInt()}m away';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km away';
    }
  }
}
