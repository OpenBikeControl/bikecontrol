import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:swift_control/utils/crypto/encryption_utils.dart';

class LocalKeyProvider {
  late AsymmetricKeyPair<PublicKey, PrivateKey> pair;

  LocalKeyProvider() {
    generateKeyPair();
  }

  Uint8List getPublicKeyBytes() {
    return EncryptionUtils.publicKeyToByteArray(pair.publicKey as ECPublicKey);
  }

  ECPublicKey getPublicKey() {
    return pair.publicKey as ECPublicKey;
  }

  ECPrivateKey getPrivateKey() {
    return pair.privateKey as ECPrivateKey;
  }

  void generateKeyPair() {
    final keyParams = ECKeyGeneratorParameters(ECCurve_secp256r1());
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final keyGenerator = ECKeyGenerator();
    keyGenerator.init(ParametersWithRandom(keyParams, secureRandom));
    pair = keyGenerator.generateKeyPair();
  }
}
