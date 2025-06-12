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
  FullNoteTest().StartLoop();
}

class FullNoteTest {
  Future<void> StartLoop() async {
    var ipnode0 = "0.0.0.0:21213";
    var ipnode3 = "0.0.0.0:9993";

    // await Block.createGenesisBlock();

    var blockgenesis = Block.getGenesisBlock();
    Block blocktestmine = Block();

    // await blocktestmine.mine(blockgenesis.indexNo, blockgenesis.hash!);

    // print("blocktestmine $blocktestmine");

    var fullnode = FullNode("/work", ipnode0, []);
    fullnode.debugName = "Fullnode ";

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

    trans1.sign(fullnode.nodeAddress!.key!);

    print(
      utf8.decode(dataDecrypted) +
          " <-----dataDecrypted ${trans1.verify(fullnode.nodeAddress!.val!)}",
    );
    fullnode.registerRequestIncommingHandleAndResponseFromOtherHandle(
      "requestDataType2Send",
      (data) async {
        RequestResponseData rr = RequestResponseData();
        rr.jsonData = "fullnode === It should be show in response $data";
        return rr;
      },
      (data) async {
        print(data);
      },
    );

    var sellerAddress3 = StringCipher.instance.generate();

    var sellerAddress = KeyPair(
      key: "KsaceOlBeTxW+/N3WsHv+P9pxtkpFmemZKW6P4DLNhA=",
      val:
          "BMSyMlgl8hgilyGNP3/l6CzJuW+rYub+wHooHoxhP8jeCm+K5o8L1Hw76V596QVV43nWwsS9nhhXGb6Fy4hIS3U=",
    );

    var node3 = FullNode("/work", ipnode3, [
      ipnode0,
    ], selfAddress: sellerAddress3.val);
    node3.debugName = "node3";

    while (true) {
      // for (var c in node1.chats) {
      //   print("${node1.wsNode?.selfIpPort}\r\n ${node1.selfAddress}\r\n $c");
      // }
      // for (var c in node2.chats) {
      //   print("${node2.wsNode?.selfIpPort}\r\n ${node2.selfAddress}\r\n $c");
      // }

      // RequestResponseData request_infos = RequestResponseData();
      // request_infos.type = "request_infos";

      // fullnode.sendRequest(request_infos);
      var msgfrom3 = MessageChatData();
      msgfrom3.jsonData = "helllo from ${node3.debugName}";

      node3.sendChatMessageToNode(sellerAddress.val!, msgfrom3);

      // print("fullnode ${fullnode.blockchain.map((e) => e.id)}");

      await Future.delayed(Duration(seconds: 5));
    }
  }
}
