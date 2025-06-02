import 'package:inceptor_genesis/inceptor_genesis.dart';
import 'dart:io';
void main() async {
  // final chain = Blockchain();
  final node = P2PNode(4040);

  await node.startServer();

  stdin.listen((input) {
    final message = String.fromCharCodes(input).trim();
    if (message.startsWith('add ')) {
      final data = message.substring(4);
      // chain.addBlock(data);
      node.broadcast('New block added: $data');
    } else if (message.startsWith('connect ')) {
      final parts = message.split(' ');
      final ip = parts[1];
      final port = int.parse(parts[2]);
      node.connectToPeer(ip, port);
    }
  });
}
