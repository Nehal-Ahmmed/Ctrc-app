import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ctrc/core/l10n/app_strings.dart';
import 'package:ctrc/features/Report/domain/models/feed_filter.dart';

/// Picks how the feed is ordered and which reports it holds back.
///
/// The choices are edited on a copy and only handed back when the sheet is
/// confirmed, so backing out leaves the feed exactly as it was rather than
/// having quietly refetched it once per tap.
class FeedFilterSheet extends ConsumerStatefulWidget {
  const FeedFilterSheet({super.key, required this.filter});

  final FeedFilter filter;

  /// Opens the sheet and resolves to the chosen filter, or null if it was
  /// dismissed without confirming.
  static Future<FeedFilter?> show(BuildContext context, FeedFilter current) {
    return showModalBottomSheet<FeedFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FeedFilterSheet(filter: current),
    );
  }

  @override
  ConsumerState<FeedFilterSheet> createState() => _FeedFilterSheetState();
}

class _FeedFilterSheetState extends ConsumerState<FeedFilterSheet> {
  late FeedFilter _draft = widget.filter;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        // Tall enough to show the sort options without scrolling on a normal
        // phone, never so tall that the feed disappears behind it.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            _buildHeader(strings),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                shrinkWrap: true,
                children: [
                  _buildSection(
                    strings.sortBy,
                    FeedSort.values
                        .map(
                          (sort) => _choice(
                            label: _sortLabel(strings, sort),
                            selected: _draft.sort == sort,
                            onSelected: () => setState(
                              () => _draft = _draft.copyWith(sort: sort),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 24),
                  Text(
                    strings.showOnly.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    strings.verificationLabel,
                    FeedStatus.values
                        .map(
                          (status) => _choice(
                            label: _statusLabel(strings, status),
                            selected: _draft.status == status,
                            onSelected: () => setState(
                              () => _draft = _draft.copyWith(status: status),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  _buildSection(
                    strings.evidenceLabel,
                    FeedEvidence.values
                        .map(
                          (evidence) => _choice(
                            label: _evidenceLabel(strings, evidence),
                            selected: _draft.evidence == evidence,
                            onSelected: () => setState(
                              () => _draft = _draft.copyWith(evidence: evidence),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  _buildSection(
                    strings.postedLabel,
                    FeedAge.values
                        .map(
                          (age) => _choice(
                            label: _ageLabel(strings, age),
                            selected: _draft.age == age,
                            onSelected: () => setState(
                              () => _draft = _draft.copyWith(age: age),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      strings.withPhotoOnly,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: _draft.withPhotoOnly,
                    onChanged: (value) => setState(
                      () => _draft = _draft.copyWith(withPhotoOnly: value),
                    ),
                  ),
                ],
              ),
            ),
            _buildApplyBar(strings),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(AppStrings strings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              strings.filterAndSort,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          // Only worth offering once there is something to undo.
          if (!_draft.isDefault)
            TextButton(
              onPressed: () => setState(() => _draft = FeedFilter.initial),
              child: Text(strings.resetAll),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.white,
      selectedColor: Colors.blue[50],
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        color: selected ? Colors.blue[800] : Colors.grey[800],
      ),
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? Colors.blue : Colors.grey[300]!,
        ),
      ),
    );
  }

  Widget _buildApplyBar(AppStrings strings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE4E6EB))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context, _draft),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            strings.showResults,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  String _sortLabel(AppStrings strings, FeedSort sort) => switch (sort) {
        FeedSort.nearest => strings.sortNearest,
        FeedSort.newest => strings.sortNewest,
        FeedSort.oldest => strings.sortOldest,
        FeedSort.top => strings.sortTop,
        FeedSort.discussed => strings.sortDiscussed,
        FeedSort.confirmed => strings.sortConfirmed,
      };

  String _statusLabel(AppStrings strings, FeedStatus status) =>
      switch (status) {
        FeedStatus.any => strings.statusAny,
        FeedStatus.verified => strings.statusVerified,
        FeedStatus.unverified => strings.statusUnverified,
        FeedStatus.disputed => strings.statusDisputed,
      };

  String _evidenceLabel(AppStrings strings, FeedEvidence evidence) =>
      switch (evidence) {
        FeedEvidence.any => strings.evidenceAny,
        FeedEvidence.seen => strings.evidenceSeen,
        FeedEvidence.heard => strings.evidenceHeard,
        FeedEvidence.guessed => strings.evidenceGuessed,
      };

  String _ageLabel(AppStrings strings, FeedAge age) => switch (age) {
        FeedAge.any => strings.postedAnytime,
        FeedAge.lastHour => strings.postedLastHour,
        FeedAge.last6Hours => strings.postedLast6Hours,
        FeedAge.lastDay => strings.postedLastDay,
        FeedAge.lastWeek => strings.postedLastWeek,
      };
}
