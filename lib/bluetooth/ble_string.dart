import 'dart:convert';

/// Device Information strings are C strings, often in a fixed buffer.
/// Bytes after the NUL, 0xFF fill, or a non-UTF-8 tail render as tofu boxes
/// after an otherwise readable version such as `0.105`.
String? decodeBleDeviceInfoString(List<int> data) {
  if (data.isEmpty) return null;
  var end = data.length;
  final nul = data.indexOf(0);
  if (nul != -1) end = nul;
  while (end > 0 && data[end - 1] == 0xFF) {
    end--;
  }
  if (end == 0) return null;

  final bytes = data.sublist(0, end);
  final decoded = _decode(bytes);
  final cleaned = decoded.replaceAll(_unprintable, '').trim();
  return cleaned.isEmpty ? null : cleaned;
}

final _unprintable = RegExp(r'[\u0000-\u001F\u007F-\u009F\uE000-\uF8FF\uFFFD-\uFFFF]');

String _decode(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException catch (error) {
    // An incomplete multibyte character may precede the error offset.
    // The caller removes any resulting replacement characters during cleanup.
    return utf8.decode(bytes.sublist(0, error.offset ?? 0), allowMalformed: true);
  }
}
