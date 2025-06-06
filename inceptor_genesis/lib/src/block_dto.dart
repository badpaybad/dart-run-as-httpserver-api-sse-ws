import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class BlockDto {
  int indexNo = 0;
  String? previousHash;
  String? hash;

  static BlockDto fromJson(Map<String, dynamic> json) {
    BlockDto msg = BlockDto();

    msg.indexNo = json["indexNo"];
    msg.previousHash = json["previousHash"];
    msg.hash = json["hash"];

    return msg;
  }

  @override
  Map<String, dynamic> toJson() {
    return {"indexNo": indexNo, "previousHash": previousHash, "hash": hash};
  }


  Map<String, dynamic> toMap() {
    return toJson();
  }

  static BlockDto fromMap(Map<String, dynamic> map) {
    return BlockDto.fromJson(map);
  }

  @override
  String toString() {
    return jsonEncode(this);
  }
}
