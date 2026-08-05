import 'package:flutter/material.dart';

enum ReportCategory {
  trafficJam('Traffic jam', Icons.traffic, Color(0xFFE8710A)),
  accident('Accident', Icons.car_crash, Color(0xFFD93025)),
  roadBlock('Road block', Icons.block, Color(0xFFD93025)),
  roadDamage('Road damage', Icons.construction, Color(0xFFE8710A)),
  waterlogging('Waterlogging', Icons.water, Color(0xFF1A73E8)),
  fire('Fire', Icons.local_fire_department, Color(0xFFD93025)),
  robbery('Robbery', Icons.money_off, Color(0xFF8430CE)),
  riot('Riot', Icons.groups, Color(0xFFD93025)),
  other('Other', Icons.more_horiz, Color(0xFF5F6368)),

  unknown('Unknown', Icons.help_outline, Color(0xFF5F6368));

  const ReportCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static const String allLabel = 'All';

  static List<ReportCategory> get selectable =>
      ReportCategory.values.where((c) => c != ReportCategory.unknown).toList();

  static List<String> get labels => selectable.map((c) => c.label).toList();

  static List<String> get filterLabels => [allLabel, ...labels];

  static ReportCategory fromLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return ReportCategory.other;
    final needle = raw.trim().toLowerCase();

    for (final category in ReportCategory.values) {
      if (category.label.toLowerCase() == needle) return category;
    }

    if (needle.contains('jam') || needle.contains('traffic')) {
      return ReportCategory.trafficJam;
    }
    if (needle.contains('accident') || needle.contains('crash')) {
      return ReportCategory.accident;
    }
    if (needle.contains('block') || needle.contains('closed')) {
      return ReportCategory.roadBlock;
    }
    if (needle.contains('road') || needle.contains('pothole') ||
        needle.contains('construction')) {
      return ReportCategory.roadDamage;
    }
    if (needle.contains('water') || needle.contains('flood')) {
      return ReportCategory.waterlogging;
    }
    if (needle.contains('fire')) return ReportCategory.fire;
    if (needle.contains('rob') || needle.contains('theft') ||
        needle.contains('crime')) {
      return ReportCategory.robbery;
    }
    if (needle.contains('riot') || needle.contains('protest')) {
      return ReportCategory.riot;
    }
    return ReportCategory.other;
  }
}
