import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'multi_window_native_platform_interface.dart';

typedef MethodCallHandler = Future<void> Function(MethodCall call);

/// An implementation of [MultiWindowNativePlatform] that uses method channels.
class MethodChannelMultiWindowNative extends MultiWindowNativePlatform {
  /// The method channel used to interact with the native platform.
  // Get the current window's BinaryMessenger
  static final BinaryMessenger messenger =
      ServicesBinding.instance.defaultBinaryMessenger;
  static final methodChannel = MethodChannel(
    'com.coditas.multi_window_native/pluginChannel',
    const StandardMethodCodec(),
    messenger,
  );
  static final _listeners = <String, Set<_ListenerWrapper>>{};

  static String registerListener(String methodName, MethodCallHandler handler) {
    final wrapper = _ListenerWrapper(
      id: UniqueKey().toString(),
      handler: handler,
    );
    _listeners.putIfAbsent(methodName, () => {}).add(wrapper);
    return wrapper.id; // Return the ID for later unregistering
  }

  static void unregisterListener({
    required String methodName,
    required String id,
  }) {
    _listeners[methodName]?.removeWhere((wrapper) => wrapper.id == id);
  }

  static void init(int windowId) {
    methodChannel.setMethodCallHandler(handleMethodCall);
    methodChannel.invokeMethod("setWindowId", {"windowId": windowId.toString()});
  }

  static Future<void> handleMethodCall(MethodCall call) async {
    final wrappers = _listeners[call.method];
    if (wrappers == null || wrappers.isEmpty) {
      throw MissingPluginException('No handler for ${call.method}');
    }

    for (var wrapper in wrappers) {
      wrapper.handler(call);
    }
  }

  // @override
  // Future<String?> getPlatformVersion() async {
  //   return await methodChannel.invokeMethod<String>('getPlatformVersion');
  // }

  @override
  Future<void> createAndRegisterWindow({
    required final String routeName,
    required final String theme,
    final String? argsJson,
    final void Function()? onCreation,
  }) async {
    // Call native method to create window
    onCreation?.call();
    await methodChannel.invokeMethod('createWindow', <String, dynamic>{
      "routeName": routeName,
      "argsJson": argsJson ?? '{}',
      "theme": theme,
    });
  }

  @override
  Future<int> getMessengerCount() async {
    try {
      final int? count = await methodChannel.invokeMethod<int>(
        'getMessengerCount',
      );
      return count ?? 1; // Fallback to 1 in case of error
    } catch (e) {
      return 1;
    }
  }

  @override
  Future<void> notifyWindowClose({required bool isMainWindow, required String windowId}) async {
    await methodChannel.invokeMethod('closeWindow', <String, dynamic>{
      "isMainWindow": isMainWindow,
      "windowId": windowId,
    });
  }

  @override
  Future<bool> notifyUiReady() async {
    return await methodChannel.invokeMethod('notifyUiReady');
  }

  @override
  /// Send data to native
  Future<void> notifyAllWindows(String method, dynamic arguments) async {
    await methodChannel.invokeMethod(method, arguments);
  }
}

class _ListenerWrapper {
  final String id;
  final MethodCallHandler handler;

  _ListenerWrapper({required this.id, required this.handler});
}
