import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:inceptor_genesis/src/key_pair.dart';
import 'package:inceptor_genesis/src/string_cipher.dart';

class WebsocketNode {
  final StringCipher _cipher = StringCipher.instance;

  /// ip:port seed node,fullnode
  final List<String> nodeAddresses;

  Map<String, WebSocket> _ipPortLanNodesConnected = {};

  /// ip:port
  final String selfIpPort;

  /// splited from selfIpPort
  final String selfIp;

  /// splited from selfIpPort
  final int selfPort;

  ///seed node ips
  final Map<String, WebSocket> socketsConnect2OtherNodes = {};

  /// other socket connected to this node
  final Set<WebSocket> clientsConnectedFromOthers = {};
  HttpServer? selfServer;

  KeyPair<String, String>? keyDiscoveryTester = KeyPair(
    key: "Bg6okpXWh9oYVGyRlesGz6uG0HqE4Fo5XnKrr/0yZWM=",
    val:
        "BEJW3kZ38Nhq6GtClzxsnpdPWX499s3PlIyFvAcO4SHKRbYhGfVHw1fXPAJ2LdI/dNVqsF1Rox4s3I5GWtQ6E9A=",
  );

  Future<String?> getLocalIpAddress({
    InternetAddressType itype = InternetAddressType.IPv4,
  }) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: itype,
        includeLoopback: false,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error fetching getLocalIpAddress IP: $e');
    }
    return null;
  }

  Future<String?> getPublicIp() async {
    try {
      /*
      https://checkip.amazonaws.com (plain text)
      https://ifconfig.me/ip
      https://icanhazip.com 
      */
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      print('Error fetching getPublicIp IP: $e');
    }
    return null;
  }

  Map<String, Future<void> Function(WebSocket, String, bool)>
  _handlersIncomming = {};

  String? _localLanIp;
  String? _publicIp;

  WebsocketNode({required this.nodeAddresses, required this.selfIpPort})
    : selfIp = selfIpPort.split(':')[0],
      selfPort = int.parse(selfIpPort.split(":")[1]) {
    //

    var ipPortApi =
        "http://$selfIp:$selfPort/nodes/valid/${Uri.encodeComponent(keyDiscoveryTester!.val!)}";

    print("restful api: $ipPortApi");
  }

  Future<void> _discorveryAutoIpPort4NodesSibling() async {
    if (_isShutdown) {
      return;
    }
    try {
      if (_publicIp != null) {
        _publicIp = _normalizeAddress(_publicIp!);
        await _validIpSibling2ConnectNode(_publicIp!);
      }

      if (_localLanIp != null) {
        var ipslan = _ipLanSameSubnet(_localLanIp!);
        // ipslan = ["192.168.4.248"];

        // print("_ipLanSameSubnet: $ipslan");

        for (var ip in ipslan) {
          ip = _normalizeAddress(ip);
          if (_ipPortLanNodesConnected.containsKey(ip)) {
            continue;
          }

          await _validIpSibling2ConnectNode(ip);
          await Future.delayed(Duration(milliseconds: 10));
        }
      }
    } catch (ex) {
      print("ERR:_discorveryAutoIpPort4NodesSibling:$ex");
    } finally {
      await Future.delayed(Duration(seconds: 60));
    }
    await _discorveryAutoIpPort4NodesSibling();
  }

  List<String> _ipLanSameSubnet(String myIp) {
    myIp = _normalizeAddress(myIp);
    final subnet = myIp.substring(
      0,
      myIp.lastIndexOf('.'),
    ); // e.g., "192.168.1"
    // print('Scanning subnet: $subnet.0/24');
    List<String> res = [];
    for (int i = 1; i < 255; i++) {
      res.add('$subnet.$i');
    }
    return res;
  }

  Future<void> _validIpSibling2ConnectNode(String ipSibling) async {
    ipSibling = _normalizeAddress(ipSibling);

    if (_ipPortLanNodesConnected.containsKey(ipSibling) ||
        socketsConnect2OtherNodes.containsKey(ipSibling)) {
      return;
    }

    var ipPort =
        "http://$ipSibling:$selfPort/nodes/valid/${Uri.encodeComponent(keyDiscoveryTester!.val!)}";

    try {
      final response = await http
          .get(Uri.parse('$ipPort'))
          .timeout(Duration(seconds: 5));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        var ips = "${data["ips"]}";
        var signed = data["signed"];
        var isvalid = _cipher.verify(ips, signed, "${keyDiscoveryTester!.val}");
        if (isvalid) {
          var listip = ips.split(
            ',',
          ); //this response come from remote ip in same LAN ( cotnain ip LAN, ip public its self)
          //ip : found = same subnet
          listip.add(ipSibling);

          listip = Set<String>.from(listip).toList();

          for (var ip in listip) {
            try {
              if (ip.isNotEmpty) {
                if (ip.indexOf(":") > 0) {
                  connectToNode("$ip", true);
                } else {
                  connectToNode("$ip:$selfPort", true);
                }
                await Future.delayed(Duration(milliseconds: 10));
              }
            } catch (exip) {
              // print('_validIpSibling2ConnectNode:ERR:$ipPort: $exip $listip');
            }
          }
        }
      } else {
        // print(
        //   '$ipSibling:_validIpSibling2ConnectNode:ERR:$ipPort: ${response.statusCode} ${response.body}',
        // );
      }
    } catch (e) {
      // print('$ipSibling:_validIpSibling2ConnectNode:ERR:$ipPort: $e');
    }
  }

  bool _isStarted = false;

  /// Khởi động server và kết nối đến các node khác
  Future<void> start(
    Future<void> Function(WebSocket, String, bool) handlerIncomming,
  ) async {
    _handlersIncomming["__main__"] = handlerIncomming;
    await _startSelfServer();
    _isStarted = true;
    _connectToOtherNodes();

    _discorveryAutoIpPort4NodesSibling();
  }

  Future<void> addHandlerIncomming(
    String subscriberName,
    Future<void> Function(WebSocket, String, bool) handlerIncomming,
  ) async {
    _handlersIncomming["$subscriberName"] = handlerIncomming;
  }

  ///  String body = await utf8.decoder.bind(request).join();
  Future<void> AddApiRoutingHandleIncomming(
    String uriPath,
    Future<String> Function(HttpRequest) handle,
  ) async {
    _apiRoutingHandler[uriPath] = handle;
  }

  Map<String, Future<String> Function(HttpRequest)> _apiRoutingHandler = {};

  /// WebSocket server lắng nghe các node khác
  Future<void> _startSelfServer() async {
    if (selfIp == "" || selfIp == "0.0.0.0") {
      selfServer = await HttpServer.bind(InternetAddress.anyIPv4, selfPort);
    } else {
      selfServer = await HttpServer.bind(selfIp, selfPort);
    }
    print(
      '$selfIpPort WebSocket server đang chạy tại ws://$selfIp:$selfPort/ws',
    );

    // iplan = await getLocalIpAddress(itype: InternetAddressType.IPv6);
    // if (iplan != null && iplan.isNotEmpty) {
    //   ips = "$ips,$iplan";
    // }
    _localLanIp = await getLocalIpAddress();
    _publicIp = await getPublicIp();

    selfServer!.listen((HttpRequest request) async {
      final response = request.response;
      response.headers.set('Access-Control-Allow-Origin', '*');
      response.headers.set('Access-Control-Allow-Headers', 'Cache-Control');
      //
      if (_apiRoutingHandler.containsKey(request.uri.path)) {
        try {
          var resdata = await _apiRoutingHandler[request!.uri!.path!]!(request);
          response
            ..statusCode = HttpStatus.ok
            ..write(resdata)
            ..close();
        } catch (eapi) {
          response
            ..statusCode = HttpStatus.internalServerError
            ..write("$eapi")
            ..close();
        }
      } else if (request.uri.path.startsWith('/nodes/valid/')) {
        var pubkey = request.uri.path.replaceFirst("/nodes/valid/", "");
         String body = await utf8.decoder.bind(request).join();
        pubkey = Uri.decodeComponent(pubkey);
        String ips = "";
        if (_cipher.isKeyPairMatch(keyDiscoveryTester!.key!, pubkey)) {
          ips = selfIp;

          if (_localLanIp != null) {
            ips = "$ips,$_localLanIp";
          }
          if (_publicIp != null) {
            ips = "$ips,$_publicIp";
          }
        }

        var ipsSigned = _cipher.sign(ips, keyDiscoveryTester!.key!);

        response
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({"ips": ips, "signed": ipsSigned}))
          ..close();
        return;
      } else if (request.uri.path.startsWith('/ws') &&
          WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        clientsConnectedFromOthers.add(socket);
        var socketaddrport =
            "${request.connectionInfo?.remoteAddress} ${request.connectionInfo?.remotePort}";
        print('$selfIpPort Client server mới kết nối: $socketaddrport');

        socket.listen(
          (data) => _handleIncoming(socket, data, isServerSide: true),
          onDone: () {
            print('$socketaddrport Client ngắt kết nối khỏi server');
            clientsConnectedFromOthers.remove(socket);
          },
          onError: (e) {
            print('$socketaddrport Lỗi từ client server: $e');
            clientsConnectedFromOthers.remove(socket);
          },
        );
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('$selfIpPort Protocol invalid')
          ..close();
      }
    });
  }

  /// Chủ động kết nối đến các node khác
  void _connectToOtherNodes() {
    for (final address in nodeAddresses) {
      if (address == selfIpPort) continue;
      connectToNode(address, false);
    }
  }

  void connectToNodeForce(String address, bool isLanIpPort) {
    try {
      socketsConnect2OtherNodes[address]!.close();
    } catch (e) {}
    try {
      socketsConnect2OtherNodes.remove(address);
    } catch (e) {}

    _scheduleReconnect(address, isLanIpPort);
  }

  String _normalizeAddress(String ipport) {
    ipport = ipport.replaceAll("http://", "");
    ipport = ipport.replaceAll("https://", "");
    var idx = ipport.indexOf('//');
    if (idx >= 0) {
      ipport = ipport.substring(idx + 1);
    }
    return ipport.trim();
  }

  void connectToNode(String address, bool isLanIpPort) async {
    address = _normalizeAddress(address);

    if (_localLanIp != null && address.contains("$_localLanIp:$selfPort")) {
      return;
    }
    if (address.contains("0.0.0.0:$selfPort")) {
      return;
    }

    if (socketsConnect2OtherNodes.containsKey(address)) return;

    final url = 'ws://$address/ws';
    try {
      final socket = await WebSocket.connect(url);
      socketsConnect2OtherNodes[address] = socket;
      print('$selfIpPort Đã kết nối tới $address');

      if (isLanIpPort) {
        _ipPortLanNodesConnected[address] = socket;
      }

      // print("--------------------------------------------");
      // print(socketsConnect2OtherNodes.keys);
      // print(_ipPortLanNodesConnected.keys);

      socket.listen(
        (data) {
          _handleIncoming(socket, data, isServerSide: false);
        },
        onDone: () {
          print('$selfIpPort Ngắt kết nối từ $address');
          socketsConnect2OtherNodes.remove(address);
          _ipPortLanNodesConnected.remove(address);
          _scheduleReconnect(address, isLanIpPort);
        },
        onError: (e) {
          print('$selfIpPort Lỗi từ $address: $e');
          socketsConnect2OtherNodes.remove(address);
          _ipPortLanNodesConnected.remove(address);
          _scheduleReconnect(address, isLanIpPort);
        },
        cancelOnError: true,
      );
    } catch (e) {
      //print('$selfIpPort Kết nối thất bại tới $address: $e');

      socketsConnect2OtherNodes.remove(address);
      _ipPortLanNodesConnected.remove(address);
      _scheduleReconnect(address, isLanIpPort);
    }
  }

  void _scheduleReconnect(String address, bool isLanIpPort) {
    Timer(
      Duration(seconds: isLanIpPort ? 60 : 10),
      () => connectToNode(address, isLanIpPort),
    );
  }

  /// Gửi tới tất cả node khác (client + server)
  Future<void> broadcast(String jsondata) async {
    broadcastToClientTryWait(jsondata);
    broadcastToNodeTryWait(jsondata);
  }

  Future<void> broadcastToNodeTryWait(String jsondata) async {
    while (socketsConnect2OtherNodes.isEmpty) {
      await Future.delayed(Duration(seconds: 1));
    }
    for (var socket in socketsConnect2OtherNodes.values) {
      if (socket.readyState == WebSocket.open) {
        socket.add(jsondata);
      }
    }
  }

  Future<void> broadcastToClientTryWait(String jsondata) async {
    while (clientsConnectedFromOthers.isEmpty) {
      await Future.delayed(Duration(seconds: 1));
    }
    for (var socket in clientsConnectedFromOthers) {
      if (socket.readyState == WebSocket.open) {
        socket.add(jsondata);
      }
    }
  }

  Future<void> sendData(WebSocket socket, String jsondata) async {
    if (socket.readyState == WebSocket.open) {
      socket.add(jsondata);
    }
  }

  void _handleIncoming(
    WebSocket srcSocket,
    String jsondata, {
    required bool isServerSide,
  }) {
    // try {
    //   // TODO: xử lý tùy logic ứng dụng
    // } catch (e) {
    //   print('Dữ liệu không hợp lệ: $e');
    // }
    for (var h in _handlersIncomming.values) {
      h(srcSocket, jsondata, isServerSide);
    }
  }

  bool _isShutdown = false;
  void shutdown() {
    _isShutdown = true;
    for (var socket in socketsConnect2OtherNodes.values) {
      socket.close();
    }
    for (var socket in clientsConnectedFromOthers) {
      socket.close();
    }
    selfServer?.close();
  }
}
/**
 * 
 * 
 * 
upstream blockchainairoboticsvn  {
    server                    10.10.10.104:21213 fail_timeout=0;
}

 server {
    listen 21213;
    server_name airobotics.vn;

    location /nodes/ {
        proxy_pass http://blockchainairoboticsvn;  
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        add_header Access-Control-Allow-Origin *;
      add_header Access-Control-Allow-Headers *;
    }

    location /ws {
        proxy_pass http://blockchainairoboticsvn;  
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        add_header Access-Control-Allow-Origin *;
      add_header Access-Control-Allow-Headers *;
    }
}
curl --location 'http://10.10.10.104:21213/nodes/valid/BEJW3kZ38Nhq6GtClzxsnpdPWX499s3PlIyFvAcO4SHKRbYhGfVHw1fXPAJ2LdI%2FdNVqsF1Rox4s3I5GWtQ6E9A%3D'
 */