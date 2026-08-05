import 'package:flutter_test/flutter_test.dart';
import 'package:ctrc/core/utils/app_time.dart';

void main() {
  group('AppTime', () {
    test('parseTimestamp treats zone-less timestamp as UTC', () {
      const zoneless = '2026-08-05T10:59:20';
      final parsed = AppTime.parseTimestamp(zoneless);
      
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isTrue);
      
      expect(parsed.toIso8601String(), '2026-08-05T10:59:20.000Z');
    });

    test('formatRelativeTime reads a fresh timestamp as fresh', () {
      final now = DateTime.now().toUtc();

      expect(
        AppTime.formatRelativeTime(now.subtract(const Duration(seconds: 30))),
        'just now',
      );
      expect(
        AppTime.formatRelativeTime(now.subtract(const Duration(minutes: 2))),
        '2 min ago',
      );
    });

    test('a zone-less timestamp minutes old is not six hours old', () {
      
      final justPosted = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 2))
          .toIso8601String()
          .split('.')
          .first; 

      expect(
        AppTime.formatRelativeTime(AppTime.parseTimestamp(justPosted)),
        '2 min ago',
      );
    });

    test('formatRelativeTime handles older dates', () {
      final now = DateTime.now().toUtc();
      
      final twentyFiveHours = now.subtract(const Duration(hours: 25));
      expect(AppTime.formatRelativeTime(twentyFiveHours), '1 d ago');
    });
  });
}
