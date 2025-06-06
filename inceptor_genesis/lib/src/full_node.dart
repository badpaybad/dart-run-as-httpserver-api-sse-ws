import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart';
import 'package:inceptor_genesis/src/block.dart';
import 'package:inceptor_genesis/src/block_dto.dart';
import 'package:inceptor_genesis/src/key_pair.dart';
import 'package:inceptor_genesis/src/message.dart';
import 'package:inceptor_genesis/src/message_base.dart';
import 'package:inceptor_genesis/src/message_chat.dart';
import 'package:inceptor_genesis/src/request_response.dart';
import 'package:inceptor_genesis/src/string_cipher.dart';
import 'package:inceptor_genesis/src/websocket_node.dart';

class FullNode {
  KeyPair<String, String>? nodeAddress;

  final StringCipher _cipher = StringCipher.instance;

  WebsocketNode? websocketNode;

  String? selfAddress;

  List<MessageChat> receivedChats = [];
  List<MessageChat> sentChats = [];
  List<MessageChat> selfChats = [];

  Map<String, String> _trackingMessages = {};
  int _trackingCounterMax = 127;

  List<Block> blockchain = [Block.getGenesisBlock()];

  FullNode(
    String ipPortSelf,
    List<String> ipPortNodes, {
    this.selfAddress = "",
  }) {
    init(ipPortSelf, ipPortNodes, selfaddress: this.selfAddress);
  }

  void connectTo(String ipport) {
    websocketNode?.connectToNode(ipport);
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

    websocketNode ??= WebsocketNode(
      nodeAddresses: ipPortNodes,
      selfIpPort: ipPortSelf,
    );

    websocketNode?.start((srcSocket, jsondata, isserver) async {
      var msgBase = jsonDecode(jsondata);

      var msgBase_id = "${msgBase["id"]}";
      var msgBase_type = "${msgBase["dataType"]}";

      if (_trackingMessages.containsKey(msgBase_id)) {
        return;
      }

      _trackingMessages[msgBase_id] = jsondata;

      if (msgBase_type == "chat") {
        var cmsg = MessageChat.fromJson(msgBase);
        if (cmsg.verify()) await _chatHandle(cmsg);
      }
      if (msgBase_type == "request_response") {
        var rqrsMsg = RequestResponse.fromJson(msgBase);
        if (rqrsMsg.verify()) await _handleRequest(srcSocket, rqrsMsg);
      }
    });

    Timer scheduer = Timer.periodic(Duration(seconds: 60), (t) async {
      try {
        //asking chain from other request_response.data.type="request_chains"
        RequestResponseData data = RequestResponseData();
        data.type = "request_chains";
        await sendRequest(data);
      } catch (e) {}
    });
  }

  Future<void> sendRequest(RequestResponseData data) async {
    RequestResponse msg = RequestResponse();

    msg.nodeId = nodeAddress!.val;
    msg.data = data;

    msg.sign(nodeAddress!.key!);

    websocketNode?.broadcast(jsonEncode(msg));
  }

  //todo: có thể  map 1-1 request-response bằng việc đăng ký Map<Function,Function> để  đưa sang quản lý ở class khác thay cho if else
  Future<void> _handleRequest(
    WebSocket srcSocket,
    RequestResponse request,
  ) async {
    if (request.data?.type == "request_chains") {
      // var chainToSend =
      //     blockchain.map((i) {
      //       BlockDto dto = BlockDto();
      //       dto.hash = i.hash;
      //       dto.previousHash = i.previousHash;
      //       dto.indexNo = i.indexNo;
      //       return dto;
      //     }).toList();
      RequestResponseData data = RequestResponseData();
      data.type = "response_chains";
      data.jsonData = jsonEncode(blockchain);
      await _sendResponse(srcSocket, data);
    } else if (request.data?.type == "response_chains") {
      List<Block> receivedChains =
          ((jsonDecode(request.data!.jsonData!) as List<dynamic>) ?? [])
              .map((txJson) => Block.fromJson(txJson))
              .toList();

      //todo: consensus here for  List<Block> blockchain
      /*✅ 1. Validate the received chain

          Before doing anything, check:

              Structure: Is it a properly formatted chain?

              Hashes: Do blocks link correctly via previousHash?

              Transactions: Are transactions valid (no double-spend, valid signatures, etc.)?

              Genesis Block: Does the received chain start with the same genesis block?

          If invalid → reject it immediately.
          2. Compare Chain Length (or Score)

          Consensus protocols often compare chains using:

              Length (e.g., longest valid chain wins — used in Bitcoin),

              Total difficulty (e.g., sum of work or weight — used in Ethereum 1.0),

              Stake weight (in Proof of Stake systems),

              Voting / finality logic (in PBFT, Tendermint, etc.). 
      */
    } else if (request.data?.type == "request_infos") {
      RequestResponseData data = RequestResponseData();
      data.type = "response_infos";
      data.jsonData = jsonEncode({
        "address": nodeAddress?.val,
        "ip": websocketNode?.selfIpPort,
      });
      await _sendResponse(srcSocket, data);
    } else if (request.data?.type == "response_infos") {
      print("${request.data?.type?.toUpperCase()}:${request.data?.jsonData}");
    } else if (request.data?.type == "request_new_transaction") {
      //todo: received transaction
      //init Block
      // do mine
      // broadcast Block type=request_new_mined_block
    } else if (request.data?.type == "request_new_mined_block") {
      // todo: add received new_mined_block add it into chain
    } else {
      // RequestResponseData data = RequestResponseData();
      // await _sendResponse(srcSocket, data);
    }
  }

  Future<void> _sendResponse(
    WebSocket srcSocket,
    RequestResponseData data,
  ) async {
    RequestResponse msg = RequestResponse();

    msg.nodeId = nodeAddress!.val;
    msg.data = data;

    msg.sign(nodeAddress!.key!);
    websocketNode?.sendData(srcSocket, jsonEncode(msg));
  }

  Future<void> _chatHandle(MessageChat msg) async {
    if (msg != null && msg.verify()) {
      if (msg.toAddress != null &&
          selfAddress != null &&
          msg.fromAddress == selfAddress &&
          msg.toAddress == selfAddress) {
        selfChats.add(msg);
      } else if (msg.toAddress != null &&
          selfAddress != null &&
          msg.fromAddress != selfAddress &&
          msg.toAddress == selfAddress) {
        receivedChats.add(msg);

        print("${websocketNode?.selfIpPort} <----------< $msg");
      } else {
        //if msg not belong to selfAddress
        msg.trackingCounter ??= 0;
        msg.trackingCounter = msg.trackingCounter! + 1;
        if (msg.trackingCounter! >= _trackingCounterMax) {
          //msg rich end of life
        } else {
          websocketNode?.broadcast(jsonEncode(msg));
        }
      }
    } else {
      print("msg incomming not verified: $msg");
    }
  }

  void sendChatMessage(
    String toAddress,
    MessageChatData msgData, {
    String? fromAddress,
  }) {
    if (fromAddress == null || fromAddress.isEmpty) fromAddress = selfAddress;

    if (fromAddress == null || fromAddress == "") {
      throw Exception("fromAddress dont asign");
    }
    if (toAddress == null || toAddress == "") {
      throw Exception("toAddress dont asign");
    }

    MessageChat msg = MessageChat();
    msg.fromAddress = fromAddress;
    msg.nodeId = nodeAddress!.val;
    msg.data = msgData;
    msg.toAddress = toAddress;

    msg.sign(nodeAddress!.key!);

    sentChats.add(msg);
    websocketNode?.broadcast(jsonEncode(msg));
  }
}
