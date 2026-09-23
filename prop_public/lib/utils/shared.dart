//INFO: This is a stub - contact me if you need the full implementation.

import 'package:flutter/foundation.dart';

/// Stubbed shared emulator helpers. The full implementation handles the
/// Zwift Click handshake / device-info responses and iOS keep-alive audio.
class SharedLogic {
  static Uint8List? handleWriteRequest(String characteristic, Uint8List value) {
    return null;
  }

  static void keepAlive() {}

  static void stopKeepAlive() {}
}

class Logger {
  /// Wired by the app to its crash reporting / debug log. Kept in the stub so
  /// error routing compiles even without the full implementation.
  static void Function(String message, Object exception, StackTrace? stackTrace)? onRecordError;

  static void recordError(String message, Object exception, StackTrace? stackTrace) {
    error('$message: $exception');
    try {
      onRecordError?.call(message, exception, stackTrace);
    } catch (e, s) {
      error('Logger.onRecordError listener failed: $e\n$s');
    }
  }

  static void info(String text) {
    if (kDebugMode) {
      print('${DateTime.now()} \x1B[32m$text\x1B[0m');
    }
  }

  static void warn(String text) {
    if (kDebugMode) {
      print('${DateTime.now()} \x1B[33m$text\x1B[0m');
    }
  }

  static void error(String text) {
    if (kDebugMode) {
      print('${DateTime.now()} \x1B[31m$text\x1B[0m');
    }
  }

  /// Sink for verbose wire traces. Wired by the app so the lines can reach a
  /// support bundle from a release build; null (the default) makes [trace] a
  /// no-op outside debug builds.
  static void Function(String message)? onTrace;

  /// Emit a verbose wire trace. [build] runs only when a sink is attached or
  /// the build is a debug build.
  static void trace(String Function() build, {bool record = true}) {
    if (!kDebugMode && (!record || onTrace == null)) return;
    final text = build();
    if (kDebugMode) debug(text);
    if (record) onTrace?.call(text);
  }

  static void debug(String s) {
    if (kDebugMode && false) {
      print('\x1B[34m$s\x1B[0m');
    }
  }
}

extension UuidDash on String {
  String toNonDash() {
    return replaceAll('-', '');
  }

  String toUUID() {
    return '${substring(0, 8)}-${substring(8, 12)}-${substring(12, 16)}-${substring(16, 20)}-${substring(20)}';
  }
}

extension ByteList on List<int> {
  int takeUInt8() {
    final value = this[0];
    removeAt(0);
    return value;
  }

  int readUInt8(int offset) {
    return this[offset];
  }

  int takeUInt16BE() {
    final value = (this[0] << 8) | this[0 + 1];
    removeAt(0);
    removeAt(0);
    return value;
  }

  List<int> takeBytes(int length) {
    final value = sublist(0, length);
    removeRange(0, length);
    return value;
  }

  int readUInt16BE(int i) {
    final value = (this[i] << 8) | this[i + 1];
    return value;
  }
}
