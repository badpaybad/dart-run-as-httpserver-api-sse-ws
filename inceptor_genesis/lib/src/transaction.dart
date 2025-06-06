import 'dart:convert';

import 'package:inceptor_genesis/src/encrypted_key_aes.dart';

class Transaction {
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

  factory Transaction.fromJson(Map<String, dynamic> json) {
    double amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    double fee = (json['fee'] as num?)?.toDouble() ?? 0.0;

    Transaction tx = Transaction();
    tx.sender = json['sender'];
    tx.recipient = json['recipient'];
    tx.type = json['type'];
    tx.data = json['data'];
    tx.amount = amount;
    tx.fee = fee;
    tx.timestamp = json['timestamp'];
    tx.signature = json['signature'];
    tx.keyAes = EncryptedKeyAes.fromJson(json['signature']);

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
