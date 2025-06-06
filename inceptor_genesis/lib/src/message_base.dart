import 'dart:convert';

import 'package:inceptor_genesis/inceptor_genesis.dart';
import 'package:inceptor_genesis/src/object_id.dart';
import 'package:json_annotation/json_annotation.dart';

abstract class MessageBase {
  String id = "${ObjectId()}";
  String? nodeId;
  String? dataType;
  String? messageSigned;
  bool? isServer;
  int createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;

  //this dont use to sign or verify
  int? trackingCounter = 0;

  void sign(String priveateKeyBase64);

  String buidData2Sign();

  bool verify({String?publicKeyBase64});
  Map<String, dynamic> toJson() ;

}
