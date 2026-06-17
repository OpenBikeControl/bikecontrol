import 'package:bike_control/utils/iap/revenuecat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RevenueCatService.isPurchasedBuild', () {
    group('iOS (isMacOS: false)', () {
      test('old paid era (< 58) is purchased', () {
        expect(RevenueCatService.isPurchasedBuild(0, isMacOS: false), isTrue);
        expect(RevenueCatService.isPurchasedBuild(57, isMacOS: false), isTrue);
      });

      test('legacy free window (58..76) is not purchased', () {
        expect(RevenueCatService.isPurchasedBuild(58, isMacOS: false), isFalse);
        expect(RevenueCatService.isPurchasedBuild(76, isMacOS: false), isFalse);
      });

      test('current paid era (77..137) is purchased', () {
        expect(RevenueCatService.isPurchasedBuild(77, isMacOS: false), isTrue);
        expect(RevenueCatService.isPurchasedBuild(114, isMacOS: false), isTrue);
        expect(RevenueCatService.isPurchasedBuild(137, isMacOS: false), isTrue);
      });

      test('first free build (138) and later are not purchased', () {
        expect(RevenueCatService.isPurchasedBuild(138, isMacOS: false), isFalse);
        expect(RevenueCatService.isPurchasedBuild(200, isMacOS: false), isFalse);
      });
    });

    group('macOS (isMacOS: true) uses 61 as the lower paid edge', () {
      test('60 is purchased, 61 is not', () {
        expect(RevenueCatService.isPurchasedBuild(60, isMacOS: true), isTrue);
        expect(RevenueCatService.isPurchasedBuild(61, isMacOS: true), isFalse);
      });

      test('current paid era (77..137) is purchased', () {
        expect(RevenueCatService.isPurchasedBuild(77, isMacOS: true), isTrue);
        expect(RevenueCatService.isPurchasedBuild(137, isMacOS: true), isTrue);
      });

      test('first free build (138) and later are not purchased', () {
        expect(RevenueCatService.isPurchasedBuild(138, isMacOS: true), isFalse);
      });
    });

    test('freeAgainFromBuild is 138', () {
      expect(RevenueCatService.freeAgainFromBuild, 138);
    });
  });
}
