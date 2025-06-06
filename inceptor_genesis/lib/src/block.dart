import 'dart:convert';
import 'dart:io';
import 'package:inceptor_genesis/src/ientity.dart';
import 'package:inceptor_genesis/src/message_base.dart';
import 'package:inceptor_genesis/src/object_id.dart';
import 'package:inceptor_genesis/src/string_cipher.dart';
import 'package:inceptor_genesis/src/transaction.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class Block implements MessageBase, IEntity {
  final StringCipher _cipher = StringCipher.instance;
  @override
  String? nodeId;
  @override
  String id = "${ObjectId()}";
  @override
  bool? isServer;
  @override
  String? dataType = "block";
  @override
  String? messageSigned;
  @override
  int createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;
  //this dont use to sign or verify, this use to count how many time msg re-broadcast
  @override
  int? trackingCounter = 0;

  int indexNo = 0;
  String? previousHash;
  String? hash;
  int nonce = 0;
  int difficulty = 2;
  String? merkleRoot;
  double? gasLimit;
  double? gasUse;
  List<Transaction>? trans;
  double? reward;

  Block genesis() => Block.getGenesisBlock();

  Block() {}

  static Future<Block> createGenesisBlock() async {
    Block genesis = Block();
    //todo: uncomment to do your own genesis block
    genesis.indexNo = 0;
    genesis.previousHash = "0";
    genesis.createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    genesis.trans =
        []; // hoặc tạo một giao dịch khởi tạo, may be settings, config
    genesis.reward = 0.0; // ví dụ reward
    genesis.gasLimit = 10000;
    genesis.gasUse = 0;
    genesis.nonce = 0;

    await genesis.mine(-1, genesis._cipher.generateSha256(genesis.id));
    final file = File('/work/genesis.json');
    file.writeAsStringSync("$genesis");

    print("$genesis");
    return genesis;
  }

  static Block getGenesisBlock() {
    var obj = jsonDecode(
      '{"nodeId":null,"id":"6842622f40254efd06c4b1ab","isServer":null,"dataType":"block","messageSigned":null,"trackingCounter":0,"createdAt":1749180975590,"indexNo":0,"previousHash":"677ec8e01273c73b286d27a37b9cf7f198dcc9e3e0f0757fa83fdca53be9e66e","hash":"a72b860af2b3170216c60dfbc43f2206099a0494f0c0974876b13022723e5baf","nonce":1749180975616,"difficulty":2,"merkleRoot":null,"gasLimit":10000.0,"gasUse":0.0,"trans":[],"reward":0.0}',
    );

    Block genesis = Block.fromJson(obj);

    print("$genesis");
    return genesis;
  }

  String calculateHash() {
    var dataRaw =
        "$nonce $difficulty $createdAt $nodeId $id $isServer $dataType $indexNo $previousHash $gasLimit $gasUse $reward ${jsonEncode(trans ?? [])}";

    return _cipher.generateSha256(dataRaw);
  }

  bool isValidHash() {
    return hash == calculateHash();
  }

  bool isHashMatchDifficulty(String hash) {
    //todo: poc of PoW Proof of Work, need do other
    // if (this.hash!.startsWith("00")) {
    //   break;
    // }
    if (this.difficulty == 2) {
      var idx21 = hash!.indexOf("21");
      var idx02 = hash!.indexOf("02");
      var idx13 = hash!.indexOf("13");
      if (this.hash!.contains("21") &&
          this.hash!.contains("02") &&
          this.hash!.contains("13") &&
          idx21 > idx02 &&
          idx02 > idx13) {
        return true;
      }
    } else {
      if (this.hash!.contains("21") &&
          this.hash!.contains("02") &&
          this.hash!.contains("13")) {
        return true;
      }
    }

    return false;
  }

  Future<Block> mine(int previousIndexNo, String previousHash) async {
    this.previousHash = previousHash;
    this.indexNo = previousIndexNo + 1;
    this.nonce = createdAt;

    while (true) {
      this.hash = this.calculateHash();

      if (isHashMatchDifficulty(this.hash!)) {
        break;
      }

      this.nonce++;
      await Future.delayed(Duration(milliseconds: 10));
    }
    return this;
  }

  @override
  String buidData2Sign() {
    var dataRaw =
        "$createdAt $nodeId $id $isServer $dataType $indexNo $previousHash $hash $nonce $difficulty $gasLimit $gasUse $reward ${jsonEncode(trans ?? [])}";
    return dataRaw;
  }

  @override
  void sign(String priveateKeyBase64) {
    //sign before broadcast Block
    messageSigned = _cipher.sign(buidData2Sign(), priveateKeyBase64);
  }

  @override
  bool verify({String? publicKeyBase64}) {
    publicKeyBase64 =
        (publicKeyBase64 == null || publicKeyBase64.isEmpty)
            ? nodeId!
            : publicKeyBase64;
    return _cipher.verify(buidData2Sign(), messageSigned!, publicKeyBase64);
  }

  static Block fromJson(Map<String, dynamic> json) {
    var txList = json['trans'] as List<dynamic>;
    List<Transaction> transactions =
        txList.map((txJson) => Transaction.fromJson(txJson)).toList();

    double gasLimit = (json['gasLimit'] as num?)?.toDouble() ?? 0.0;
    double gasUse = (json['gasUse'] as num?)?.toDouble() ?? 0.0;
    double reward = (json['reward'] as num?)?.toDouble() ?? 0.0;

    Block msg = Block();
    msg.nodeId = json["nodeId"];
    msg.id = json["id"];
    msg.isServer = json["isServer"];
    msg.dataType = json["dataType"];
    msg.messageSigned = json["messageSigned"];
    msg.trackingCounter = json["trackingCounter"];
    msg.createdAt = json["createdAt"];

    msg.indexNo = json["indexNo"];
    msg.previousHash = json["previousHash"];
    msg.hash = json["hash"];
    msg.nonce = json["nonce"];
    msg.difficulty = json["difficulty"];
    msg.merkleRoot = json["merkleRoot"];
    msg.gasLimit = gasLimit;
    msg.gasUse = gasUse;
    msg.reward = reward;
    msg.trans = transactions;

    return msg;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "nodeId": nodeId,
      "id": id,
      "isServer": isServer,
      "dataType": dataType,
      "messageSigned": messageSigned,
      "trackingCounter": trackingCounter,
      "createdAt": createdAt,

      "indexNo": indexNo,
      "previousHash": previousHash,
      "hash": hash,
      "nonce": nonce,
      "difficulty": difficulty,
      "merkleRoot": merkleRoot,
      "gasLimit": gasLimit,
      "gasUse": gasUse,
      "trans": trans?.map((tx) => tx.toJson()).toList(),
      "reward": reward,
    };
  }

  @override
  Map<String, dynamic> toMap() {
    return toJson();
  }

  static Block fromMap(Map<String, dynamic> map) {
    return Block.fromJson(map);
  }

  @override
  String toString() {
    return jsonEncode(this);
  }
}
