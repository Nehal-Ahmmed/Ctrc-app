import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/comment_model.dart';
import '../models/report_category.dart';
import '../models/report_model.dart';

/// Hands a report to the phone's own share sheet, which is what puts WhatsApp,
/// Messenger, SMS, email and the rest in front of the user — the app does not
/// need to know about any of them individually.
///
/// A warning is only worth passing on if the person receiving it can tell
/// *where* the incident is, so the text always carries a map link built from
/// the report's own coordinates.
abstract final class ReportShare {
  /// [origin] anchors the sheet to the button that opened it. Ignored
  /// everywhere except iPad and Mac, where a popover needs something to point
  /// at.
  static Future<void> share(ReportModel report, {Rect? origin}) {
    return SharePlus.instance.share(
      ShareParams(
        text: buildMessage(report),
        subject: '${ReportCategory.fromLabel(report.category).label}: ${report.title}',
        sharePositionOrigin: origin,
      ),
    );
  }

  /// Split out from [share] so the wording can be checked without a share
  /// sheet being involved.
  @visibleForTesting
  static String buildMessage(ReportModel report) {
    final category = ReportCategory.fromLabel(report.category);
    final createdAt = CommentModel.parseTimestamp(report.createdAt);

    final lines = <String>[
      '${category.label}: ${report.title}',
      if (report.description != null && report.description!.trim().isNotEmpty)
        report.description!.trim(),
      '',
    ];

    final place = report.location?.address ?? report.location?.city;
    if (place != null && place.trim().isNotEmpty) {
      lines.add('Where: ${place.trim()}');
    }

    final location = report.location;
    if (location != null) {
      lines.add('Map: ${mapLink(location.latitude, location.longitude)}');
    }

    lines.add([
      if (createdAt != null) 'Reported ${formatRelativeTime(createdAt)}',
      _statusLine(report),
    ].join(' · '));

    lines
      ..add('')
      ..add('Shared from CTRC, the crowdsourced traffic and road condition app.');

    return lines.join('\n');
  }

  /// Opens in whatever map app the recipient has, rather than assuming one.
  static String mapLink(double latitude, double longitude) =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  static String _statusLine(ReportModel report) {
    final confirmations = report.subReportCount;
    final backing = switch (report.status) {
      'verified' => 'confirmed by ${report.upvoteCount} people',
      'disputed' => 'disputed by others',
      _ => 'not confirmed yet',
    };
    return confirmations > 0 ? '$backing · $confirmations linked updates' : backing;
  }
}
