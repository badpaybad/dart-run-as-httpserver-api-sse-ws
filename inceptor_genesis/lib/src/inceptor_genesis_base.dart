import 'package:inceptor_genesis/src/full_node.dart';

import 'dart:async';

class LeecherTest {
  Future<void> StartLoop() async {
    List<String> ipfullnode = ["0.0.0.0:9990"];

    var ipnode1 = "0.0.0.0:9991";
    var ipnode2 = "0.0.0.0:9992";

    var node1 = FullNode(ipnode1, ipfullnode);

    var node2 = FullNode(ipnode2, ipfullnode);

    node1.sendChatMessage(
      node2.selfAddress!,
      "Node1 PING hello at ${DateTime.now()}",
    );
    node2.sendChatMessage(
      node1.selfAddress!,
      "Node2 PONG hello at ${DateTime.now()}",
    );

    while (true) {
      // for (var c in node1.chats) {
      //   print("${node1.wsNode?.selfIpPort}\r\n ${node1.selfAddress}\r\n $c");
      // }
      // for (var c in node2.chats) {
      //   print("${node2.wsNode?.selfIpPort}\r\n ${node2.selfAddress}\r\n $c");
      // }
      node1.sendChatMessage(
        node2.selfAddress!,
        "Node1 PING hello at ${DateTime.now()}",
      );
      await Future.delayed(Duration(seconds: 10));
    }
  }
}

class FullNoteTest {
  Future<void> StartLoop() async {
    List<String> ipfullnode = ["0.0.0.0:9990"];

    var ipnode0 = "0.0.0.0:9990";

    var fullnode = FullNode(ipnode0, []);

    while (true) {
      // for (var c in node1.chats) {
      //   print("${node1.wsNode?.selfIpPort}\r\n ${node1.selfAddress}\r\n $c");
      // }
      // for (var c in node2.chats) {
      //   print("${node2.wsNode?.selfIpPort}\r\n ${node2.selfAddress}\r\n $c");
      // }
      await Future.delayed(Duration(seconds: 1));
    }
  }
}
