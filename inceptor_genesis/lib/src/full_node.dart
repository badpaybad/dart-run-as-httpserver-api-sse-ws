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
import 'package:inceptor_genesis/src/transaction.dart';
import 'package:inceptor_genesis/src/websocket_node.dart';

/// Fullnode run all services for blockchain, should be declare one ( singleton )
class FullNode {
  String? debugName;

  KeyPair<String, String>? nodeAddress;

  final StringCipher _cipher = StringCipher.instance;

  WebsocketNode? websocketNode;

  /// when user open app they must give public key to start node
  String? selfAddress;

  List<MessageChat> chatsReceived = [];
  List<MessageChat> chatsSent = [];
  List<MessageChat> chatsSelf = [];

  List<MessageChat> chatsNode2NodeReceived = [];
  List<MessageChat> chatsNode2NodeSelf = [];
  List<MessageChat> chatsNode2NodeSent = [];

  Block _genesis = Block.getGenesisBlock();

  Map<String, String> _trackingMessages = {};

  int get _trackingCounterMax =>
      blockchain.length +
      (websocketNode == null
          ? 0
          : (websocketNode!.socketsConnect2OtherNodes.length +
              websocketNode!.clientsConnectedFromOthers.length));

  List<Block> blockchain = [Block.getGenesisBlock()];

  ///-1:doing, 0: none, 1:done
  int _consensusState = 0;

  Map<String, DateTime> addressOnlineAt = {};

  List<Transaction> _transOffer = [];
  List<Transaction> _transAccepted = [];

  Map<String, Future<RequestResponseData?> Function(RequestResponseData)>
  _mapRequest_DataType_Handler = {};
  Map<String, Future<void> Function(RequestResponseData)>
  _mapRespone_DataType_Handler = {};

  String workingDir;

  FullNode(
    this.workingDir,
    String ipPortSelf,
    List<String> ipPortNodes, {
    this.selfAddress = "", this.nodeAddress
  }) {
    if (selfAddress == "") {
      var pkselfnode = _cipher.generate();
      selfAddress = pkselfnode.val;
      print("$debugName  privatekey: ${pkselfnode.key}");
      print("$debugName  publickey: ${pkselfnode.val}");
    }
    this.selfAddress = selfAddress;

    nodeAddress ??= _cipher.generate();
    print("$debugName  nodekey: ${nodeAddress?.key}");
    print("$debugName  nodeId: ${nodeAddress?.val}");

    init(ipPortSelf, ipPortNodes);

    if (this.isChainValid(blockchain) == false) {
      throw Exception(
        "Your local blockchain not valid or genesis block not valid, remove all and download from truth source",
      );
    }

    registerRequestIncommingHandleAndResponseFromOtherHandle(
      "request_infos",
      (data) async {
        RequestResponseData datar = RequestResponseData();
        datar.jsonData = jsonEncode({
          "address": nodeAddress?.val,
          "ip": websocketNode?.selfIpPort,
        });

        return datar;
      },
      (data) async {
        // print("$debugName ${data?.type?.toUpperCase()}:${data?.jsonData}");
        var response_infos = jsonDecode(data.jsonData!);
        addressOnlineAt[response_infos["address"]] = DateTime.now();
        print("addressOnlineAt------------\r\n");
        print(addressOnlineAt);
      },
    );
  }

