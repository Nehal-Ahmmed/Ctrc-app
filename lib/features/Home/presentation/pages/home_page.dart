import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:ctrc/features/Report/data/datasources/report_remote_datasource.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/presentation/widgets/create_report_bottom_sheet.dart';
import 'package:ctrc/features/Report/presentation/widgets/report_card_widget.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ctrc/features/Auth/presentation/providers/auth_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  LatLng? _currentLocation;
  List<ReportModel> _feedReports = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  final ReportRemoteDataSource _remoteDataSource = ReportRemoteDataSourceImpl();
  StreamSubscription<Position>? _positionStreamSub;
  
  final List<String> _categories = [
    'All',
    'Road block',
    'Robbery',
    'Accident',
    'Fire',
    'Traffic jam',
    'Riot',
    'Other'
  ];

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
        category: _selectedCategory,
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

  Future<void> _handleVote(ReportModel report, String type, int index) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to vote')),
      );
      return;
    }
    
    // Optimistic update
    setState(() {
       if (type == 'up') {
          _feedReports[index] = report.copyWith(upvoteCount: report.upvoteCount + 1);
       } else {
          _feedReports[index] = report.copyWith(downvoteCount: report.downvoteCount + 1);
       }
    });

    try {
      await _remoteDataSource.voteReport(
        reportId: report.reportId,
        userId: int.parse(user.user_id),
        type: type,
      );
    } catch (e) {
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
           _feedReports[index] = report;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to vote: $e')),
        );
      }
    }
  }

  void _openCommentDialog(ReportModel report, int index) {
      final user = ref.read(authProvider).user;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to comment')),
        );
        return;
      }
      
      final TextEditingController commentController = TextEditingController();
      bool isSubmitting = false;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Add Comment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          if (commentController.text.trim().isEmpty) return;
                          
                          setModalState(() {
                            isSubmitting = true;
                          });

                          try {
                            await _remoteDataSource.addComment(
                              reportId: report.reportId,
                              userId: int.parse(user.user_id),
                              content: commentController.text.trim(),
                            );
                            
                            if (mounted) {
                              setState(() {
                                _feedReports[index] = report.copyWith(
                                  commentCount: report.commentCount + 1,
                                );
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Comment added')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setModalState(() {
                                isSubmitting = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to comment: $e')),
                              );
                            }
                          }
                        },
                        child: isSubmitting 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                            : const Text('Post Comment'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      );
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
            SliverToBoxAdapter(
              child: _buildCategoryFilter(),
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
                    return _buildReportCard(report, index);
                  },
                  childCount: _feedReports.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = category;
                  });
                  _fetchFeedData();
                }
              },
              backgroundColor: Colors.white,
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.blue : Colors.grey[300]!,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreatePostHeader() {
    final user = ref.watch(authProvider).user;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[100],
            backgroundImage: (user?.image_url != null && user!.image_url!.isNotEmpty)
                ? NetworkImage(user.image_url!)
                : null,
            child: (user?.image_url == null || user!.image_url!.isEmpty)
                ? const Icon(Icons.person, color: Colors.blue)
                : null,
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

  Future<void> _handleSave(ReportModel report, int index) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save posts')),
      );
      return;
    }

    final isCurrentlySaved = report.isSaved;
    
    // Optimistic update
    setState(() {
      _feedReports[index] = report.copyWith(isSaved: !isCurrentlySaved);
    });

    try {
      if (isCurrentlySaved) {
        await _remoteDataSource.unsaveReport(report.reportId, int.parse(user.user_id));
      } else {
        await _remoteDataSource.saveReport(report.reportId, int.parse(user.user_id));
      }
    } catch (e) {
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _feedReports[index] = report;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update save status: $e')),
        );
      }
    }
  }

  Widget _buildReportCard(ReportModel report, int index) {
    return ReportCardWidget(
      report: report,
      currentLocation: _currentLocation,
      onUpvote: () => _handleVote(report, 'up', index),
      onDownvote: () => _handleVote(report, 'down', index),
      onComment: () => _openCommentDialog(report, index),
      onSave: () => _handleSave(report, index),
    );
  }

}
