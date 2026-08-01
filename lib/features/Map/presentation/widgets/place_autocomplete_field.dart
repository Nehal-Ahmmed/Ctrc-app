import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/datasources/geo_request_cache.dart';
import '../../data/datasources/geocoding_datasource.dart';
import '../../domain/models/place_suggestion.dart';

/// A text field that suggests places while you type.
///
/// Suggestions are rendered inline (as a list right under the field) rather
/// than in an overlay so the widget composes inside both the map's floating
/// search card and the route planner sheet.
class PlaceAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final GeocodingDataSource geocoder;
  final String hintText;
  final Widget? prefixIcon;
  final LatLng? biasTowards;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<PlaceSuggestion> onSelected;
  final VoidCallback? onCleared;

  /// Optional shortcut row, e.g. "Use my current location".
  final Widget? leadingShortcut;

  const PlaceAutocompleteField({
    super.key,
    required this.controller,
    required this.geocoder,
    required this.onSelected,
    this.hintText = 'Search here',
    this.prefixIcon,
    this.biasTowards,
    this.focusNode,
    this.autofocus = false,
    this.onCleared,
    this.leadingShortcut,
  });

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  static const _debounce = Duration(milliseconds: 450);

  Timer? _debounceTimer;
  CancelToken? _cancelToken;
  List<PlaceSuggestion> _suggestions = const [];
  bool _isLoading = false;
  bool _suppressNextQuery = false;
  String? _error;

  /// A rate limit is temporary, so it reads as a gentle notice rather than a
  /// red failure.
  bool _isRateLimited = false;

  late final FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    _cancelToken?.cancel();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_suppressNextQuery) {
      _suppressNextQuery = false;
      return;
    }

    _debounceTimer?.cancel();
    final query = widget.controller.text.trim();

    if (query.length < 2) {
      _cancelToken?.cancel();
      _cancelToken = null;
      if (_suggestions.isNotEmpty || _isLoading || _error != null) {
        setState(() {
          _suggestions = const [];
          _isLoading = false;
          _error = null;
        });
      }
      return;
    }

    _debounceTimer = Timer(_debounce, () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    _cancelToken?.cancel();
    final token = CancelToken();
    _cancelToken = token;

    setState(() {
      _isLoading = true;
      _error = null;
      _isRateLimited = false;
    });

    try {
      final results = await widget.geocoder.search(
        query,
        near: widget.biasTowards,
        cancelToken: token,
      );
      if (!mounted || token.isCancelled) return;
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    } on GeoServiceException catch (e) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
        _isRateLimited = e.isRateLimited;
      });
    } on DioException catch (e) {
      if (!mounted || e.type == DioExceptionType.cancel) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not reach the place search service.';
        _isRateLimited = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not reach the place search service.';
        _isRateLimited = false;
      });
    }
  }

  void _select(PlaceSuggestion suggestion) {
    _debounceTimer?.cancel();
    _cancelToken?.cancel();
    _suppressNextQuery = true;
    widget.controller.text = suggestion.title;
    widget.controller.selection =
        TextSelection.collapsed(offset: suggestion.title.length);
    setState(() {
      _suggestions = const [];
      _isLoading = false;
      _error = null;
    });
    _focusNode.unfocus();
    widget.onSelected(suggestion);
  }

  /// Lets the parent close the suggestion list, e.g. after a shortcut is used.
  void clearSuggestions({String? text}) {
    _debounceTimer?.cancel();
    _cancelToken?.cancel();
    if (text != null) {
      _suppressNextQuery = true;
      widget.controller.text = text;
    }
    setState(() {
      _suggestions = const [];
      _isLoading = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) {
            _debounceTimer?.cancel();
            if (_suggestions.isNotEmpty) {
              _select(_suggestions.first);
            } else {
              _runSearch(value.trim());
            }
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : hasText
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear',
                        onPressed: () {
                          widget.controller.clear();
                          clearSuggestions();
                          widget.onCleared?.call();
                        },
                      )
                    : null,
          ),
        ),
        if (widget.leadingShortcut != null) widget.leadingShortcut!,
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _isRateLimited
                      ? Icons.hourglass_bottom
                      : Icons.wifi_off_rounded,
                  size: 15,
                  color: _isRateLimited
                      ? Colors.orange[800]
                      : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: _isRateLimited
                          ? Colors.orange[900]
                          : Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ),
                if (_isRateLimited)
                  TextButton(
                    onPressed: () => _runSearch(widget.controller.text.trim()),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Retry', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        if (_suggestions.isNotEmpty) ...[
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: Icon(suggestion.icon, color: Colors.grey[700]),
                  title: Text(
                    suggestion.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    suggestion.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  onTap: () => _select(suggestion),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
