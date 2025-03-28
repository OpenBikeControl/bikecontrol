import 'dart:developer';

class UniversalLogger {
  static void logInfo(message) {
    log(
      message.toString(),
      name: 'UniversalBle:INFO',
    );
  }

  static void logError(message) {
    log(
      '\x1B[31m$message\x1B[31m',
      name: 'UniversalBle:ERROR',
    );
  }

  static void logWarning(message) {
    log(
      '\x1B[33m$message\x1B[33m',
      name: 'UniversalBle:WARN',
    );
  }
}
