import 'package:d4rt/d4rt.dart';

Future<void> mainTest() async {
  final code = '''
import 'dart:io';
import 'dart:async';

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

  Future<String> main(String test) async {
    var client = HttpClient();
    try {
      HttpClientRequest request = await client.getUrl(Uri.parse('https://api.ipify.org?format=json'));
      // Optionally set up headers...
      // Optionally write to the request object...
      HttpClientResponse response = await request.close();
      // Process the response

      final list = await readBody(response);
      return String.fromCharCodes(list);
    } catch (e) {
      print('Error: \$e');
    } finally {
      client.close();
    }
  }
  ''';
  final interpreter = D4rt();
  interpreter.grant(NetworkPermission.any);
  interpreter.grant(FilesystemPermission.read);
  final result = await interpreter.execute(source: code, positionalArgs: ['Hello']);
  print('Result: $result'); // Result: 8

  // call whatismyip() function
}
