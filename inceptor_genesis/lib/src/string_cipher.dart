import 'dart:convert';
import 'package:inceptor_genesis/src/cipher.dart';
import 'package:inceptor_genesis/src/key_pair.dart';

class StringCipher {
  final Cipher _cipher = Cipher();

  KeyPair<String, String> generate({String yourSecretPhase = ""}) {
    var kp = _cipher.generateKeyPair(yourSecretPhase: yourSecretPhase);

    return KeyPair(
      key: _cipher.encodePrivateKey(kp.privateKey),
      val: _cipher.encodePublicKey(kp.publicKey),
    );
  }

  String sign(String dataRaw, String priveateKeyBase64) {
    var signed = _cipher.sign(
      utf8.encode(dataRaw),
      _cipher.decodePrivateKey(priveateKeyBase64),
    );

    return base64Encode(signed);
  }

  bool verify(String dataRaw, String signedBase64, String publicKeyBase64) {
    return _cipher.verify(
      utf8.encode(dataRaw),
      base64Decode(signedBase64),
      _cipher.decodePublicKey(publicKeyBase64),
    );
  }

  bool isKeyPairMatch(String privateKeyBase64, String publicKeyBase64) {
    return _cipher.isKeyPairMatch(
      _cipher.decodePrivateKey(privateKeyBase64),
      _cipher.decodePublicKey(publicKeyBase64),
    );
  }
}
