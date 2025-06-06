import 'dart:convert';

import 'package:inceptor_genesis/inceptor_genesis.dart';
import 'package:inceptor_genesis/src/encrypted_key_aes.dart';
import 'package:inceptor_genesis/src/full_node.dart';

import 'dart:async';

import 'package:inceptor_genesis/src/request_response.dart';
import 'package:inceptor_genesis/src/transaction.dart';

class LeecherTest {
  Future<void> StartLoop() async {
    var ipnode0 = "0.0.0.0:21213";
    List<String> ipfullnode = ["airobotics.vn:21213", ipnode0];
    ipfullnode = [ipnode0];

    var ipnode1 = "0.0.0.0:9991";
    var ipnode2 = "0.0.0.0:9992";

    var node1 = FullNode(ipnode1, ipfullnode);

    var node2 = FullNode(ipnode2, ipfullnode);

    node1.sendChatMessage(
      node2.selfAddress!,
      MessageChatData(jsonData: "Node1 PING hello at ${DateTime.now()}"),
    );
    node2.sendChatMessage(
      node1.selfAddress!,
      MessageChatData(jsonData: "Node2 PONG hello at ${DateTime.now()}"),
    );

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

      RequestResponseData data = RequestResponseData();
      data.type = "request_infos";

      node1.sendRequest(data);

      await Future.delayed(Duration(seconds: 10));
    }
  }
}

class FullNoteTest {
  Future<void> StartLoop() async {
    var ipnode0 = "0.0.0.0:21213";

    //await Block.createGenesisBlock();

    var blockgenesis = Block.getGenesisBlock();
    Block blocktestmine = Block();

    await blocktestmine.mine(blockgenesis.indexNo, blockgenesis.hash!);

    print("blocktestmine $blocktestmine");

    var fullnode = FullNode(ipnode0, []);

    final StringCipher stringCipher = StringCipher.instance;

    // ma hoa keyAes = publickey
    var encrypted = stringCipher.keyAesEncrypt(
      "keyAes your password",
      fullnode.nodeAddress!.val!,
    );
    // ma hoa content = keyAes
    var encrypted123 = encrypted.encryptData(
      utf8.encode("123"),
      "keyAes your password",
    );

    print("$encrypted123 -> encrypted123");
    // giai ma lay keyAes = privatekey
    var keyAes = stringCipher.keyAesDecrypt(
      encrypted,
      fullnode.nodeAddress!.key!,
    );
    // giay ma content = keyAes
    var decrypted123 = encrypted.decryptData(encrypted123, keyAes);

    print(
      "keyAes ----> $keyAes ==== $keyAes decrypted123 == ${utf8.decode(decrypted123)}",
    );

    var testaes = stringCipher.aesEncryptData(
      utf8.encode("can be content file"),
      "123456",
    );
    print(
      "${utf8.decode(stringCipher.aesDecryptData(testaes, "123456"))} <-- aesDecryptData",
    );

    // tao transaction co content (file ) can ma hoa

    Transaction trans1 = Transaction();
    //store keyAes '123456' as encrypted for trans1 with EncryptedKeyAes
    trans1.keyAes = EncryptedKeyAes().setKeyAes(
      fullnode.nodeAddress!.val!,
      "123456",
    );
    // store data encrypted
    trans1.data = base64Encode(
      StringCipher.instance.aesEncryptData(
        utf8.encode("Can read byte from file on disk or url ..."),
        "123456",
      ),
    );

    var key2decryptData = trans1.keyAes?.getKeyAes(fullnode.nodeAddress!.key!);

    var dataDecrypted = StringCipher.instance.aesDecryptData(
      base64Decode(trans1!.data!),
      key2decryptData!,
    );

    print(utf8.decode(dataDecrypted) + " <-----dataDecrypted");

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
