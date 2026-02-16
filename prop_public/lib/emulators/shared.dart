//INFO: This is a stub - contact me if you need the full implementation.

import 'package:flutter/foundation.dart';

class SharedLogic {
  static Uint8List? handleWriteRequest(String characteristic, Uint8List value) {
    return null;
  }

  static Future<void> keepAlive() async {}

  static void stopKeepAlive() {}
}

class Logger {
  static void info(String text) {
    if (kDebugMode) {
      print('${DateTime.now()} \x1B[32m$text\x1B[0m');
    }
  }

  static void warn(String text) {
    if (kDebugMode) {
      print('\x1B[33m$text\x1B[0m');
    }
  }

  static void error(String text) {
    if (kDebugMode) {
      print('\x1B[31m$text\x1B[0m');
    }
  }

  static void debug(String s) {
    if (kDebugMode) {
      print('\x1B[34m$s\x1B[0m');
    }
  }
}
