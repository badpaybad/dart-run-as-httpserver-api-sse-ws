import 'dart:convert';
import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:inceptor_genesis/src/encrypted_key_aes.dart';
import 'package:inceptor_genesis/src/object_id.dart';
import 'package:pointycastle/export.dart';

class Cipher {
  static final Cipher instance = Cipher._();

  Cipher._();

  AsymmetricKeyPair<ECPublicKey, ECPrivateKey> generateKeyPair({
    String yourSecretPhase = "",
  }) {
    if (yourSecretPhase.isEmpty) {
      yourSecretPhase = "${ObjectId()}";
    }
    Uint8List seedBytes = Uint8List.fromList(
      sha256.convert(utf8.encode(yourSecretPhase)).bytes,
    );

    final keyParams = ECKeyGeneratorParameters(domainParamsEphemeral);
    // final keyParams = ECKeyGeneratorParameters(ECCurve_secp256r1());
    final secureRandom =
        FortunaRandom()..seed(
          KeyParameter(
            seedBytes,
            // Uint8List.fromList(
            //   List.generate(
            //     32,
            //     (_) => DateTime.now().millisecondsSinceEpoch % 256,
            //   ),
            // ),
          ),
        );
    final generator =
        ECKeyGenerator()..init(ParametersWithRandom(keyParams, secureRandom));
    return generator.generateKeyPair();
  }

  // Hàm ký dữ liệu (input là Uint8List)
  Uint8List sign(Uint8List dataToSign, ECPrivateKey privateKey) {
    final signer = Signer('SHA-256/ECDSA');

    // Khởi tạo secure random đúng cách
    final secureRandom = FortunaRandom();
    final seed = Uint8List.fromList(
      List.generate(32, (_) => DateTime.now().millisecondsSinceEpoch % 256),
    );
    secureRandom.seed(KeyParameter(seed));

    final privParams = PrivateKeyParameter<ECPrivateKey>(privateKey);
    final params = ParametersWithRandom(privParams, secureRandom);

    signer.init(true, params);

    ECSignature sig = signer.generateSignature(dataToSign) as ECSignature;

    final rBytes = sig.r.toRadixString(16).padLeft(64, '0');
    final sBytes = sig.s.toRadixString(16).padLeft(64, '0');

    return Uint8List.fromList(hex.decode(rBytes + sBytes));
  }

  // Hàm xác minh chữ ký
  bool verify(Uint8List data, Uint8List signatureBytes, ECPublicKey publicKey) {
    final signer = Signer('SHA-256/ECDSA');
    final pubParams = PublicKeyParameter<ECPublicKey>(publicKey);
    signer.init(false, pubParams);

    // Tách r, s từ signatureBytes (64 bytes)
    final r = BigInt.parse(
      hex.encode(signatureBytes.sublist(0, 32)),
      radix: 16,
    );
    final s = BigInt.parse(
      hex.encode(signatureBytes.sublist(32, 64)),
      radix: 16,
    );
    final signature = ECSignature(r, s);

    return signer.verifySignature(data, signature);
  }

  String encodePrivateKey(ECPrivateKey privateKey) {
    final dBytes = privateKey.d!.toRadixString(16).padLeft(64, '0');
    return base64Encode(hex.decode(dBytes));
  }

  String encodePublicKey(ECPublicKey publicKey) {
    final x = publicKey.Q!.x!
        .toBigInteger()!
        .toRadixString(16)
        .padLeft(64, '0');
    final y = publicKey.Q!.y!
        .toBigInteger()!
        .toRadixString(16)
        .padLeft(64, '0');

    final publicKeyBytes = hex.decode(
      '04$x$y',
    ); // Uncompressed format (starts with 0x04)
    return base64Encode(publicKeyBytes);
  }

  // Giải mã privateKey từ Base64
  ECPrivateKey decodePrivateKey(String base64PrivateKey) {
    final dBytes = base64Decode(base64PrivateKey);
    final d = BigInt.parse(hex.encode(dBytes), radix: 16);
    final domainParams = domainParamsEphemeral; //ECCurve_secp256r1();
    return ECPrivateKey(d, domainParams);
  }

