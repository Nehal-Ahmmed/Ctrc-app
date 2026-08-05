class AppTime {
  AppTime._();

  static final _hasTimezone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  static DateTime? parseTimestamp(dynamic value) {
    if (value == null) return null;
    
    if (value is num) {
      final asInt = value.toInt();
      
      return asInt < 100000000000
          ? DateTime.fromMillisecondsSinceEpoch(asInt * 1000, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
    }
    
    final raw = '$value';
    if (raw.trim().isEmpty) return null;

    final withZone = _hasTimezone.hasMatch(raw) ? raw : '${raw}Z';
    return DateTime.tryParse(withZone)?.toUtc();
  }

  static String formatRelativeTime(DateTime? time) {
    if (time == null) return '';
    
    final now = DateTime.now().toUtc();
    final diff = now.difference(time.toUtc());
    
    if (diff.isNegative) return 'just now';
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 30) return '${diff.inDays} d ago';
    
    final localTime = time.toUtc().add(const Duration(hours: 6));
    return '${localTime.day}/${localTime.month}/${localTime.year}';
  }
}
