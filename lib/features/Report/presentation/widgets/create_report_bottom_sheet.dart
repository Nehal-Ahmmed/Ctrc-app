import 'package:flutter/material.dart';
import 'package:ctrc/features/Report/data/datasources/report_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateReportBottomSheet extends StatefulWidget {
  final double latitude;
  final double longitude;
  final int? parentReportId;

  const CreateReportBottomSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    this.parentReportId,
  });

  @override
  State<CreateReportBottomSheet> createState() => _CreateReportBottomSheetState();
}

class _CreateReportBottomSheetState extends State<CreateReportBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  String _category = 'Traffic'; // Default
  bool _isLoading = false;

  final ReportRemoteDataSource _remoteDataSource = ReportRemoteDataSourceImpl();

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      // Temporarily grabbing userId. In a real scenario, use state management (e.g. Riverpod).
      int userId = 1; 

      await _remoteDataSource.createReport(
        userId: userId,
        latitude: widget.latitude,
        longitude: widget.longitude,
        title: widget.parentReportId != null ? 'Sub-report' : _title,
        description: _description,
        category: widget.parentReportId != null ? 'Sub-report' : _category,
        parentReportId: widget.parentReportId,
      );

      if (mounted) {
        Navigator.pop(context, true); // True indicates success
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

  @override
  Widget build(BuildContext context) {
    final bool isSubReport = widget.parentReportId != null;

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
                isSubReport ? 'Link to Incident' : 'Report New Incident',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (!isSubReport) ...[
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  onSaved: (value) => _title = value ?? '',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: ['Traffic', 'Accident', 'Road Condition', 'Waterlogging', 'Other']
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (value) => setState(() => _category = value!),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                onSaved: (value) => _description = value ?? '',
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitReport,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Report', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
