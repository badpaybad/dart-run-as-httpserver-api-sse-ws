import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:inceptor_genesis/src/cipher.dart';
import 'package:inceptor_genesis/src/encrypted_key_aes.dart';
import 'package:inceptor_genesis/src/key_pair.dart';

class StringCipher {
  static final StringCipher instance = StringCipher._();

  StringCipher._();

  final Cipher _cipher = Cipher.instance;

  final Random random = Random.secure();

  String generateSha256(String input) {
    return _cipher.generateSha256(input); // Return as hex string
  }

  KeyPair<String, String> generate({String yourSecretPhase = ""}) {
    var kp = _cipher.generateKeyPair(yourSecretPhase: yourSecretPhase);

    var pripub = KeyPair(
      key: _cipher.encodePrivateKey(kp.privateKey),
      val: _cipher.encodePublicKey(kp.publicKey),
    );

    // var ismatch = _cipher.isKeyPairMatch(kp.privateKey, kp.publicKey);

    // var data = utf8.encode("dataToSign: nguyen phan du");
    // var signed = _cipher.sign(data, kp.privateKey);

    // var iverify = _cipher.verify(data, signed, kp.publicKey);

    // print("generate: $iverify $ismatch");

    return pripub;
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

  EncryptedKeyAes keyAesEncrypt(String keyAes, String publicKeyBase64) {
    return _cipher.encryptAESKey(
      utf8.encode(keyAes),
      _cipher.decodePublicKey(publicKeyBase64),
    );
  }

  String keyAesDecrypt(EncryptedKeyAes info, String privateKeyBase64) {
    var keyaes = _cipher.decryptAESKey(
      _cipher.decodePrivateKey(privateKeyBase64),
      info.base64EphemeralPublicKey!,
      info.base64Iv!,
      info.base64EncryptedAESKey!,
    );

    return utf8.decode(keyaes);
  }

  Uint8List aesEncryptData(Uint8List dataRaw, String aesKey) {
    var key = sha256.convert(utf8.encode(aesKey)).bytes;
    var iv = Uint8List.fromList(key.sublist(0, 16));

    return _cipher.aesEncryptData(dataRaw, Uint8List.fromList(key), iv);
  }

  Uint8List aesDecryptData(Uint8List dataEncrypted, String aesKey) {
    var key = sha256.convert(utf8.encode(aesKey)).bytes;
    var iv = Uint8List.fromList(key.sublist(0, 16));

    return _cipher.aesDecryptData(dataEncrypted, Uint8List.fromList(key), iv);
  }
}
