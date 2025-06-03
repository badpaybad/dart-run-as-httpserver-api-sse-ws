import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:inceptor_genesis/src/object_id.dart';
import 'package:pointycastle/export.dart';

class Cipher {
  AsymmetricKeyPair<ECPublicKey, ECPrivateKey> generateKeyPair({
    String yourSecretPhase = "",
  }) {
    if (yourSecretPhase.isEmpty) {
      yourSecretPhase = "${ObjectId()}";
    }
    Uint8List seedBytes = Uint8List.fromList(
      sha256.convert(utf8.encode(yourSecretPhase)).bytes,
    );

    final keyParams = ECKeyGeneratorParameters(ECCurve_secp256r1());
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
    final domainParams = ECCurve_secp256r1();
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

    final curve = ECCurve_secp256r1();
    final q = curve.curve.createPoint(x, y);

    return ECPublicKey(q, curve);
  }

  bool isKeyPairMatch(ECPrivateKey privateKey, ECPublicKey publicKey) {
    final curve = ECCurve_secp256r1();
    final domainParams = curve;

    // Derive public point from private key: Q = d * G
    final G = domainParams.G;
    final Q = G * privateKey.d!;

    // Check if the derived point matches the given public key
    return Q!.x!.toBigInteger() == publicKey.Q!.x!.toBigInteger() &&
        Q.y!.toBigInteger() == publicKey.Q!.y!.toBigInteger();
  }
}
