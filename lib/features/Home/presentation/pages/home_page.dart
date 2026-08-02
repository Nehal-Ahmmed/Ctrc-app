import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:ctrc/core/l10n/app_strings.dart';
import 'package:ctrc/core/location/last_known_location.dart';
import 'package:ctrc/core/providers/settings_provider.dart';
import 'package:ctrc/core/storage/local_store.dart';
import 'package:ctrc/core/widgets/app_toast.dart';
import 'package:ctrc/features/Notifications/data/datasources/fcm_service.dart';
import 'package:ctrc/features/Notifications/presentation/providers/notification_provider.dart';
import 'package:ctrc/features/Home/presentation/widgets/feed_filter_sheet.dart';
import 'package:ctrc/features/Report/data/datasources/report_local_cache.dart';
import 'package:ctrc/features/Report/data/datasources/report_remote_datasource.dart';
import 'package:ctrc/features/Report/domain/models/feed_filter.dart';
import 'package:ctrc/features/Report/domain/models/report_category.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/domain/services/vote_toggle.dart';
import 'package:ctrc/features/Report/presentation/widgets/create_report_bottom_sheet.dart';
import 'package:ctrc/features/Report/presentation/widgets/report_card_widget.dart';
import 'package:ctrc/features/Report/presentation/widgets/comments_bottom_sheet.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ctrc/features/Auth/presentation/providers/auth_provider.dart';
import 'package:ctrc/core/providers/reload_provider.dart';

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
  FeedFilter _filter = FeedFilter.initial;
  final ReportRemoteDataSource _remoteDataSource = ReportRemoteDataSourceImpl();
  final ReportLocalCache _cache = ReportLocalCache();
  StreamSubscription<Position>? _positionStreamSub;

  /// True while what is on screen came off the device rather than the backend.
  /// Drives the "showing saved reports" strip, so nothing old is mistaken for
  /// the road as it is right now.
  bool _isShowingCache = false;

  /// Same list the create sheet offers, so a filter chip always matches what
  /// was actually filed.
  final List<String> _categories = ReportCategory.filterLabels;

  @override
  void initState() {
    super.initState();
    _restoreFromDevice();
    _initLocationTracking();
  }

  /// Puts the last session back on screen before anything is asked of the GPS
  /// or the network.
  ///
  /// The feed normally waits on both — a fix, then a backend that sleeps when
  /// idle — and shows an empty state until they land. Neither is needed to
  /// redraw what was here last time.
  void _restoreFromDevice() {
    final storedCategory = LocalStore.instance.getString(StorageKeys.feedCategory);
    if (storedCategory != null && _categories.contains(storedCategory)) {
      _selectedCategory = storedCategory;
    }

    final storedFilter = LocalStore.instance.getJson(StorageKeys.feedFilter);
    if (storedFilter is Map) {
      _filter = FeedFilter.fromJson(Map<String, dynamic>.from(storedFilter));
    }

    // Where the phone last was. The real fix replaces it seconds later, but it
    // is enough to start fetching against immediately.
    _currentLocation = LastKnownLocation.read();

    final cached = _cache.read(
      ReportLocalCache.feedBucket,
      userId: ref.read(authIdentityProvider),
    );
    if (cached == null) return;

    // The origin is still worth having even when the list is not — it is where
    // to start fetching from.
    _currentLocation ??= cached.origin;

    // Past the cutoff these are no longer road conditions, they are history.
    // A jam from yesterday shown as the feed is worse than an empty one.
    if (cached.isOlderThan(ReportLocalCache.staleAfter)) return;

    _feedReports = cached.reports;
    _isShowingCache = true;
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocationTracking() async {
    // With a stored position there is something to ask the backend for right
    // away, instead of after the radio answers — which indoors, on a cold
    // start, can be a long wait.
    if (_currentLocation != null) _fetchFeedData();

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
    final point = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentLocation = point;
    });
    // Kept for the next cold start, so the next launch begins where this one
    // left off rather than nowhere.
    unawaited(LastKnownLocation.save(point));
    _fetchFeedData();
  }

  Future<void> _fetchFeedData() async {
    if (_currentLocation == null) return;

    // Piggybacks on the feed reload, which already happens whenever the phone
    // moves or the radius preference changes — exactly when the set of map
    // cells worth listening to would change too.
    final settings = ref.read(settingsProvider);
    unawaited(ref.read(fcmServiceProvider).syncTopics(
          latitude: _currentLocation!.latitude,
          longitude: _currentLocation!.longitude,
          radiusKm: settings.reportRadius,
          enabled: settings.nearbyAlertsEnabled,
        ));

    setState(() {
      _isLoading = true;
    });

    try {
      final user = ref.read(authProvider).user;
      final userId = user != null ? int.tryParse(user.user_id) : null;

      final reports = await _remoteDataSource.getNearbyReports(
        lat: _currentLocation!.latitude,
        lng: _currentLocation!.longitude,
        // Honours the "Report Radius" preference in Settings.
        radius: ref.read(settingsProvider).reportRadius,
        category: _selectedCategory,
        userId: userId,
        filter: _filter,
      );

      if (mounted) {
        setState(() {
          _feedReports = reports;
          _isShowingCache = false;
        });

        // What the next launch opens with, filed under whoever is signed in —
        // these cards carry that person's saves and votes.
        unawaited(_cache.write(
          ReportLocalCache.feedBucket,
          reports,
          userId: user?.user_id,
          origin: _currentLocation,
        ));

        // Anything new near the user becomes an entry in the alert inbox.
        ref.read(notificationsProvider.notifier).ingest(
              reports,
              viewerLocation: _currentLocation,
              viewerUserId: userId,
              enabled: ref.read(settingsProvider).nearbyAlertsEnabled,
            );
      }
    } catch (e, stack) {
      debugPrint('Error fetching feed: $e\n$stack');
      if (mounted) {
        AppToast.error(
          context,
          e,
          title: 'Could not load the feed',
          action: ToastAction(label: 'Retry', onPressed: _fetchFeedData),
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
      AppToast.warning(context, ref.read(appStringsProvider).waitingForGps);
      return;
    }

    if (ref.read(authProvider).user == null) {
      AppToast.info(context, ref.read(appStringsProvider).logInToReport);
      return;
    }

    final result = await showModalBottomSheet<CreateReportResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CreateReportBottomSheet(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
      ),
    );

    if (result != null && mounted) {
      AppToast.success(context, result.message);
      _fetchFeedData();
    }
  }

  Future<void> _handleVote(ReportModel report, String type, int index) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      AppToast.info(context, ref.read(appStringsProvider).logInToVote);
      return;
    }

    // Save original state
    final originalReport = _feedReports[index];

    setState(() {
      _feedReports[index] = VoteToggle.apply(report, type);
    });

    try {
      await _remoteDataSource.voteReport(
        reportId: report.reportId,
        userId: int.parse(user.user_id),
        type: type,
      );
    } catch (e, stack) {
      debugPrint('Error voting: $e\n$stack');
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
           _feedReports[index] = originalReport;
        });
        AppToast.error(context, e, title: 'Vote not saved');
      }
    }
  }

  void _openCommentDialog(ReportModel report, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        reportId: report.reportId,
        onCommentAdded: () {
          setState(() {
            _feedReports[index] = _feedReports[index].copyWith(
              commentCount: _feedReports[index].commentCount + 1,
            );
          });
        },
      ),
    );
  }

  /// Signing in or out changes whose saves and votes these cards carry, so the
  /// feed drops the old viewer's state immediately and refetches its own.
  void _onIdentityChanged() {
    if (!mounted) return;

    // Whatever the new viewer has stored is a better starting point than the
    // previous viewer's list with its saves and votes scrubbed off — but only
    // if they have one.
    final cached = _cache.read(
      ReportLocalCache.feedBucket,
      userId: ref.read(authIdentityProvider),
    );

    setState(() {
      _feedReports = cached?.reports ??
          _feedReports.map((report) => report.withoutViewerState()).toList();
      _isShowingCache = cached != null;
    });
    _fetchFeedData();
  }

  @override
  Widget build(BuildContext context) {
    // Changing the radius in Settings should reshape the feed straight away.
    ref.listen<double>(
      settingsProvider.select((s) => s.reportRadius),
      (previous, next) {
        if (previous != null && previous != next) _fetchFeedData();
      },
    );

    // Turning the alerts off should stop the pushes there and then, rather
    // than at whenever the feed happens to reload next.
    ref.listen<bool>(
      settingsProvider.select((s) => s.nearbyAlertsEnabled),
      (previous, next) {
        if (previous != null && previous != next) _fetchFeedData();
      },
    );

    ref.listen<String?>(
      authIdentityProvider,
      (previous, next) {
        if (previous != next) _onIdentityChanged();
      },
    );

    ref.listen<ReloadCommand?>(
      reloadProvider,
      (previous, next) {
        if (next != null && next.index == 0) {
          _fetchFeedData();
        }
      },
    );

    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[200],
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
            if (_isShowingCache && _feedReports.isNotEmpty)
              SliverToBoxAdapter(child: _buildCachedNotice(strings)),
            if (_isLoading && _feedReports.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_feedReports.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          // With a filter on, "nothing within 5 km" would be a
                          // lie — the reports are there, they were held back.
                          _filter.activeFilterCount > 0
                              ? strings.noMatchingReports
                              : _selectedCategory == ReportCategory.allLabel
                                  ? strings.noIncidentsWithin(
                                      ref.watch(settingsProvider)
                                          .reportRadius
                                          .toInt(),
                                    )
                                  : strings.noCategoryIncidentsWithin(
                                      _selectedCategory,
                                      ref.watch(settingsProvider)
                                          .reportRadius
                                          .toInt(),
                                    ),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
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

  /// Marks the list as the stored one rather than the current one.
  ///
  /// Road conditions go out of date fast, so a cached feed has to say so —
  /// otherwise an hour-old jam reads as a live one.
  Widget _buildCachedNotice(AppStrings strings) {
    return Container(
      width: double.infinity,
      color: Colors.amber[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.history, size: 16, color: Colors.amber[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.showingSavedReports,
              style: TextStyle(fontSize: 12, color: Colors.amber[900]),
            ),
          ),
        ],
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
          final label = category == ReportCategory.allLabel
              ? ref.watch(appStringsProvider).categoryAll
              : category;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = category;
                  });
                  // Deliberate choices, so they survive the app closing.
                  unawaited(LocalStore.instance
                      .setString(StorageKeys.feedCategory, category));
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
                  ref.watch(appStringsProvider).whatsHappeningNearby,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildFilterButton(),
        ],
      ),
    );
  }

  /// Opens the filter sheet. Sits beside the composer because the two are the
  /// same question from either end: what goes into the feed, and what comes
  /// out of it.
  Widget _buildFilterButton() {
    final strings = ref.watch(appStringsProvider);
    final isActive = !_filter.isDefault;
    final hidden = _filter.activeFilterCount;

    return Tooltip(
      message: strings.filterAndSort,
      child: InkWell(
        onTap: _openFilterSheet,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue[50] : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.blue : Colors.grey[300]!,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.tune,
                size: 22,
                color: isActive ? Colors.blue : Colors.grey[700],
              ),
              // Counts only what is being held back; a changed sort order
              // hides nothing, so it does not earn a badge.
              if (hidden > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$hidden',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final chosen = await FeedFilterSheet.show(context, _filter);
    if (chosen == null || chosen == _filter || !mounted) return;

    setState(() {
      _filter = chosen;
    });
    unawaited(
      LocalStore.instance.setJson(StorageKeys.feedFilter, chosen.toJson()),
    );
    // The new order and the new cut come from the query, so the list has to be
    // fetched again rather than rearranged in place.
    _fetchFeedData();
  }

  Future<void> _handleSave(ReportModel report, int index) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      AppToast.info(context, ref.read(appStringsProvider).logInToSave);
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
        AppToast.error(context, e, title: 'Could not update saved posts');
      }
    }
  }

  Future<void> _handleEditReport(ReportModel report, int index) async {
    final location = report.location;
    final result = await showModalBottomSheet<CreateReportResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CreateReportBottomSheet(
        latitude: location?.latitude ?? 0,
        longitude: location?.longitude ?? 0,
        editReport: report,
        locationLabel: [location?.address, location?.city]
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .join(', '),
      ),
    );

    if (result == CreateReportResult.edited) {
      _fetchFeedData();
    }
  }

  Widget _buildReportCard(ReportModel report, int index) {
    final user = ref.read(authProvider).user;
    final currentUserId = user != null ? int.tryParse(user.user_id) : null;
    final isOwner = currentUserId != null && report.userId == currentUserId;

    return ReportCardWidget(
      report: report,
      currentLocation: _currentLocation,
      onUpvote: () => _handleVote(report, 'up', index),
      onDownvote: () => _handleVote(report, 'down', index),
      onComment: () => _openCommentDialog(report, index),
      onSave: () => _handleSave(report, index),
      onEdit: isOwner ? () => _handleEditReport(report, index) : null,
    );
  }

}