  // Giải mã publicKey từ Base64 (định dạng uncompressed 04 + x + y)
  ECPublicKey decodePublicKey(String base64PublicKey) {
    final pubBytes = base64Decode(base64PublicKey);

    if (pubBytes[0] != 0x04) {
      throw ArgumentError(
        'Public key không ở định dạng uncompressed (phải bắt đầu bằng 0x04)',
      );
    }

    final xBytes = pubBytes.sublist(1, 33);
    final yBytes = pubBytes.sublist(33, 65);

    final x = BigInt.parse(hex.encode(xBytes), radix: 16);
    final y = BigInt.parse(hex.encode(yBytes), radix: 16);

    final curve = domainParamsEphemeral; //ECCurve_secp256r1();
    final q = curve.curve.createPoint(x, y);

    return ECPublicKey(q, curve);
  }

  bool isKeyPairMatch(ECPrivateKey privateKey, ECPublicKey publicKey) {
    final curve = domainParamsEphemeral; // ECCurve_secp256r1();
    final domainParams = curve;

    // Derive public point from private key: Q = d * G
    final G = domainParams.G;
    final Q = G * privateKey.d!;

    // Check if the derived point matches the given public key
    return Q!.x!.toBigInteger() == publicKey.Q!.x!.toBigInteger() &&
        Q.y!.toBigInteger() == publicKey.Q!.y!.toBigInteger();
  }

  String generateSha256(String input) {
    final bytes = utf8.encode(input); // Convert to UTF8
    final digest = sha256.convert(bytes); // Perform SHA-256 hashing
    return digest.toString(); // Return as hex string
  }

  final ECDomainParameters domainParamsEphemeral = ECCurve_secp256r1();
}

extension AesCipher on Cipher {
  Uint8List aesEncryptData(
    Uint8List dataRaw,
    Uint8List aesKey32bytes,
    Uint8List iv16bytes,
  ) {
    final paddedCipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );

