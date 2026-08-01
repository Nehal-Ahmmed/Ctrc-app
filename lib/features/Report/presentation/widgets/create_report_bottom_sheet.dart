import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../Auth/presentation/providers/auth_provider.dart';
import '../../../Map/data/datasources/geocoding_datasource.dart';
import '../../../Map/domain/services/incident_severity.dart';
import '../../../Map/domain/utils/geo_utils.dart';
import '../../data/datasources/report_remote_datasource.dart';
import '../../domain/models/report_category.dart';
import 'link_incident_sheet.dart';

/// How far out to look for an incident this report might belong to.
///
/// Fixed at the roadmap's 5 km rather than the user's browse radius: how wide
/// you like your feed is a display preference, whereas "is this the same
/// event?" is a property of the road.
const double kLinkSearchRadiusKm = 5.0;

class CreateReportBottomSheet extends ConsumerStatefulWidget {
  final double latitude;
  final double longitude;

  /// Set when the reporter already chose an incident to attach to (for example
  /// "Add an update" from the report details page). When null the sheet runs
  /// the link-or-create check itself.
  final int? parentReportId;
  final String? parentTitle;

  /// Human label for where the pin is, shown so the reporter can tell whether
  /// they are filing against their GPS position or a spot they picked.
  final String? locationLabel;

  const CreateReportBottomSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    this.parentReportId,
    this.parentTitle,
    this.locationLabel,
  });

  @override
  ConsumerState<CreateReportBottomSheet> createState() =>
      _CreateReportBottomSheetState();
}

class _CreateReportBottomSheetState
    extends ConsumerState<CreateReportBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final ReportRemoteDataSource _remoteDataSource = ReportRemoteDataSourceImpl();
  final GeocodingDataSource _geocoder = GeocodingDataSource();

  String _category = ReportCategory.trafficJam.label;
  bool _isLoading = false;

  /// Resolved once when the sheet opens so the report carries a street name
  /// instead of bare coordinates.
  String? _resolvedAddress;

  /// Chosen in the link step; also set upfront when the caller passed a parent.
  int? _linkedParentId;
  String? _linkedParentTitle;

  @override
  void initState() {
    super.initState();
    _linkedParentId = widget.parentReportId;
    _linkedParentTitle = widget.parentTitle;

    final label = widget.locationLabel?.trim();
    _resolvedAddress = (label == null || label.isEmpty) ? null : label;
    if (_resolvedAddress == null) _resolveAddress();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress() async {
    final label = await _geocoder
        .describe(LatLng(widget.latitude, widget.longitude));
    if (!mounted || label == null) return;
    setState(() => _resolvedAddress = label);
  }

  bool get _isSubReport => _linkedParentId != null;

  LatLng get _point => LatLng(widget.latitude, widget.longitude);

  /// Open incidents close enough that this report is probably about the same
  /// event. Returns an empty list when nothing is nearby or the lookup fails —
  /// a flaky network must never block someone from filing a report.
  Future<List<IncidentCandidate>> _findNearbyIncidents({
    required int userId,
    required double radiusKm,
  }) async {
    try {
      final nearby = await _remoteDataSource.getNearbyReports(
        lat: widget.latitude,
        lng: widget.longitude,
        radius: radiusKm,
        userId: userId,
      );

      final candidates = <IncidentCandidate>[];
      for (final report in nearby) {
        final location = report.location;
        if (location == null) continue;
        if (!IncidentSeverity.isActive(report)) continue;
        candidates.add((
          report: report,
          distanceMeters: GeoUtils.metersBetween(
            _point,
            LatLng(location.latitude, location.longitude),
          ),
        ));
      }

      candidates.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return candidates.take(8).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider).user;
    if (user == null) {
      _notify('Please log in to report an incident');
      return;
    }
    final userId = int.tryParse(user.user_id);
    if (userId == null) {
      _notify('Your session looks invalid — please log in again');
      return;
    }

    setState(() => _isLoading = true);

    var parentReportId = _linkedParentId;

    // Link-or-create: only when the reporter has not already picked a parent.
    if (parentReportId == null) {
      final candidates = await _findNearbyIncidents(
        userId: userId,
        radiusKm: kLinkSearchRadiusKm,
      );

      if (!mounted) return;

      if (candidates.isNotEmpty) {
        final choice = await LinkIncidentSheet.show(
          context,
          candidates: candidates,
          radiusLabel: 'within ${kLinkSearchRadiusKm.toInt()} km',
        );

        if (!mounted) return;
        if (choice == null) {
          // Backed out of the prompt — keep the form as they left it.
          setState(() => _isLoading = false);
          return;
        }
        parentReportId = choice.parent?.reportId;
      }
    }

    try {
      await _remoteDataSource.createReport(
        userId: userId,
        latitude: widget.latitude,
        longitude: widget.longitude,
        title: parentReportId != null
            ? 'Update'
            : _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: parentReportId != null ? 'Sub-report' : _category,
        parentReportId: parentReportId,
        address: _resolvedAddress,
      );

      if (!mounted) return;
      Navigator.pop(context, parentReportId != null
          ? CreateReportResult.linked
          : CreateReportResult.created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _notify('Could not submit the report: $e');
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(authProvider).user != null;
    final strings = ref.watch(appStringsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isSubReport
                    ? strings.addToThisIncident
                    : strings.reportNewIncident,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _buildLocationRow(),
              if (_isSubReport) ...[
                const SizedBox(height: 12),
                _buildLinkedBanner(),
              ],
              const SizedBox(height: 16),
              if (!_isSubReport) ...[
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: strings.titleLabel,
                    hintText: 'e.g. Truck blocking the left lane',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? strings.required
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: strings.categoryLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: ReportCategory.values
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.label,
                          child: Row(
                            children: [
                              Icon(category.icon,
                                  size: 18, color: category.color),
                              const SizedBox(width: 10),
                              Text(category.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: strings.descriptionLabel,
                  hintText: _isSubReport
                      ? 'What is happening there right now?'
                      : 'Add anything that helps other drivers',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? strings.required
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_isLoading || !isAuthenticated)
                    ? null
                    : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isAuthenticated
                            ? strings.submitReport
                            : strings.logInToReport,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
              if (!_isSubReport) ...[
                const SizedBox(height: 8),
                Text(
                  'If something similar is already reported nearby you will be '
                  'asked whether to link to it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _resolvedAddress ??
                  '${widget.latitude.toStringAsFixed(5)}, '
                      '${widget.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 18, color: Color(0xFFE8710A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Linking to "${_linkedParentTitle ?? 'incident #$_linkedParentId'}"',
              style: const TextStyle(fontSize: 12.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the sheet handed back, so callers can word the confirmation correctly.
enum CreateReportResult {
  created,
  linked;

  String get message => switch (this) {
        CreateReportResult.created => 'Incident reported. Thanks!',
        CreateReportResult.linked => 'Added to the existing incident. Thanks!',
      };
}
