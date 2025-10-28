import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/hkdf.dart';

class EncryptionUtils {
  static const int KEY_LENGTH = 32;
  static const int HKDF_LENGTH = 36;
  static const int MAC_LENGTH = 4;

  static Uint8List publicKeyToByteArray(ECPublicKey ecPublicKey) {
    final affineX = ecPublicKey.Q!.x!.toBigInteger();
    final affineY = ecPublicKey.Q!.y!.toBigInteger();
    final affineXUnsigned = _bigIntToUnsignedBytes(affineX!);
    final affineYUnsigned = _bigIntToUnsignedBytes(affineY!);
    return Uint8List.fromList([...affineXUnsigned, ...affineYUnsigned]);
  }

  static ECPublicKey generatePublicKey(Uint8List publicKeyBytes, ECDomainParameters params) {
    final bitLength = params.n.bitLength ~/ 8;
    final xBytes = publicKeyBytes.sublist(0, bitLength);
    final yBytes = publicKeyBytes.sublist(bitLength, 2 * bitLength);
    final x = BigInt.parse(xBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(), radix: 16);
    final y = BigInt.parse(yBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(), radix: 16);
    final ecPoint = params.curve.createPoint(x, y);
    return ECPublicKey(ecPoint, params);
  }

  static Uint8List generateSharedSecretBytes(ECPrivateKey privateKey, ECPublicKey serverPublicKey) {
    final ecdh = ECDHBasicAgreement();
    ecdh.init(privateKey);
    final sharedSecret = ecdh.calculateAgreement(serverPublicKey);
    return _bigIntToUnsignedBytes(sharedSecret);
  }

  static Uint8List generateHKDFBytes(Uint8List secretKey, Uint8List salt) {
    final hkdf = HKDFKeyDerivator(SHA256Digest());
    final params = HkdfParameters(secretKey, HKDF_LENGTH, salt);
    hkdf.init(params);
    final result = Uint8List(HKDF_LENGTH);
    hkdf.deriveKey(null, 0, result, 0);
    return result;
  }

  static Uint8List _bigIntToUnsignedBytes(BigInt number) {
    final bytes = number.toRadixString(16).padLeft((number.bitLength + 7) >> 3 << 1, '0');
    return Uint8List.fromList(
      List<int>.generate(bytes.length ~/ 2, (i) => int.parse(bytes.substring(i * 2, i * 2 + 2), radix: 16)),
    );
  }
}
