import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:inceptor_genesis_node/inceptor_genesis_node.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

import 'package:inceptor_genesis_node/inceptor_genesis_node.dart'
    as inceptor_genesis_node;
import 'package:inceptor_genesis/inceptor_genesis.dart';

Future<void> main(List<String> arguments) async {
  var ipnode0 = "0.0.0.0:21213";

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
  // FullNoteTest().StartLoop();
  // LeecherTest().StartLoop();

  // StringCipher strCipher = StringCipher();

  // var kp = strCipher.generate();

  // var strtest = "Nguyen Phan Du";

  // var signed = strCipher.sign(strtest, kp.key!);

  // print(signed);
  // var oki = strCipher.verify(strtest, signed, kp.val!);

  // print(oki);
  // start_server();
  // client_connect();

  // while (true) {
  //   await Future.delayed(Duration(seconds: 1));
  // }
}