    paddedCipher.init(
      true, // true = encryption
      PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
        ParametersWithIV(KeyParameter(aesKey32bytes), iv16bytes),
        null,
      ),
    );

    return paddedCipher.process(dataRaw);
  }

  Uint8List aesDecryptData(
    Uint8List encryptedData,
    Uint8List aesKey32bytes,
    Uint8List iv16bytes,
  ) {
    final paddedCipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );

    paddedCipher.init(
      false, // true = decryption
      PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
        ParametersWithIV(KeyParameter(aesKey32bytes), iv16bytes),
        null,
      ),
    );
    return paddedCipher.process(encryptedData);
  }

  /// Mã hóa AES key bằng ECIES (trả về ephemeralPublicKey + encrypted AES key)
  EncryptedKeyAes encryptAESKey(Uint8List aesKey, ECPublicKey buyerPublicKey) {
    // 1. Tạo ephemeral key pair
    final ephemeralKeys = generateKeyPair(
      yourSecretPhase: "$ObjectId() $_getSecureRandom() ${encodePublicKey(buyerPublicKey)}",
    );

    //   var xxx=encodePublicKey(ephemeralKeys.publicKey);
    //  var temp= decodePublicKey(xxx);

    // 2. Tạo shared secret (ephemeral private key + buyer public key)
    final sharedSecret = _generateSharedSecret(
      ephemeralKeys.privateKey,
      buyerPublicKey,
    );

    // 3. Tạo AES key từ shared secret (ở đây dùng SHA256)
    final aesKeyForEnc = sha256.convert(sharedSecret).bytes;

    // 4. Mã hóa AES key (gốc) bằng AES-256-CBC với key là aesKeyForEnc
    final iv = _generateRandomBytes(16);
    final cipher = CBCBlockCipher(AESEngine())..init(
      true,
      ParametersWithIV(KeyParameter(Uint8List.fromList(aesKeyForEnc)), iv),
    );

    final paddedAESKey = _pkcs7Pad(aesKey, 16);
    final encryptedAESKey = _processBlocks(cipher, paddedAESKey);

    // 5. Trả về:
    // - ephemeral public key (định dạng uncompressed Base64)
    // - iv (Base64)
    // - encrypted AES key (Base64)
    EncryptedKeyAes res = EncryptedKeyAes();

    res.base64EphemeralPublicKey = encodePublicKey(ephemeralKeys.publicKey);
    res.base64Iv = base64Encode(iv);
    res.base64EncryptedAESKey = base64Encode(encryptedAESKey);
    return res;
  }

  /// Giải mã AES key bằng ECIES (dùng private key người mua và dữ liệu nhận được)
  Uint8List decryptAESKey(
    ECPrivateKey buyerPrivateKey,
    String base64EphemeralPublicKey,
    String base64Iv,
    String base64EncryptedAESKey,
  ) {
    // 1. Giải mã ephemeral public key
    final ephemeralPubKey = decodePublicKey(base64EphemeralPublicKey);

    // 2. Tạo shared secret (private key người mua + ephemeral public key)
    final sharedSecret = _generateSharedSecret(
      buyerPrivateKey,
      ephemeralPubKey,
    );

    // 3. Tạo AES key từ shared secret (SHA256)
    final aesKeyForDec = sha256.convert(sharedSecret).bytes;

    // 4. Giải mã AES key bằng AES-256-CBC với key aesKeyForDec
    final iv = base64Decode(base64Iv);
    final encryptedAESKey = base64Decode(base64EncryptedAESKey);

    final cipher = CBCBlockCipher(AESEngine())..init(
      false,
      ParametersWithIV(KeyParameter(Uint8List.fromList(aesKeyForDec)), iv),
    );

    final decryptedPadded = _processBlocks(cipher, encryptedAESKey);
    final decrypted = _pkcs7Unpad(decryptedPadded);

    return decrypted;
  }

  /// Tạo shared secret từ private key & public key ECC
  Uint8List _generateSharedSecret(ECPrivateKey privKey, ECPublicKey pubKey) {
    final sharedPoint = pubKey.Q! * privKey.d!;
    final x = sharedPoint?.x?.toBigInteger()!;
    // Dùng x coordinate làm shared secret (64 bytes có thể nén)
    final sharedSecret = _bigIntToBytes(x!, 32);
    return sharedSecret;
  }

  /// Sinh random bytes (IV, Key)
  Uint8List _generateRandomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rnd.nextInt(256)));
  }

  // /// Sinh ephemeral keypair mới
  // AsymmetricKeyPair<ECPublicKey, ECPrivateKey> generateEphemeralKeyPair() {
  //   final secureRandom = _getSecureRandom();
  //   final keyParams = ECKeyGeneratorParameters(domainParamsEphemeral);
  //   final generator = ECKeyGenerator();
  //   generator.init(ParametersWithRandom(keyParams, secureRandom));
  //   return generator.generateKeyPair();
  // }

  Uint8List _bigIntToBytes(BigInt number, int length) {
    final bytes = number
        .toUnsigned(8 * length)
        .toRadixString(16)
        .padLeft(length * 2, '0');
    return Uint8List.fromList(hex.decode(bytes));
  }

  SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final seed = Uint8List(32);
    final rnd = Random.secure();
    for (int i = 0; i < seed.length; i++) {
      seed[i] = rnd.nextInt(256);
    }
    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }

  Uint8List _processBlocks(BlockCipher cipher, Uint8List input) {
    final output = Uint8List(input.length);
    for (int offset = 0; offset < input.length;) {
      offset += cipher.processBlock(input, offset, output, offset);
    }
    return output;
  }

  Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padLen = blockSize - (data.length % blockSize);
    return Uint8List.fromList(data + List.filled(padLen, padLen));
  }

  Uint8List _pkcs7Unpad(Uint8List paddedData) {
    final padLen = paddedData.last;
    return paddedData.sublist(0, paddedData.length - padLen);
  }

  // // Encode public key dạng uncompressed (0x04 + X + Y)
  // Uint8List _encodePublicKeyEyephemeral(ECPublicKey publicKey) {
  //   final x = publicKey.Q!.x!.toBigInteger()!;
  //   final y = publicKey.Q!.y!.toBigInteger()!;

  //   final xBytes = _bigIntToBytes(x, 32);
  //   final yBytes = _bigIntToBytes(y, 32);

  //   return Uint8List.fromList([0x04] + xBytes + yBytes);
  // }

  // // Giải mã public key uncompressed base64
  // ECPublicKey _decodePublicEyephemeral(String base64PublicKey) {
  //   final pubBytes = base64Decode(base64PublicKey);

  //   if (pubBytes[0] != 0x04) {
  //     throw ArgumentError(
  //       'Public key không ở dạng uncompressed (phải bắt đầu bằng 0x04)',
  //     );
  //   }

  //   final xBytes = pubBytes.sublist(1, 33);
  //   final yBytes = pubBytes.sublist(33, 65);

  //   final x = BigInt.parse(hex.encode(xBytes), radix: 16);
  //   final y = BigInt.parse(hex.encode(yBytes), radix: 16);

  //   final q = domainParamsEphemeral.curve.createPoint(x, y);
  //   return ECPublicKey(q, domainParamsEphemeral);
  // }
}

