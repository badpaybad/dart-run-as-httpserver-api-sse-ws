import 'dart:convert';
import 'dart:io';
import 'package:inceptor_genesis/inceptor_genesis.dart';
import 'package:inceptor_genesis/src/message_base.dart';
import 'package:inceptor_genesis/src/message_chat.dart';
import 'package:inceptor_genesis/src/object_id.dart';
import 'package:inceptor_genesis/src/string_cipher.dart';
import 'package:json_annotation/json_annotation.dart';

class ChatDomain {
  FullNode fullNode;
  String? owner;

  List<ChatGroup> groups = [];

  ChatDomain(this.fullNode, this.owner) {}

  void creatGroup(String? name) {
    var g = ChatGroup(fullNode, owner);
    g.name = name;
    groups.add(g);
  }
}

class ChatGroup {
  ObjectId id = ObjectId();
  bool? isPrivate;
  String? name;

  String? owner;

  Map<String, String> members = {};

  List<MessageChat> messages = [];

  Map<String, String> invitedMembers = {};

  FullNode fullNode;

  ChatGroup(this.fullNode, this.owner) {}

  void inviteFriends(List<String> friends) {
    for (var m in friends) {
      invitedMembers[m] = m;
      // fullNode.sendChatMessage(toAddress, msgData)
    }
  }
}
