import 'package:flutter_test/flutter_test.dart';
import 'package:ctrc/core/l10n/app_strings.dart';
import 'package:ctrc/features/Report/domain/models/report_category.dart';

void main() {
  group('ReportCategory', () {
    test('the feed filter offers every category the create sheet can file', () {
      
      for (final label in ReportCategory.labels) {
        expect(ReportCategory.filterLabels, contains(label));
      }
      expect(ReportCategory.filterLabels.first, ReportCategory.allLabel);
    });

    test('resolves the exact labels it writes', () {
      for (final category in ReportCategory.values) {
        expect(ReportCategory.fromLabel(category.label), category);
      }
    });

    test('resolves older wording from existing rows', () {
      expect(ReportCategory.fromLabel('Traffic'), ReportCategory.trafficJam);
      expect(ReportCategory.fromLabel('Road Condition'),
          ReportCategory.roadDamage);
      expect(ReportCategory.fromLabel('waterlogging'),
          ReportCategory.waterlogging);
      expect(ReportCategory.fromLabel('Protest'), ReportCategory.riot);
    });

    test('falls back to Other for unknown or empty input', () {
      expect(ReportCategory.fromLabel(null), ReportCategory.other);
      expect(ReportCategory.fromLabel('   '), ReportCategory.other);
      expect(ReportCategory.fromLabel('zzz'), ReportCategory.other);
    });
  });

  group('AppStrings', () {
    test('every supported code resolves to a distinct translation', () {
      final english = AppStrings.of('en');
      final bangla = AppStrings.of('bn');

      expect(english, isA<EnglishStrings>());
      expect(bangla, isA<BanglaStrings>());
      expect(english.settings, isNot(bangla.settings));
    });

    test('unknown codes fall back to English', () {
      expect(AppStrings.of('fr'), isA<EnglishStrings>());
    });

    test('interpolated strings carry their value through', () {
      expect(AppStrings.of('en').noIncidentsWithin(10), contains('10'));
      expect(AppStrings.of('bn').noIncidentsWithin(10), contains('10'));
    });
  });
}
