import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ios_receipt_method_channel.dart';

abstract class IosReceiptPlatform extends PlatformInterface {
  /// Constructs a IosReceiptPlatform.
  IosReceiptPlatform() : super(token: _token);

  static final Object _token = Object();

  static IosReceiptPlatform _instance = MethodChannelIosReceipt();

  /// The default instance of [IosReceiptPlatform] to use.
  ///
  /// Defaults to [MethodChannelIosReceipt].
  static IosReceiptPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [IosReceiptPlatform] when
  /// they register themselves.
  static set instance(IosReceiptPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getAppleReceipt() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() {
    throw UnimplementedError('getAllTransactions() has not been implemented.');
  }
}
