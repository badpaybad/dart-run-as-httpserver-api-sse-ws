import 'dart:convert';
import 'dart:typed_data';
import 'package:inceptor_genesis/inceptor_genesis.dart';
/// transaction se ma hoa key aes = buyer public key, buyer dung private key lay key aes. dung key aes de giai ma lay data  
class EncryptedKeyAes {
  String? base64EphemeralPublicKey;
  String? base64Iv;
  String? base64EncryptedAESKey;

  final StringCipher _cipher = StringCipher.instance;

  EncryptedKeyAes();
  // ma hoa key aes = public key
  EncryptedKeyAes setKeyAes(String publicKeyBase64, String keyAes) {
    var temp = _cipher.keyAesEncrypt(keyAes, publicKeyBase64);
    this.base64EphemeralPublicKey = temp.base64EphemeralPublicKey;
    this.base64Iv = temp.base64Iv;
    this.base64EncryptedAESKey = temp.base64EncryptedAESKey;

    return this;
  }
  /// gia ma lay key aes = private key
  String getKeyAes(String priveateKeyBase64) {
    return _cipher.keyAesDecrypt(this, priveateKeyBase64);
  }
  /// ma hoa data = key aes
  Uint8List encryptData(Uint8List dataRaw, String aesKey) {
    return _cipher.aesEncryptData(dataRaw, aesKey);
  }
  /// giai ma data = key aes 
  Uint8List decryptData(Uint8List encryptedData, String aesKey) {
    return _cipher.aesDecryptData(encryptedData, aesKey);
  }

  factory EncryptedKeyAes.fromJson(Map<String, dynamic> json) {
    EncryptedKeyAes tx = EncryptedKeyAes();
    tx.base64EphemeralPublicKey = json['base64EphemeralPublicKey'];
    tx.base64Iv = json['base64Iv'];
    tx.base64EncryptedAESKey = json['base64EncryptedAESKey'];

    return tx;
  }

  Map<String, dynamic> toJson() => {
    'base64EphemeralPublicKey': base64EphemeralPublicKey,
    'base64Iv': base64Iv,
    'base64EncryptedAESKey': base64EncryptedAESKey,
  };

  Map<String, dynamic> toMap() {
    return toJson();
  }

  static EncryptedKeyAes fromMap(Map<String, dynamic> map) {
    return EncryptedKeyAes.fromJson(map);
  }

  @override
  String toString() {
    return jsonEncode(this);
  }
}
