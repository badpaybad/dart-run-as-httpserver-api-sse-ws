import 'dart:convert';
import 'package:inceptor_genesis/src/object_id.dart';
import 'package:inceptor_genesis/src/string_cipher.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class Message {
  final StringCipher _cipher = StringCipher();

  String? nodeId;
  String? fromAddress;
  String? toAddress;
  String id = "${ObjectId()}";
  bool? isServer;
  String? dataType;
  String? data;
  String? messageSigned;

  //this dont use to sign or verify
  int? trackingCounter = 0;

  Message() {}

  void sign(String priveateKeyBase64) {
    var dataRaw =
        "$nodeId $fromAddress $toAddress $id $isServer $dataType $data";
    messageSigned = _cipher.sign(dataRaw, priveateKeyBase64);
  }

  bool verify() {
    var dataRaw =
        "$nodeId $fromAddress $toAddress $id $isServer $dataType $data";
    return _cipher.verify(dataRaw, messageSigned!, nodeId!);
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    Message msg = Message();
    msg.nodeId = json["nodeId"];
    msg.fromAddress = json["fromAddress"];
    msg.toAddress = json["toAddress"];
    msg.id = json["id"];
    msg.isServer = json["isServer"];
    msg.dataType = json["dataType"];
    msg.data = json["data"];
    msg.messageSigned = json["messageSigned"];
    msg.trackingCounter = json["trackingCounter"];

    return msg;
  }

  Map<String, dynamic> toJson() {
    return {
      "nodeId": nodeId,
      "fromAddress": fromAddress,
      "toAddress": toAddress,
      "id": id,
      "isServer": isServer,
      "dataType": dataType,
      "data": data,
      "messageSigned": messageSigned,
      "trackingCounter": trackingCounter,
    };
  }

  @override
  String toString() {
    return jsonEncode(this);
  }
}
