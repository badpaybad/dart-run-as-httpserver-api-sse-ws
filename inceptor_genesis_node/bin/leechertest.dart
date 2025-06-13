import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

import 'package:inceptor_genesis_node/inceptor_genesis_node.dart'
    as inceptor_genesis_node;
import 'package:inceptor_genesis/inceptor_genesis.dart';

Future<void> main(List<String> arguments) async {
  LeecherTest().StartLoop();
}

class LeecherTest {
  Future<void> StartLoop() async {
    var ipnode0 = "0.0.0.0:21213";
    List<String> ipfullnode = ["airobotics.vn:21213", ipnode0];
    ipfullnode = [ipnode0];

    var ipnode1 = "0.0.0.0:9991";
    var ipnode2 = "0.0.0.0:9992";

    var sellerAddress = StringCipher.instance.generate();

    var node_sellerAddress = KeyPair(
      key:"KsaceOlBeTxW+/N3WsHv+P9pxtkpFmemZKW6P4DLNhA=",
      val: "BMSyMlgl8hgilyGNP3/l6CzJuW+rYub+wHooHoxhP8jeCm+K5o8L1Hw76V596QVV43nWwsS9nhhXGb6Fy4hIS3U=",
    );

    var node1 = FullNode(
      "/work",
      ipnode1,
      ipfullnode,
      selfAddress: sellerAddress.val, nodeAddress: node_sellerAddress
    );
    node1.debugName = "node1";

    var buyerAddress = StringCipher.instance.generate();

    var node2 = FullNode(
      "/work",
      ipnode2,
      ipfullnode,
      selfAddress: buyerAddress.val
    );
    node2.debugName = "node2";

    node1.sendChatMessage(
      node2.selfAddress!,
      MessageChatData(jsonData: "Node1 PING hello at ${DateTime.now()}"),
    );
    node2.sendChatMessage(
      node1.selfAddress!,
      MessageChatData(jsonData: "Node2 PONG hello at ${DateTime.now()}"),
    );

    // node1.registerRequestIncommingHandleAndResponseFromOtherHandle(
    //   "requestDataType2Send",
    //   (data) async {
    //     RequestResponseData rr = RequestResponseData();
    //     rr.jsonData = "Node 1 === It should be show in response $data";
    //     return rr;
    //   },
    //   (data) async {
    //     print(data);
    //   },
    // );

    // node2.registerRequestResponseWithIncommingHandle(
    //   "requestDataType2Send",
    //   (data) async {
    //     RequestResponseData rr = RequestResponseData();
    //     rr.jsonData = "Node 2 ==== It should be show in response";
    //     return rr;
    //   },
    //   (data) async {
    //     print(data);
    //   },
    // );

    var trans = Transaction();
    trans.amount = 0;

    node1.sendOfferTransaction(trans, sellerAddress.key!);

    //

    await Future.delayed(Duration(seconds: 1));

    print("${node1.debugName} ${node1.selfAddress}");

    print("${node2.debugName} ${node2.selfAddress}");

    //
    node2.acceptOfferTransaction(trans, buyerAddress.key!);

    while (true) {
      // for (var c in node1.chats) {
      //   print("${node1.wsNode?.selfIpPort}\r\n ${node1.selfAddress}\r\n $c");
      // }
      // for (var c in node2.chats) {
      //   print("${node2.wsNode?.selfIpPort}\r\n ${node2.selfAddress}\r\n $c");
      // }
      // node1.sendChatMessage(
      //   node2.selfAddress!,
      //   "Node1 PING hello at ${DateTime.now()}",
      // );

      // RequestResponseData data = RequestResponseData();
      // data.type = "requestDataType2Send";

      // node1.sendRequest(data);

      print(node1.chatsNode2NodeReceived);

      // print("node 1 ${node1.blockchain.map((e) => e.hash)}");
      // print("node 2 ${node2.blockchain.map((e) => e.hash)}");

      await Future.delayed(Duration(seconds: 5));
    }
  }
}
