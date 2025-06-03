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