  void init(String ipPortSelf, List<String> ipPortNodes) {
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
        if (cmsg.verify()) await _chatHandle(cmsg, jsondata);
      }
      if (msgBase_type == "chat_node_2_node") {
        var cmsg = MessageChat.fromJson(msgBase);
        if (cmsg.verify()) await _chatHandleNode2Node(cmsg, jsondata);
      }
      if (msgBase_type == "request_response") {
        var rqrsMsg = RequestResponse.fromJson(msgBase);
        if (rqrsMsg.verify())
          await _handleRequestResponse(srcSocket, rqrsMsg, jsondata);
      }
    });

    _requestOtherNodes2ConsensusChain();
  }

  /// UI action want to manual add ip:port to connect
  void connectTo(String ipport, bool isIpPortLan) {
    websocketNode?.connectToNode(ipport, isIpPortLan);
  }

  bool isChainValid(List<Block> chainOfBlocks) {
    if (_genesis.isValidHash() == false ||
        chainOfBlocks
                .where(
                  (t) => t.toString() == _genesis.toString() && t.isValidHash(),
                )
                .length !=
            1) {
      //may be should check if 1st block in chain should be genesis;
      return false;
    }

    for (int i = 1; i < chainOfBlocks.length; i++) {
      final current = chainOfBlocks[i];
      final previous = chainOfBlocks[i - 1];

      if (current.hash != current.computeHash()) return false;
      if (current.previousHash != previous.hash) return false;
    }
    return true;
  }

  bool consenusLongestChain(List<Block> receivedChain) {
    _consensusState = -1;
    if (isChainValid(receivedChain) == false) {
      print(
        "consenusLongestChain: receivedChain wrong, your local chain is correct",
      );
      return false;
    }

    if (receivedChain.length > blockchain.length) {
      blockchain = receivedChain;

      print(
        "consenusLongestChain: receivedChain correct and longest, your local chain replace by receivedChain",
      );
    }
    // print("consenusLongestChain: receivedChain == local blockchain");
    _consensusState = 1;
    return true;
  }

  Future<void> _requestOtherNodes2ConsensusChain() async {
    try {
      //asking chain from other request_response.data.type="request_chains"
      RequestResponseData data = RequestResponseData();
      data.type = "request_chains";
      await sendRequest(data);
      // print("scheduer.request_chains======================> $data");
    } catch (e) {
      print("ERROR: scheduler: request_chains: $e");
    }

    await Future.delayed(Duration(seconds: 60));

    await _requestOtherNodes2ConsensusChain();
  }

  /// UI action want to create trans offer
  Future<void> sendOfferTransaction(
    Transaction trans,
    String priveateKeyBase64,
  ) async {
    trans.type = "offer";
    trans.recipient = null;
    trans.sender = selfAddress;
    trans.sign(priveateKeyBase64);

    if (trans.verify(trans.sender!) == false) {
      throw Exception("error sendOfferTransaction");
    }

    RequestResponseData request = RequestResponseData();
    request.type = "new_trans_offer";
    request.jsonData = jsonEncode(trans);
    await sendRequest(request);
  }

  /// UI action want to create trans offer
  Future<void> acceptOfferTransaction(
    Transaction trans,
    String priveateKeyBase64,
  ) async {
    if (trans.verify(trans.sender!) == false) {
      throw Exception(
        "Not valid, sender should be public key, transaction have to sign use private key",
      );
    }

    var buytrans = trans.clone();
    buytrans.fromId = trans.id;
    buytrans.type = "buy";
    buytrans.sender = selfAddress;
    buytrans.recipient = buytrans.sender;
    buytrans.sign(priveateKeyBase64);

    if (buytrans.verify(buytrans.sender!) == false) {
      throw Exception("error acceptOfferTransaction");
    }

    RequestResponseData request = RequestResponseData();
    request.type = "new_trans_buy";
    request.jsonData = jsonEncode(buytrans);

    _transAccepted.add(buytrans);

    await sendRequest(request);
  }

  /// after received trans from other can do mine -> got block -> broadcast
  Future<void> sendMinedBlock(Block block) async {
    RequestResponseData data = RequestResponseData();
    data.type = "new_minedblock";
    data.jsonData = jsonEncode(block);

    await sendRequest(data);
  }

  Block get latestBlock => blockchain[blockchain.length - 1];

  double balanceOfAddress(String address) {
    //check double spend here
    List<Transaction> senders = [];
    List<Transaction> receivers = [];

    double received = 0;
    double sent = 0;

    for (var b in blockchain) {
      for (var t in b.trans!) {
        if (t.sender == address) {
          senders.add(t);
          sent += t.amount ?? 0;
        }
        if (t.recipient == address) {
          receivers.add(t);
          received += t.amount ?? 0;
        }
      }
    }

    double balance = received - sent;

    return balance;
  }

  bool isBlanceValid(Transaction trans) {
    //check double spend here
    List<Transaction> senders = [];
    List<Transaction> receivers = [];

    double received = 0;
    double sent = 0;

    for (var b in blockchain) {
      for (var t in b.trans!) {
        if (t.sender == trans.sender) {
          senders.add(t);
          sent += t.amount ?? 0;
        }
        if (t.recipient == trans.sender) {
          receivers.add(t);
          received += t.amount ?? 0;
        }
      }
    }

    double balance = received - sent;

    return balance >= (trans.amount ?? 0);
  }

  Future<void> reBroadCast(MessageBase msg, String jsonDataRaw) async {
    msg.trackingCounter ??= 0;
    msg.trackingCounter = msg.trackingCounter! + 1;
    if (msg.trackingCounter! >= _trackingCounterMax) {
      print("msg was end of life: $msg");
      //msg rich end of life
    } else {
      //re-broadcast
      websocketNode?.broadcast(jsonDataRaw);
    }
  }
}

