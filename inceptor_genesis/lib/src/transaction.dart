import 'dart:convert';

import 'package:inceptor_genesis/inceptor_genesis.dart';
import 'package:inceptor_genesis/src/encrypted_key_aes.dart';

class Transaction {
  String id = "${ObjectId()}";
  String? fromId;
  String? sender;
  String? recipient;
  String? type;
  String? data;
  double? amount;
  double? fee;
  int? timestamp;
  String? signature;
  //keyAes=EncryptedKeyAes().build(address-publickey,'your secret'); data=StringCipher.instance.aesDecryptData(dataraw,'your secret')
  EncryptedKeyAes? keyAes;
  Transaction() {}

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromId': fromId,
    'sender': sender,
    'recipient': recipient,
    'type': type,
    'data': data,
    'amount': amount,
    'fee': fee,
    'timestamp': timestamp,
    'signature': signature,
    'keyAes': keyAes,
  };

  Transaction clone() {
    var cloned = Transaction.fromJson(this.toJson());
    cloned.signature = null;
    cloned.fromId = this.id;
    return cloned;
  }

  String dataToSign() {
    return "$id $fromId $sender $recipient $type $data $amount $fee $timestamp $keyAes";
  }

  void sign(String priveateKeyBase64) {
    var dataRaw = dataToSign();
    signature = StringCipher.instance.sign(dataRaw, priveateKeyBase64);
  }

  bool verify(String publicKeyBase64) {
    var dataRaw = dataToSign();
    return StringCipher.instance.verify(dataRaw, signature!, publicKeyBase64);
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    double amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    double fee = (json['fee'] as num?)?.toDouble() ?? 0.0;

    Transaction tx = Transaction();
    tx.id = json['id'];
    tx.fromId = json['fromId'];
    tx.sender = json['sender'];
    tx.recipient = json['recipient'];
    tx.type = json['type'];
    tx.data = json['data'];
    tx.amount = amount;
    tx.fee = fee;
    tx.timestamp = json['timestamp'];
    tx.signature = json['signature'];
    tx.keyAes =
        json['keyAes'] == null
            ? null
            : EncryptedKeyAes.fromJson(json['keyAes']);

    return tx;
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }

  static Transaction fromMap(Map<String, dynamic> map) {
    return Transaction.fromJson(map);
  }

  @override
  String toString() {
    return jsonEncode(this);
  }
}
