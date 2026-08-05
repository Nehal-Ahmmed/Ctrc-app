import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/app_time.dart';
import '../models/report_category.dart';
import '../models/report_model.dart';

abstract final class ReportShare {
  
  static Future<void> share(ReportModel report, {Rect? origin}) {
    return SharePlus.instance.share(
      ShareParams(
        text: buildMessage(report),
        subject: '${ReportCategory.fromLabel(report.category).label}: ${report.title}',
        sharePositionOrigin: origin,
      ),
    );
  }

  @visibleForTesting
  static String buildMessage(ReportModel report) {
    final category = ReportCategory.fromLabel(report.category);
    final createdAt = AppTime.parseTimestamp(report.createdAt);

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
      if (createdAt != null) 'Reported ${AppTime.formatRelativeTime(createdAt)}',
      _statusLine(report),
    ].join(' · '));

    lines
      ..add('')
      ..add('Shared from CTRC, the crowdsourced traffic and road condition app.');

    return lines.join('\n');
  }

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