extension FullNodeRequestResponse_TransactionAndMine on FullNode {
  Future<void> sendRequest(RequestResponseData data) async {
    RequestResponse msg = RequestResponse();

    msg.nodeId = nodeAddress!.val;
    msg.data = data;

    msg.sign(nodeAddress!.key!);

    var msgJsonData = jsonEncode(msg);

    _trackingMessages[msg.id] = msgJsonData;

    websocketNode?.broadcast(msgJsonData);
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

  /// reqresIncomming.data.type='requestype'  => reqresReturn.data.type='response:' +reqresIncomming.data.type;
  Future<void> registerRequestIncommingHandleAndResponseFromOtherHandle(
    String requestDataType2Send,
    Future<RequestResponseData?> Function(RequestResponseData)
    handlerRequestIncomming,
    Future<void> Function(RequestResponseData) handlerResponseIncomming,
  ) async {
    _mapRequest_DataType_Handler[requestDataType2Send] = (drr) async {
      var r = await handlerRequestIncomming(drr);
      if (r != null) r!.type = "response:" + requestDataType2Send;
      return r;
    };
    handlerRequestIncomming;
    _mapRespone_DataType_Handler["response:" + requestDataType2Send] =
        handlerResponseIncomming;

    // RequestResponseData request = RequestResponseData();
    // request.jsonData = requestData2Send;
    // request.type = requestDataType2Send;

    // _sendRequest(request);
  }

  //todo: có thể  map 1-1 request-response bằng việc đăng ký Map<Function,Function> để  đưa sang quản lý ở class khác thay cho if else
  Future<void> _handleRequestResponse(
    WebSocket srcSocket,
    RequestResponse reqres,
    String jsonDataRaw,
  ) async {
    if (reqres.data == null || reqres.data?.type == null) {
      return;
    }
    if (_mapRequest_DataType_Handler.containsKey(reqres.data!.type!)) {
      var handler = _mapRequest_DataType_Handler[reqres.data!.type!];

      var result = await handler!(reqres.data!);

      if (result != null) {
        result.type = "response:" + reqres.data!.type!;
        _sendResponse(srcSocket, result);
      }

      return;
    }

    if (_mapRespone_DataType_Handler.containsKey(reqres.data!.type!)) {
      // print("request handle -----2 ${reqres.data}");

      var handler = _mapRespone_DataType_Handler[reqres.data!.type!];
      await handler!(reqres.data!);

      return;
    }

    if (reqres.data?.type == "new_trans_offer") {
      //some one want to buy just forward
      //store local to UI deciced buy or not
      reBroadCast(reqres, jsonDataRaw);
      var newtrans = Transaction.fromJson(jsonDecode(reqres.data!.jsonData!));
      _transOffer.add(newtrans);
    } else if (reqres.data?.type == "new_trans_buy") {
      while (_consensusState == -1) {
        //wait for checking blockchain
        await Future.delayed(Duration(seconds: 1));
      }

      var newtrans = Transaction.fromJson(jsonDecode(reqres.data!.jsonData!));

      if (newtrans.verify(newtrans.sender!)) {
        //todo: check balance
        if (isBlanceValid(newtrans)) {
          //todo: do mine for trans broadcast new_minedblock
          Block newblock = Block();
          newblock.trans = [newtrans];
          newblock.reward = 1;

          var lstblk = latestBlock;

          await newblock.mine(lstblk.indexNo, lstblk.hash!);

          //todo: consenusLongestChain have to do it

          await sendMinedBlock(newblock);
          //todo: rebroad cast
          await reBroadCast(reqres, jsonDataRaw);
        }
      }
    } else if (reqres.data?.type == "new_minedblock") {
      //todo: consensus then add to local blockchain
      //todo: rebroad cast
      if (isChainValid(blockchain)) {
        var lstblk = latestBlock;

        var newminedblock = Block.fromJson(jsonDecode(reqres.data!.jsonData!));

        if (lstblk.indexNo == newminedblock.indexNo - 1 &&
            lstblk.hash == newminedblock.previousHash) {
          blockchain.add(newminedblock);

          //todo: consenusLongestChain have to do it

          reBroadCast(reqres, jsonDataRaw);
        }
      }
    } else if (reqres.data?.type == "request_chains") {
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

      // print("scheduer.response_chains======================> $data");
    } else if (reqres.data?.type == "response_chains") {
      List<Block> receivedChains =
          ((jsonDecode(reqres.data!.jsonData!) as List<dynamic>) ?? [])
              .map((txJson) => Block.fromJson(txJson))
              .toList();
      consenusLongestChain(receivedChains);
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
    } else {
      // RequestResponseData data = RequestResponseData();
      // await _sendResponse(srcSocket, data);
    }
  }
}

extension FullNodeSellerBuyerChat on FullNode {
  Future<void> _chatHandle(MessageChat msg, String jsonDataRaw) async {
    if (msg != null && msg.verify()) {
      if (msg.toAddress != null &&
          selfAddress != null &&
          msg.fromAddress == selfAddress &&
          msg.toAddress == selfAddress) {
        chatsSelf.add(msg);
      } else if (msg.toAddress != null &&
          selfAddress != null &&
          msg.fromAddress != selfAddress &&
          msg.toAddress == selfAddress) {
        chatsReceived.add(msg);

        // print("${websocketNode?.selfIpPort} <----------< $msg");

        /*
        else if (request.data?.type == "request_ai_compute") {
          //todo: if dont want computing re-broadcast  websocketNode?.broadcast(jsonEncode(msg));
          //todo: do grid computing

          // reply to msg.fromAddress sendChatMessage(msg.fromAddress,..data:{type:response_ai_compute}.., selfAddress,)
        } 
        else if (request.data?.type == "response_ai_compute" ) {
          //todo: each part{id} will compare result (cause sent to atless 2 node)
          //todo: combin grind computing all parts -> finally value computed 
          //todo: if dont want computing re-broadcast  websocketNode?.broadcast(jsonEncode(msg));
        }  
        */
      } else {
        //if msg not belong to selfAddress
        // msg.trackingCounter ??= 0;
        // msg.trackingCounter = msg.trackingCounter! + 1;
        // if (msg.trackingCounter! >= _trackingCounterMax) {
        //   print("msg was end of life: $msg");
        //   //msg rich end of life
        // } else {
        //   //re-broadcast
        //   websocketNode?.broadcast(jsonDataRaw);
        // }
        reBroadCast(msg, jsonDataRaw);
      }
    } else {
      print("msg incomming not verified: $msg");
    }
  }

