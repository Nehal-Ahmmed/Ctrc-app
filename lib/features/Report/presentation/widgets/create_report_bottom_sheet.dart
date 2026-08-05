import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/app_time.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../Auth/presentation/providers/auth_provider.dart';
import '../../../Map/data/datasources/geocoding_datasource.dart';
import '../../../Map/domain/services/incident_severity.dart';
import '../../../Map/domain/utils/geo_utils.dart';
import '../../data/datasources/report_remote_datasource.dart';
import '../../domain/models/report_category.dart';
import '../../domain/models/report_model.dart';
import '../../domain/services/incident_match.dart';
import 'link_incident_sheet.dart';

const double kLinkSearchRadiusKm = 5.0;

class CreateReportBottomSheet extends ConsumerStatefulWidget {
  final double latitude;
  final double longitude;

  final int? parentReportId;
  final String? parentTitle;

  final String? locationLabel;

  final ReportModel? editReport;

  const CreateReportBottomSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    this.parentReportId,
    this.parentTitle,
    this.locationLabel,
    this.editReport,
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

  String _evidence = 'seen';

  bool _isLoading = false;

  String? _imageUrl;
  bool _isUploadingImage = false;

  String? _resolvedAddress;

  int? _linkedParentId;
  String? _linkedParentTitle;

  @override
  void initState() {
    super.initState();
    _linkedParentId = widget.parentReportId;
    _linkedParentTitle = widget.parentTitle;

    final editing = widget.editReport;
    if (editing != null) {
      _titleController.text = editing.title;
      _descriptionController.text = editing.description ?? '';
      _evidence = editing.evidenceType;
      _imageUrl = editing.imageUrl;
      
      if (editing.category != ReportCategory.unknown.label) {
        _category = editing.category;
      }
    }

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

  bool get _isEditing => widget.editReport != null;

  bool get _isGuess => _evidence == 'guessed';

  String get _submittedCategory =>
      _isGuess ? ReportCategory.unknown.label : _category;

  LatLng get _point => LatLng(widget.latitude, widget.longitude);

  bool _couldBeSameIncident(String otherCategory) {
    final unknown = ReportCategory.unknown.label.toLowerCase();
    final mine = _submittedCategory.toLowerCase();
    final other = otherCategory.trim().toLowerCase();
    return mine == unknown || other == unknown || mine == other;
  }

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
        withinHours: kLinkMaxAgeHours,
      );

      final title = _titleController.text;

      final candidates = <IncidentCandidate>[];
      for (final report in nearby) {
        final location = report.location;
        if (location == null) continue;
        if (!IncidentSeverity.isActive(report)) continue;
        if (!_couldBeSameIncident(report.category)) continue;
        if (!IncidentMatch.isRecentEnough(
          AppTime.parseTimestamp(report.createdAt),
        )) {
          continue;
        }

        candidates.add((
          report: report,
          distanceMeters: GeoUtils.metersBetween(
            _point,
            LatLng(location.latitude, location.longitude),
          ),
          titleScore: IncidentMatch.titleSimilarity(title, report.title),
        ));
      }

      return IncidentMatch.rank(candidates).take(8).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploadingImage = true);
    try {
      final url = await _remoteDataSource.uploadReportImage(picked.path);
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _isUploadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      AppToast.error(context, e, title: 'Could not upload the photo');
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) await _pickImage(source);
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

    if (_isEditing) {
      try {
        await _remoteDataSource.updateReport(
          reportId: widget.editReport!.reportId,
          userId: userId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _submittedCategory,
          evidenceType: _evidence,
          imageUrl: _imageUrl,
        );

        if (!mounted) return;
        Navigator.pop(context, CreateReportResult.edited);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppToast.error(context, e, title: 'Could not save the changes');
      }
      return;
    }

    var parentReportId = _linkedParentId;

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
        category: _submittedCategory,
        evidenceType: _evidence,
        imageUrl: _imageUrl,
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
      AppToast.error(context, e, title: 'Could not submit the report');
    }
  }

  void _notify(String message) => AppToast.info(context, message);

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
                _isEditing
                    ? 'Edit your report'
                    : _isSubReport
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
              ],
              DropdownButtonFormField<String>(
                initialValue: _evidence,
                decoration: const InputDecoration(
                  labelText: 'How do you know about this?',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'seen',
                    child: Text('I saw it myself'),
                  ),
                  DropdownMenuItem(
                    value: 'heard',
                    child: Text('Someone told me'),
                  ),
                  DropdownMenuItem(
                    value: 'guessed',
                    child: Text('I am guessing from the traffic'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _evidence = value);
                },
              ),
              const SizedBox(height: 16),
              if (_isGuess)
                _buildUnknownCategoryNote()
              else
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: strings.categoryLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: ReportCategory.selectable
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
              const SizedBox(height: 16),
              _buildPhotoSection(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_isLoading || _isUploadingImage || !isAuthenticated)
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
                        !isAuthenticated
                            ? strings.logInToReport
                            : _isEditing
                                ? 'Save changes'
                                : strings.submitReport,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
              if (!_isSubReport && !_isEditing) ...[
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

  Widget _buildPhotoSection() {
    if (_isUploadingImage) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 10),
            Text('Uploading photo...', style: TextStyle(fontSize: 12.5)),
          ],
        ),
      );
    }

    if (_imageUrl != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              _imageUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                height: 180,
                alignment: Alignment.center,
                color: Colors.grey.withValues(alpha: 0.12),
                child: const Text('Photo could not be shown'),
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _imageUrl = null),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: _choosePhotoSource,
      icon: const Icon(Icons.add_a_photo_outlined, size: 20),
      label: const Text('Add a photo (optional)'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildUnknownCategoryNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filed as "Unknown". Someone who actually sees what happened '
              'can name it later.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[800]),
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

enum CreateReportResult {
  created,
  linked,
  edited;

  String get message => switch (this) {
        CreateReportResult.created => 'Incident reported. Thanks!',
        CreateReportResult.linked => 'Added to the existing incident. Thanks!',
        CreateReportResult.edited => 'Your report has been updated.',
      };
}
