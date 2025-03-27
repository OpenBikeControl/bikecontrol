import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:swift_control/utils/crypto/encryption_utils.dart';

import 'local_key_provider.dart';

class ZapCrypto {
  final LocalKeyProvider localKeyProvider;
  final AESEngine aesEngine = AESEngine();

  Uint8List? encryptionKeyBytes;
  Uint8List? ivBytes;
  int counter = 0;

  ZapCrypto(this.localKeyProvider);

  void initialise(Uint8List devicePublicKeyBytes) {
    final hkdfBytes = generateHmacKeyDerivationFunctionBytes(devicePublicKeyBytes);
    encryptionKeyBytes = hkdfBytes.sublist(0, EncryptionUtils.KEY_LENGTH);
    ivBytes = hkdfBytes.sublist(32, EncryptionUtils.HKDF_LENGTH);
  }

  Uint8List encrypt(Uint8List data) {
    assert(encryptionKeyBytes != null && ivBytes != null, "Not initialised");

    final counterValue = counter;
    counter++;

    final nonceBytes = createNonce(ivBytes!, counterValue);
    final encrypted = encryptDecrypt(true, nonceBytes, data);
    return Uint8List.fromList(createCounterBytes(counterValue) + encrypted);
  }

  Uint8List decrypt(Uint8List counterArray, Uint8List payload) {
    assert(encryptionKeyBytes != null && ivBytes != null, "Not initialised");

    final nonceBytes = Uint8List.fromList(ivBytes! + counterArray);
    return encryptDecrypt(false, nonceBytes, payload);
  }

  Uint8List encryptDecrypt(bool encrypt, Uint8List nonceBytes, Uint8List data) {
    final aeadParameters = AEADParameters(
      KeyParameter(encryptionKeyBytes!),
      EncryptionUtils.MAC_LENGTH * 8,
      nonceBytes,
      Uint8List(0),
    );
    final ccmBlockCipher = CCMBlockCipher(aesEngine);
    ccmBlockCipher.init(encrypt, aeadParameters);
    final processed = Uint8List(ccmBlockCipher.getOutputSize(data.length));
    ccmBlockCipher.processBytes(data, 0, data.length, processed, 0);
    ccmBlockCipher.doFinal(processed, 0);
    return processed;
  }

  Uint8List generateHmacKeyDerivationFunctionBytes(Uint8List devicePublicKeyBytes) {
    final serverPublicKey = EncryptionUtils.generatePublicKey(
      devicePublicKeyBytes,
      localKeyProvider.getPublicKey().parameters!,
    );
    final sharedSecretBytes = EncryptionUtils.generateSharedSecretBytes(
      localKeyProvider.getPrivateKey(),
      serverPublicKey,
    );
    final salt = Uint8List.fromList(
      EncryptionUtils.publicKeyToByteArray(serverPublicKey) + localKeyProvider.getPublicKeyBytes(),
    );
    return EncryptionUtils.generateHKDFBytes(sharedSecretBytes, salt);
  }

  Uint8List createNonce(Uint8List iv, int messageCounter) {
    return Uint8List.fromList(iv + createCounterBytes(messageCounter));
  }

  Uint8List createCounterBytes(int messageCounter) {
    final buffer = ByteData(4);
    buffer.setInt32(0, messageCounter, Endian.big);
    return buffer.buffer.asUint8List();
  }
}