  /// UI action to send chat msg to address ( public key of buyer or seller )
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
    msg.dataType = "chat";
    msg.fromAddress = fromAddress;
    msg.nodeId = nodeAddress!.val;
    msg.data = msgData;
    msg.toAddress = toAddress;
    /*
    else if (request.data?.type == "request_ai_compute") {

      //todo: split into parts broadcast each part{id} ( atless 3 node working ) 
      //todo: do grid computing
    } 
   
    */
    msg.sign(nodeAddress!.key!);

    var msgJsonData = jsonEncode(msg);

    _trackingMessages[msg.id] = msgJsonData;

    chatsSent.add(msg);
    websocketNode?.broadcast(msgJsonData);
  }
}

extension FullNodeChatNode2Node on FullNode {
  Future<void> _chatHandleNode2Node(MessageChat msg, String jsonDataRaw) async {
    if (msg != null && msg.verify()) {
      if (msg.toAddress != null &&
          selfAddress != null &&
          msg.fromAddress == nodeAddress!.val! &&
          msg.toAddress == nodeAddress!.val!) {
        //
        chatsNode2NodeSelf.add(msg);
      } else if (msg.toAddress != null &&
          selfAddress != null &&
          msg.fromAddress != nodeAddress!.val! &&
          msg.toAddress == nodeAddress!.val!) {
        //
        chatsNode2NodeReceived.add(msg);

        // print("${websocketNode?.selfIpPort} <----------< $msg");

        /*
        else if (request.data?.type == "request_ai_compute") {
          //todo: if dont want computing re-broadcast  websocketNode?.broadcast(jsonEncode(msg));
          //todo: do grid computing

          // reply to msg.fromAddress sendChatMessage(msg.fromAddress,..data:{type:response_ai_compute}.., selfAddress,)
        } 
        else if (request.data?.type == "response_ai_compute" ) {
          //todo: each part{id} will compare result (cause sent to atless 2 node)
          //todo: combin grind computing all parts -> finally value computed 
          //todo: if dont want computing re-broadcast  websocketNode?.broadcast(jsonEncode(msg));
        }  
        */
      } else {
        //if msg not belong to selfAddress
        // msg.trackingCounter ??= 0;
        // msg.trackingCounter = msg.trackingCounter! + 1;
        // if (msg.trackingCounter! >= _trackingCounterMax) {
        //   print("msg was end of life: $msg");
        //   //msg rich end of life
        // } else {
        //   //re-broadcast
        //   websocketNode?.broadcast(jsonDataRaw);
        // }
        reBroadCast(msg, jsonDataRaw);
      }
    } else {
      print("msg incomming not verified: $msg");
    }
  }