// extension AesHelper on Cipher {
//   /// Sinh AES key (32 bytes) từ passphrase
//   Uint8List deriveKeyFromPassphrase(String passphrase) {
//     return Uint8List.fromList(sha256.convert(utf8.encode(passphrase)).bytes);
//   }

//   /// Mã hóa dữ liệu bằng AES-256-CBC
//   Map<String, String> aesEncrypt(String plainText, Uint8List aesKey) {
//     final iv = _generateRandomBytes(16); // IV phải là 16 bytes
//     final paddedText = _pkcs7Pad(
//       Uint8List.fromList(utf8.encode(plainText)),
//       16,
//     );

//     final cipher = CBCBlockCipher(AESFastEngine())
//       ..init(true, ParametersWithIV(KeyParameter(aesKey), iv));

//     final encrypted = _processBlocks(cipher, paddedText);

//     return {'ciphertext': base64Encode(encrypted), 'iv': base64Encode(iv)};
//   }

//   /// Giải mã AES-256-CBC
//   String aesDecrypt(
//     String base64Ciphertext,
//     String base64Iv,
//     Uint8List aesKey,
//   ) {
//     final iv = base64Decode(base64Iv);
//     final encryptedBytes = base64Decode(base64Ciphertext);

//     final cipher = CBCBlockCipher(AESFastEngine())
//       ..init(false, ParametersWithIV(KeyParameter(aesKey), iv));

//     final decryptedPadded = _processBlocks(cipher, encryptedBytes);
//     final decrypted = _pkcs7Unpad(decryptedPadded);

//     return utf8.decode(decrypted);
//   }

//   /// Sinh random bytes (IV, Key)
//   Uint8List _generateRandomBytes(int length) {
//     final rnd = Random.secure();
//     return Uint8List.fromList(List.generate(length, (_) => rnd.nextInt(256)));
//   }

//   /// Pad dữ liệu theo PKCS7
//   Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
//     final padLen = blockSize - (data.length % blockSize);
//     return Uint8List.fromList(data + List.filled(padLen, padLen));
//   }

//   /// Bỏ padding PKCS7
//   Uint8List _pkcs7Unpad(Uint8List paddedData) {
//     final padLen = paddedData.last;
//     return paddedData.sublist(0, paddedData.length - padLen);
//   }

//   /// Block processing
//   Uint8List _processBlocks(BlockCipher cipher, Uint8List input) {
//     final output = Uint8List(input.length);
//     for (int offset = 0; offset < input.length;) {
//       offset += cipher.processBlock(input, offset, output, offset);
//     }
//     return output;
//   }
// }
