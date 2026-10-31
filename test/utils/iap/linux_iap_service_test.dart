// Base is free on Linux; only Pro is sold there (through Stripe).
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/iap/linux_iap_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initializing grants Base', () async {
    IAPManager.instance.isPurchased.value = false;
    addTearDown(() => IAPManager.instance.isPurchased.value = true);

    await LinuxIAPService().initialize();

    expect(IAPManager.instance.isPurchased.value, isTrue);
  });
}
