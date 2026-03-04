import 'dart:io';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/core.dart';
import 'package:d4rt/d4rt.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const String kDefaultDeviceScript = '''
import 'dart:io';
import 'dart:async';

Future<List<dynamic>> main(String characteristicUuid, List<int> data) async {
  var client = HttpClient();

  try {
    HttpClientRequest request = await client.getUrl(Uri.parse('https://api.ipify.org?format=json'));
    // Optionally set up headers...
    // Optionally write to the request object...
    HttpClientResponse response = await request.close();
    // Process the response

    final list = await readBody(response);
    return [characteristicUuid, list];
  } catch (e) {
    print('Error: \$e');
  } finally {
    client.close();
  }
}
  
  
Future<List<int>> readBody(HttpClientResponse response) async {
  final completer = Completer<List<int>>();
  final bytes = <int>[];

  response.listen(
    (chunk) => bytes.addAll(chunk),
    onDone: () => completer.complete(bytes),
    onError: (e, st) => completer.completeError(e, st),
    cancelOnError: true,
  );

  final allBytes = await completer.future;
  return allBytes;
}


''';

class ScriptValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ScriptValidationResult.valid() : isValid = true, errorMessage = null;

  const ScriptValidationResult.invalid(this.errorMessage) : isValid = false;
}

class ScriptExecutionResult {
  final String characteristicUuid;
  final Uint8List data;

  const ScriptExecutionResult({
    required this.characteristicUuid,
    required this.data,
  });
}

class DeviceScriptService {
  DeviceScriptService._();

  static final DeviceScriptService instance = DeviceScriptService._();

  final Map<String, String> _customScriptCache = {};
  final Set<String> _missingScriptCache = <String>{};

  Future<String> loadScriptForEditing(String deviceType) async {
    final script = await _loadCustomScript(deviceType);
    return script ?? kDefaultDeviceScript;
  }

  Future<bool> hasCustomScript(String deviceType) async {
    if (kIsWeb) {
      return false;
    }

    if (_customScriptCache.containsKey(deviceType)) {
      return true;
    }

    if (_missingScriptCache.contains(deviceType)) {
      return false;
    }

    final file = await _scriptFileForDeviceType(deviceType);
    final exists = await file.exists();
    if (!exists) {
      _missingScriptCache.add(deviceType);
    }
    return exists;
  }

  Future<ScriptValidationResult> saveScript({
    required String deviceType,
    required String source,
  }) async {
    if (kIsWeb) {
      return ScriptValidationResult.invalid('Script files are not supported on web.');
    }

    final cleaned = source.replaceAll('BikeControl', '').replaceAll('Bike Control', '').replaceAll('bikecontrol', '');
    final validation = validateScript(cleaned);
    if (!validation.isValid) {
      return validation;
    }

    final file = await _scriptFileForDeviceType(deviceType);
    await file.writeAsString(cleaned, flush: true);

    _customScriptCache[deviceType] = source;
    _missingScriptCache.remove(deviceType);

    return const ScriptValidationResult.valid();
  }

  Future<void> deleteScript(String deviceType) async {
    if (kIsWeb) {
      return;
    }

    final file = await _scriptFileForDeviceType(deviceType);
    if (await file.exists()) {
      await file.delete();
    }

    _customScriptCache.remove(deviceType);
    _missingScriptCache.add(deviceType);
  }

  ScriptValidationResult validateScript(String source) {
    try {
      final interpreter = D4rt();
      interpreter.grant(NetworkPermission.any);
      interpreter.grant(FilesystemPermission.read);
      final introspection = interpreter.analyze(source: source);

      FunctionInfo? mainFunction;
      for (final function in introspection.functions) {
        if (function.name == 'main') {
          mainFunction = function;
          break;
        }
      }

      if (mainFunction == null) {
        return ScriptValidationResult.invalid('The script must declare a top-level main function.');
      }

      if (mainFunction.arity != 2 ||
          mainFunction.parameterNames.length != 2 ||
          mainFunction.namedParameterNames.isNotEmpty) {
        return ScriptValidationResult.invalid(
          'main must have exactly two positional parameters: (String characteristicUuid, List<int> data).',
        );
      }

      final returnType = (mainFunction.returnType ?? '').replaceAll(' ', '');
      final returnsList =
          returnType == 'List' ||
          returnType.startsWith('List<') ||
          returnType == 'Future<List>' ||
          returnType.startsWith('Future<List<');

      if (!returnsList) {
        return ScriptValidationResult.invalid(
          'main must return List<dynamic> or Future<List<dynamic>>.',
        );
      }

      return const ScriptValidationResult.valid();
    } catch (e) {
      return ScriptValidationResult.invalid(e.toString());
    }
  }

  Future<ScriptExecutionResult?> runCustomScript({
    required String deviceType,
    required String characteristicUuid,
    required Uint8List data,
  }) async {
    final source = await _loadCustomScript(deviceType);
    if (source == null) {
      return null;
    }

    return runScriptSource(
      source: source,
      characteristicUuid: characteristicUuid,
      data: data,
      deviceTypeForLog: deviceType,
    );
  }

  Future<ScriptExecutionResult> runScriptSource({
    required String source,
    required String characteristicUuid,
    required Uint8List data,
    String? deviceTypeForLog,
  }) async {
    core.connection.signalNotification(
      LogNotification(
        'Running custom script${deviceTypeForLog != null ? ' for device type "$deviceTypeForLog"' : ''} with characteristic $characteristicUuid input data: ${data.join()}',
      ),
    );

    final interpreter = D4rt();
    interpreter.grant(NetworkPermission.any);
    interpreter.grant(FilesystemPermission.read);
    final result = await interpreter.execute(
      source: source,
      positionalArgs: [characteristicUuid, data.toList()],
    );

    if (result is! List || result.length < 2) {
      throw const FormatException('Script output must be [characteristicUuid, data].');
    }

    final outputCharacteristic = result[0];
    final outputData = _parseData(result[1]);

    if (outputCharacteristic is! String || outputCharacteristic.trim().isEmpty) {
      throw const FormatException('The first output item must be a non-empty String UUID.');
    }

    if (outputData == null) {
      throw const FormatException('The second output item must be a List<int> (0..255).');
    }

    return ScriptExecutionResult(
      characteristicUuid: outputCharacteristic.trim().toLowerCase(),
      data: outputData,
    );
  }

  Future<String?> _loadCustomScript(String deviceType) async {
    if (kIsWeb) {
      return null;
    }

    final cached = _customScriptCache[deviceType];
    if (cached != null) {
      return cached;
    }

    if (_missingScriptCache.contains(deviceType)) {
      return null;
    }

    final file = await _scriptFileForDeviceType(deviceType);
    if (!await file.exists()) {
      _missingScriptCache.add(deviceType);
      return null;
    }

    final script = await file.readAsString();
    _customScriptCache[deviceType] = script;
    return script;
  }

  Future<File> _scriptFileForDeviceType(String deviceType) async {
    final baseDirectory = await getApplicationSupportDirectory();
    final scriptDirectory = Directory('${baseDirectory.path}${Platform.pathSeparator}device_scripts');
    if (!await scriptDirectory.exists()) {
      await scriptDirectory.create(recursive: true);
    }

    final sanitizedType = _sanitizeDeviceType(deviceType);
    return File('${scriptDirectory.path}${Platform.pathSeparator}$sanitizedType.dart');
  }

  Uint8List? _parseData(dynamic raw) {
    if (raw is Uint8List) {
      return raw;
    }

    if (raw is! List) {
      return null;
    }

    final bytes = <int>[];
    for (final value in raw) {
      if (value is! num) {
        return null;
      }

      final byteValue = value.toInt();
      if (byteValue < 0 || byteValue > 255) {
        return null;
      }

      bytes.add(byteValue);
    }

    return Uint8List.fromList(bytes);
  }

  String _sanitizeDeviceType(String deviceType) {
    return deviceType.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }
}