  /// UI action to send chat msg to address ( public key of buyer or seller )
  void sendChatMessageToNode(
    String toNodeAddress,
    MessageChatData msgData, {
    String? fromNodeAddress,
  }) {
    if (fromNodeAddress == null || fromNodeAddress.isEmpty)
      fromNodeAddress = nodeAddress!.val!;

    if (fromNodeAddress == null || fromNodeAddress == "") {
      throw Exception("fromAddress dont asign");
    }
    if (toNodeAddress == null || toNodeAddress == "") {
      throw Exception("toAddress dont asign");
    }

    MessageChat msg = MessageChat();
    msg.dataType = "chat_node_2_node";
    msg.fromAddress = fromNodeAddress;
    msg.nodeId = nodeAddress!.val;
    msg.data = msgData;
    msg.toAddress = toNodeAddress;
    /*
    else if (request.data?.type == "request_ai_compute") {

      //todo: split into parts broadcast each part{id} ( atless 3 node working ) 
      //todo: do grid computing
    } 
   
    */
    msg.sign(nodeAddress!.key!);

    var msgJsonData = jsonEncode(msg);

    _trackingMessages[msg.id] = msgJsonData;

    chatsNode2NodeSent.add(msg);
    websocketNode?.broadcast(msgJsonData);
  }
}
