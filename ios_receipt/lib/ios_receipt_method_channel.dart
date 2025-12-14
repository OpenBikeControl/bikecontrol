import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ios_receipt_platform_interface.dart';

/// An implementation of [IosReceiptPlatform] that uses method channels.
class MethodChannelIosReceipt extends IosReceiptPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ios_receipt');

  @override
  Future<String?> getAppleReceipt() async {
    final version = await methodChannel.invokeMethod<String>('getAppleReceipt');
    return version;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final list = await methodChannel.invokeMethod('getAllTransactions');
    return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
