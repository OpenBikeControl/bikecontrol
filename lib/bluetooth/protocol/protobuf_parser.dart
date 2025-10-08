import 'dart:typed_data';

/// Utility class for parsing Protocol Buffer messages manually.
///
/// This is needed when the auto-generated protobuf classes don't correctly
/// handle embedded or non-standard Protocol Buffer structures, such as the
/// Zwift Ride analog paddle data.
///
/// Reference: https://developers.google.com/protocol-buffers/docs/encoding
class ProtobufParser {
  /// Decodes a ZigZag-encoded signed integer to its original value.
  ///
  /// ZigZag encoding maps signed integers to unsigned integers:
  /// - 0 -> 0, -1 -> 1, 1 -> 2, -2 -> 3, 2 -> 4, etc.
  ///
  /// Formula: (n >>> 1) ^ -(n & 1)
  static int zigzagDecode(int encoded) {
    return (encoded >>> 1) ^ -(encoded & 1);
  }

  /// Decodes a Protocol Buffer varint from a buffer at the given offset.
  ///
  /// Returns a record of (decodedValue, bytesConsumed).
  ///
  /// Varints use the most significant bit (MSB) of each byte as a continuation
  /// flag. If MSB is 1, there are more bytes to read. If MSB is 0, it's the
  /// last byte.
  static (int, int) decodeVarint(Uint8List buffer, int offset) {
    var value = 0;
    var shift = 0;
    var bytesRead = 0;

    while (offset + bytesRead < buffer.length) {
      final byte = buffer[offset + bytesRead];
      value |= (byte & 0x7f) << shift;
      bytesRead++;

      if ((byte & 0x80) == 0) {
        // MSB is 0, we're done
        break;
      }
      shift += 7;
    }

    return (value, bytesRead);
  }

  /// Extracts the field number from a Protocol Buffer tag byte.
  ///
  /// Tag format: (field_number << 3) | wire_type
  static int getFieldNumber(int tag) => tag >> 3;

  /// Extracts the wire type from a Protocol Buffer tag byte.
  ///
  /// Wire types:
  /// - 0: Varint (int32, int64, uint32, uint64, sint32, sint64, bool, enum)
  /// - 1: 64-bit (fixed64, sfixed64, double)
  /// - 2: Length-delimited (string, bytes, embedded messages, packed repeated)
  /// - 3: Start group (deprecated)
  /// - 4: End group (deprecated)
  /// - 5: 32-bit (fixed32, sfixed32, float)
  static int getWireType(int tag) => tag & 0x7;

  /// Skips a Protocol Buffer field based on its wire type.
  ///
  /// Returns the number of bytes skipped.
  static int skipField(Uint8List buffer, int offset, int wireType) {
    var bytesSkipped = 0;

    switch (wireType) {
      case 0: // Varint
        while (offset + bytesSkipped < buffer.length) {
          final byte = buffer[offset + bytesSkipped];
          bytesSkipped++;
          if ((byte & 0x80) == 0) break; // MSB is 0, done
        }
        break;

      case 2: // Length-delimited
        if (offset + bytesSkipped < buffer.length) {
          final length = buffer[offset + bytesSkipped];
          bytesSkipped += 1 + length;
        }
        break;

      // Wire types 1 (64-bit) and 5 (32-bit) are not used in our case
      // but could be implemented if needed
      default:
        // Unknown wire type, skip one byte
        bytesSkipped = 1;
    }

    return bytesSkipped;
  }

  /// Parses a Protocol Buffer message containing location and analog value.
  ///
  /// Expected fields:
  /// - Field 1: location (varint)
  /// - Field 2: analogValue (sint32, ZigZag encoded)
  ///
  /// Returns a map with 'location' and 'value' keys.
  static Map<String, int> parseLocationValue(Uint8List buffer) {
    int? location;
    int? analogValue;
    var offset = 0;

    while (offset < buffer.length) {
      final tag = buffer[offset];
      final fieldNum = getFieldNumber(tag);
      final wireType = getWireType(tag);
      offset++;

      if (fieldNum == 1 && wireType == 0) {
        // Parse location field (varint)
        final (value, bytesRead) = decodeVarint(buffer, offset);
        location = value;
        offset += bytesRead;
      } else if (fieldNum == 2 && wireType == 0) {
        // Parse analog value field (ZigZag encoded sint32)
        final (value, bytesRead) = decodeVarint(buffer, offset);
        analogValue = zigzagDecode(value);
        offset += bytesRead;
      } else {
        // Skip unknown fields
        offset += skipField(buffer, offset, wireType);
      }
    }

    return {
      'location': location ?? 0,
      'value': analogValue ?? 0,
    };
  }

  /// Parses a Protocol Buffer key group containing analog sensor data.
  ///
  /// Handles two formats:
  /// 1. Field 3 (wire type 2): Nested message containing location and value
  /// 2. Field 1 + Field 2 (wire type 0): Direct location and value fields
  ///
  /// Returns a map of location IDs to analog values.
  static Map<int, int> parseKeyGroup(Uint8List buffer) {
    final groupStatus = <int, int>{};
    var offset = 0;

    while (offset < buffer.length) {
      final tag = buffer[offset];
      final fieldNum = getFieldNumber(tag);
      final wireType = getWireType(tag);
      offset++;

      if (fieldNum == 3 && wireType == 2) {
        // Nested message format
        final length = buffer[offset++];
        final messageBuffer = buffer.sublist(offset, offset + length);
        final res = parseLocationValue(messageBuffer);
        groupStatus[res['location']!] = res['value']!;
        offset += length;
      } else if (fieldNum == 1 && wireType == 0) {
        // Direct field format - parse location
        final (location, locationBytes) = decodeVarint(buffer, offset);
        offset += locationBytes;

        // Parse corresponding value field
        if (offset < buffer.length) {
          final valueTag = buffer[offset];
          final valueFieldNum = getFieldNumber(valueTag);
          final valueWireType = getWireType(valueTag);
          offset++;

          if (valueFieldNum == 2 && valueWireType == 0) {
            final (value, valueBytes) = decodeVarint(buffer, offset);
            final decodedValue = zigzagDecode(value);
            groupStatus[location] = decodedValue;
            offset += valueBytes;
          }
        }
      } else {
        // Skip unknown fields
        offset += skipField(buffer, offset, wireType);
      }
    }

    return groupStatus;
  }

  /// Finds the offset to the next section with the given marker byte.
  ///
  /// Returns the number of bytes to skip to reach the next section,
  /// or the total length if no more sections exist.
  static int findNextMarker(Uint8List data, int marker) {
    for (var i = 1; i < data.length; i++) {
      if (data[i] == marker) {
        return i;
      }
    }
    return data.length;
  }
}
