import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:windows_iap/models/product.dart';
import 'package:windows_iap/models/store_license.dart';

import 'windows_iap.dart';
import 'windows_iap_method_channel.dart';

abstract class WindowsIapPlatform extends PlatformInterface {
  /// Constructs a WindowsIapPlatform.
  WindowsIapPlatform() : super(token: _token);

  static final Object _token = Object();

  static WindowsIapPlatform _instance = MethodChannelWindowsIap();

  /// The default instance of [WindowsIapPlatform] to use.
  ///
  /// Defaults to [MethodChannelWindowsIap].
  static WindowsIapPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WindowsIapPlatform] when
  /// they register themselves.
  static set instance(WindowsIapPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<StorePurchaseStatus?> makePurchase(String storeId) {
    throw UnimplementedError('makePurchase() has not been implemented.');
  }

  Future<List<Product>> getProducts() {
    throw UnimplementedError('getProducts() has not been implemented.');
  }

  Future<bool> checkPurchase({required String storeId}) {
    throw UnimplementedError('checkPurchase() has not been implemented.');
  }

  Future<Map<String, StoreLicense>> getAddonLicenses() {
    throw UnimplementedError('getAddonLicenses() has not been implemented.');
  }
}
