import 'dart:convert';
import 'package:inceptor_genesis/src/key_pair.dart';
import 'package:inceptor_genesis/src/message.dart';
import 'package:inceptor_genesis/src/string_cipher.dart';
import 'package:inceptor_genesis/src/websocket_node.dart';

class FullNode {
  KeyPair<String, String>? nodeAddress;

  final StringCipher _cipher = StringCipher();

  WebsocketNode? wsNode;

  String? selfAddress;

  List<Message> chats = [];
  List<Message> selfChats = [];

  Map<String, Message> _trackingMessages = {};

  FullNode(
    String ipPortSelf,
    List<String> ipPortNodes, {
    this.selfAddress = "",
  }) {
    init(ipPortSelf, ipPortNodes, selfaddress: this.selfAddress);
  }

  void connectTo(String ipport) {
    wsNode?.connectToNode(ipport);
  }

  void init(String ipPortSelf, List<String> ipPortNodes, {selfaddress = ""}) {
    if (selfaddress == "") {
      var pkselfnode = _cipher.generate();
      selfaddress = pkselfnode.val;
      print("Your privatekey: ${pkselfnode.key}");
      print("Your publickey: ${pkselfnode.val}");
    }
    this.selfAddress = selfaddress;

    nodeAddress ??= _cipher.generate();
    print("Your nodekey: ${nodeAddress?.key}");
    print("Your nodeId: ${nodeAddress?.val}");

    wsNode ??= WebsocketNode(
      nodeAddresses: ipPortNodes,
      selfIpPort: ipPortSelf,
    );

    wsNode?.start((jsondata, isserver) {
      Message msg = Message.fromJson(jsonDecode(jsondata));

      if (_trackingMessages.containsKey(msg.id)) {
        return;
      }

      _trackingMessages[msg.id] = msg;

      if (msg.verify()) {
        if (msg.dataType == "chat") {
          if (msg.toAddress != null &&
              selfAddress != null &&
              msg.fromAddress == selfAddress &&
              msg.toAddress == selfAddress) {
            selfChats.add(msg);
          } else if (msg.toAddress != null &&
              selfAddress != null &&
              msg.fromAddress != selfAddress &&
              msg.toAddress == selfAddress) {
            chats.add(msg);

            print("${wsNode?.selfIpPort} <----------< $msg");
          } else {
            //if msg not belong to selfAddress
            msg.trackingCounter ??= 0;
            msg.trackingCounter = msg.trackingCounter! + 1;

            wsNode?.broadcast(jsonEncode(msg));
          }
        }
      } else {
        print("msg incomming not verified: $msg");
      }
    });
  }

  void sendChatMessage(String toAddress, String msgText) {
    if (selfAddress == null || selfAddress == "") {
      throw Exception("selfAddress dont asign");
    }
    if (toAddress == null || toAddress == "") {
      throw Exception("toAddress dont asign");
    }

    Message msg = Message();
    msg.fromAddress = selfAddress;
    msg.nodeId = nodeAddress!.val;
    msg.data = msgText;
    msg.toAddress = toAddress;
    msg.dataType = "chat";

    msg.sign(nodeAddress!.key!);

    chats.add(msg);
    wsNode?.broadcast(jsonEncode(msg));
  }
}
