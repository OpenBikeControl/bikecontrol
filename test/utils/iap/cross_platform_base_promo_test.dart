import 'package:bike_control/utils/iap/cross_platform_base_promo.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => CrossPlatformBasePromo.now = DateTime.now);

  void at(DateTime t) => CrossPlatformBasePromo.now = () => t;

  test('runs on Friday 27 November anywhere on Earth, same window as the backend', () {
    at(DateTime.utc(2026, 11, 26, 9, 59, 59));
    expect(CrossPlatformBasePromo.isRunning, isFalse);
    at(DateTime.utc(2026, 11, 26, 10));
    expect(CrossPlatformBasePromo.isRunning, isTrue);
    at(DateTime.utc(2026, 11, 28, 11, 59, 59));
    expect(CrossPlatformBasePromo.isRunning, isTrue);
    at(DateTime.utc(2026, 11, 28, 12));
    expect(CrossPlatformBasePromo.isRunning, isFalse);
  });

  test('is offered where the purchase reaches the account', () {
    at(DateTime.utc(2026, 11, 27, 12));
    expect(CrossPlatformBasePromo.isOfferedOn(PurchaseChannel.appStore), isTrue);
    expect(CrossPlatformBasePromo.isOfferedOn(PurchaseChannel.macAppStore), isTrue);
    expect(CrossPlatformBasePromo.isOfferedOn(PurchaseChannel.playStore), isTrue);
    expect(CrossPlatformBasePromo.isOfferedOn(PurchaseChannel.windowsDirect), isTrue);
    expect(CrossPlatformBasePromo.isOfferedOn(PurchaseChannel.microsoftStore), isTrue);
    expect(CrossPlatformBasePromo.isOfferedOn(PurchaseChannel.linuxDirect), isFalse);
  });
}
