import 'dart:convert';
import 'package:inceptor_genesis/inceptor_genesis.dart';
import 'package:inceptor_genesis/src/ientity.dart';
import 'package:inceptor_genesis/src/message_base.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class RequestResponseData {
  String? type;
  String? jsonData;
  static RequestResponseData fromJson(Map<String, dynamic> json) {
    RequestResponseData msg = RequestResponseData();
    msg.type = json["type"];
    msg.jsonData = json["jsonData"];
    return msg;
  }

  @override
  Map<String, dynamic> toJson() {
    return {"type": type, "jsonData": jsonData};
  }

  @override
  String toString() {
    return jsonEncode(this);
  }
}

@JsonSerializable()
class RequestResponse implements MessageBase, IEntity {
  final StringCipher _cipher = StringCipher.instance;
  @override
  String? nodeId;

  @override
  String id = "${ObjectId()}";

  @override
  bool? isServer;
  @override
  String? dataType = "request_response";
  @override
  String? messageSigned;
  @override
  int createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;
  ///this dont use to sign or verify, this use to count how many time msg re-broadcast
  @override
  int? trackingCounter = 0;

  RequestResponseData? data;
  // int indexNo = 0;
  // String? previousHash;
  // String? hash;
  // int nonce = 0;
  // int difficulty = 2;
  // String? merkleRoot;
  //  double? gasLimit;
  //  double? gasUse;

  RequestResponse() {}

  // void buildBlock() {
  //   hash = _cipher.generateSha256("$id $previousHash $merkleRoot $nonce $createdAt");
  // }

  @override
  String buidData2Sign() {
    var dataRaw = "$createdAt $nodeId $id $isServer $dataType $data";
    return dataRaw;
  }

  @override
  void sign(String priveateKeyBase64) {
    messageSigned = _cipher.sign(buidData2Sign(), priveateKeyBase64);
  }

  @override
  bool verify({String? publicKeyBase64}) {
    publicKeyBase64 =
        (publicKeyBase64 == null || publicKeyBase64.isEmpty)
            ? nodeId!
            : publicKeyBase64;
    return _cipher.verify(buidData2Sign(), messageSigned!, publicKeyBase64);
  }

  static RequestResponse fromJson(Map<String, dynamic> json) {
    RequestResponse msg = RequestResponse();
    msg.nodeId = json["nodeId"];
    msg.id = json["id"];
    msg.isServer = json["isServer"];
    msg.dataType = json["dataType"];
    msg.data = RequestResponseData.fromJson(json["data"]);
    msg.messageSigned = json["messageSigned"];
    msg.trackingCounter = json["trackingCounter"];
    msg.createdAt = json["createdAt"];

    return msg;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "nodeId": nodeId,
      "id": id,
      "isServer": isServer,
      "dataType": dataType,
      "data": data,
      "messageSigned": messageSigned,
      "trackingCounter": trackingCounter,
      "createdAt": createdAt,
    };
  }

  @override
  Map<String, dynamic> toMap() {
    return toJson();
  }

  static RequestResponse fromMap(Map<String, dynamic> map) {
    return RequestResponse.fromJson(map);
  }

  @override
  String toString() {
    return jsonEncode(this);
  }
}