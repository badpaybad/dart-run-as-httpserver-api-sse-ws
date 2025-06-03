
/*
dependencies:
  pointycastle: ^3.6.1
  convert: ^3.1.1
  crypto: ^3.0.3
Tạo Private Key / Public Key (ECC P256)
import 'package:pointycastle/export.dart';
import 'dart:typed_data';
import 'package:convert/convert.dart';

AsymmetricKeyPair<PublicKey, PrivateKey> generateKeyPair() {
  final keyParams = ECKeyGeneratorParameters(ECCurve_secp256r1());
  final secureRandom = FortunaRandom()
    ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => DateTime.now().millisecondsSinceEpoch % 256))));
  final generator = ECKeyGenerator()
    ..init(ParametersWithRandom(keyParams, secureRandom));
  return generator.generateKeyPair();
}

// Chuyển String thành Uint8List (mã hóa UTF-8)
Uint8List uint8list = utf8.encode(myString) as Uint8List;

// Chuyển Uint8List thành String (giải mã UTF-8)
String decodedString = utf8.decode(bytes);

// Hàm ký dữ liệu (input là Uint8List)
Uint8List sign(Uint8List dataToSign, ECPrivateKey privateKey) {
  final signer = Signer('SHA-256/ECDSA');
  final privParams = PrivateKeyParameter<ECPrivateKey>(privateKey);
  signer.init(true, privParams);

  ECSignature sig = signer.generateSignature(dataToSign) as ECSignature;

  // Serialize signature: concat r + s (each 32 bytes)
  final rBytes = sig.r.toRadixString(16).padLeft(64, '0');
  final sBytes = sig.s.toRadixString(16).padLeft(64, '0');

  return Uint8List.fromList(hex.decode(rBytes + sBytes));
}

// Hàm xác minh chữ ký
bool verify(Uint8List data, Uint8List signatureBytes, ECPublicKey publicKey) {
  final signer = Signer('SHA-256/ECDSA');
  final pubParams = PublicKeyParameter<ECPublicKey>(publicKey);
  signer.init(false, pubParams);

  // Tách r, s từ signatureBytes (64 bytes)
  final r = BigInt.parse(hex.encode(signatureBytes.sublist(0, 32)), radix: 16);
  final s = BigInt.parse(hex.encode(signatureBytes.sublist(32, 64)), radix: 16);
  final signature = ECSignature(r, s);

  return signer.verifySignature(data, signature);
}
String encodePrivateKey(ECPrivateKey privateKey) {
  final dBytes = privateKey.d!.toRadixString(16).padLeft(64, '0');
  return base64Encode(hex.decode(dBytes));
}

String encodePublicKey(ECPublicKey publicKey) {
  final x = publicKey.Q!.x!.toBigInteger()!.toRadixString(16).padLeft(64, '0');
  final y = publicKey.Q!.y!.toBigInteger()!.toRadixString(16).padLeft(64, '0');

  final publicKeyBytes = hex.decode('04$x$y'); // Uncompressed format (starts with 0x04)
  return base64Encode(publicKeyBytes);
}

// Giải mã privateKey từ Base64
ECPrivateKey decodePrivateKey(String base64PrivateKey) {
  final dBytes = base64Decode(base64PrivateKey);
  final d = BigInt.parse(hex.encode(dBytes), radix: 16);
  final domainParams = ECCurve_secp256r1();
  return ECPrivateKey(d, domainParams);
}

// Giải mã publicKey từ Base64 (định dạng uncompressed 04 + x + y)
ECPublicKey decodePublicKey(String base64PublicKey) {
  final pubBytes = base64Decode(base64PublicKey);

  if (pubBytes[0] != 0x04) {
    throw ArgumentError('Public key không ở định dạng uncompressed (phải bắt đầu bằng 0x04)');
  }

  final xBytes = pubBytes.sublist(1, 33);
  final yBytes = pubBytes.sublist(33, 65);

  final x = BigInt.parse(hex.encode(xBytes), radix: 16);
  final y = BigInt.parse(hex.encode(yBytes), radix: 16);

  final curve = ECCurve_secp256r1();
  final q = curve.createPoint(x, y);

  return ECPublicKey(q, curve);
}

void main() {
  final keyPair = generateKeyPair();
  final privateKey = keyPair.privateKey as ECPrivateKey;
  final publicKey = keyPair.publicKey as ECPublicKey;

  print(' Private Key: ${privateKey.d}');
  print(' Public Key: (${publicKey.Q!.x!.toBigInteger()}, ${publicKey.Q!.y!.toBigInteger()})');
}
import 'dart:convert';
import 'package:crypto/crypto.dart';

class Block {
  final int index;
  final String previousHash;
  final int timestamp;
  final String data;
  late final String hash;

  Block({
    required this.index,
    required this.previousHash,
    required this.timestamp,
    required this.data,
  }) {
    hash = calculateHash();
  }

  String calculateHash() {
    final input = '$index$previousHash$timestamp$data';
    return sha256.convert(utf8.encode(input)).toString();
  }
}

void main() {
  final genesisBlock = Block(
    index: 0,
    previousHash: '0',
    timestamp: DateTime.now().millisecondsSinceEpoch,
    data: 'Genesis block',
  );

  print(' Block Hash: ${genesisBlock.hash}');
}


. Tạo file server: bin/server.dart
import 'dart:io';

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('WebSocket server running on ws://${server.address.address}:${server.port}/ws');

  await for (HttpRequest request in server) {
    if (request.uri.path == '/ws' &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocket socket = await WebSocketTransformer.upgrade(request);
      print('Client connected');

      socket.listen(
        (data) {
          print('Received: $data');
          socket.add('Echo: $data'); // Trả lời client
        },
        onDone: () => print('Client disconnected'),
        onError: (err) => print('Socket error: $err'),
      );
    } else {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.write('WebSocket only');
      await request.response.close();
    }
  }
}
Kết nối client Flutter hoặc Dart console

import 'package:web_socket_channel/web_socket_channel.dart';

final channel = WebSocketChannel.connect(
  Uri.parse('ws://192.168.1.10:8080/ws'), // thay IP bằng server thật
);

channel.sink.add('hello');
channel.stream.listen((message) {
  print('Server says: $message');
});

c# 
using System;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using var ws = new ClientWebSocket();
var uri = new Uri("ws://localhost:8080");

await ws.ConnectAsync(uri, CancellationToken.None);
Console.WriteLine("Connected to WebSocket server!");

// Gửi message ban đầu
var initMessage = "Hello server!";
await SendMessage(ws, initMessage);

var buffer = new byte[1024];
var messageBuffer = new List<byte>();

while (ws.State == WebSocketState.Open)
{
    var result = await ws.ReceiveAsync(new ArraySegment<byte>(buffer), CancellationToken.None);

    // Lưu đoạn data vừa nhận
    messageBuffer.AddRange(buffer.Take(result.Count));

    if (result.MessageType == WebSocketMessageType.Close)
    {
        Console.WriteLine("Server closed connection");
        await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "Client closing", CancellationToken.None);
        break;
    }

    // Nếu đây là đoạn cuối của message thì xử lý message full
    if (result.EndOfMessage)
    {
        var messageBytes = messageBuffer.ToArray();
        var messageText = Encoding.UTF8.GetString(messageBytes);
        Console.WriteLine("Full message received: " + messageText);

        // Xóa buffer để nhận message mới
        messageBuffer.Clear();
    }
}


#ngix ssl

server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    location /ws {
        proxy_pass http://localhost:8080;

        # WebSocket headers
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Forward headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Optional: redirect HTTP to HTTPS
server {
    listen 80;
    server_name example.com;
    return 301 https://$host$request_uri;
}



dependencies:
  web_socket_channel: ^2.4.0
// websocket_server.dart
import 'dart:io';

void main() async {
  final server = await HttpServer.bind('0.0.0.0', 8080);
  print('WebSocket server running on ws://localhost:8080');

  await for (HttpRequest req in server) {
    if (req.uri.path == '/ws' && WebSocketTransformer.isUpgradeRequest(req)) {
      WebSocket socket = await WebSocketTransformer.upgrade(req);
      print('Client connected');

      socket.listen((message) {
        print('Received: $message');
        socket.add('Echo: $message'); // Gửi lại client
      }, onDone: () {
        print('Client disconnected');
      });
    } else {
      req.response.statusCode = HttpStatus.forbidden;
      req.response.write('WebSocket endpoint only');
      await req.response.close();
    }
  }
}


// websocket_client.dart
import 'dart:io';

void main() async {
  final socket = await WebSocket.connect('ws://localhost:8080/ws');
  print('Connected to server');

  // Gửi dữ liệu
  socket.add('Hello WebSocket server');

  // Lắng nghe phản hồi
  socket.listen((data) {
    print('Server says: $data');
  });
}


#  tcp

import 'dart:io';
import 'dart:convert';

void main() async {
  var server = await ServerSocket.bind(InternetAddress.anyIPv4, 4567);
  print('TCP Server started on port 4567');

  await for (Socket client in server) {
    print('Client connected: ${client.remoteAddress.address}');

    client.listen((data) {
      final message = utf8.decode(data);
      print('Received: $message');

      client.write('Server echo: $message');
    }, onDone: () {
      print('Client disconnected');
    });
  }
}


import 'dart:io';
import 'dart:convert';

void main() async {
  final socket = await Socket.connect('localhost', 4567);
  print('Connected to server');

  // Gửi dữ liệu
  socket.write('Hello from client!');

  // Nhận dữ liệu từ server
  socket.listen((data) {
    final message = utf8.decode(data);
    print('Server says: $message');
  });
}

4. Kết nối TCP để truyền dữ liệu
Server lắng nghe

public async Task StartTcpServerAsync(int port)
{
    var listener = new TcpListener(IPAddress.Any, port);
    listener.Start();
    while (true)
    {
        var client = await listener.AcceptTcpClientAsync();
        _ = Task.Run(() => HandleClientAsync(client));
    }
}

Client gửi message

public async Task SendMessageToPeerAsync(string ip, int port, string message)
{
    using var client = new TcpClient();
    await client.ConnectAsync(ip, port);
    using var stream = client.GetStream();
    var data = Encoding.UTF8.GetBytes(message);
    await stream.WriteAsync(data, 0, data.Length);
}

public async Task BroadcastMessageAsync(List<PeerInfo> peers, string message)
{
    var tasks = peers.Select(peer =>
        SendMessageToPeerAsync(peer.IP, peer.Port, message));
    await Task.WhenAll(tasks);
}

1. Gửi Broadcast UDP với Dart
import 'dart:io';
import 'dart:convert';

void main() async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  socket.broadcastEnabled = true; // bật broadcast

  final data = utf8.encode('Hello LAN broadcast!');
  final broadcastAddress = InternetAddress('255.255.255.255');

  print('Sending broadcast...');
  socket.send(data, broadcastAddress, 4567);
  
  await Future.delayed(Duration(seconds: 1));
  socket.close();
}
2. Nhận Broadcast UDP
import 'dart:io';
import 'dart:convert';

void main() async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 4567);
  print('Listening for broadcast on port 4567...');

  socket.listen((event) {
    if (event == RawSocketEvent.read) {
      final datagram = socket.receive();
      if (datagram != null) {
        final message = utf8.decode(datagram.data);
        print('Received from ${datagram.address.address}: $message');
      }
    }
  });
}


3. Dùng Multicast UDP
Tham gia nhóm multicast

import 'dart:io';
import 'dart:convert';

void main() async {
  final multicastAddress = InternetAddress('239.1.2.3');
  final port = 4567;

  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
  socket.joinMulticast(multicastAddress);

  print('Listening multicast ${multicastAddress.address}:$port');

  socket.listen((event) {
    if (event == RawSocketEvent.read) {
      final datagram = socket.receive();
      if (datagram != null) {
        final message = utf8.decode(datagram.data);
        print('Multicast from ${datagram.address.address}: $message');
      }
    }
  });
}

Gửi multicast

import 'dart:io';
import 'dart:convert';

void main() async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

  final multicastAddress = InternetAddress('239.1.2.3');
  final port = 4567;

  final message = utf8.encode('Hello multicast LAN!');
  socket.send(message, multicastAddress, port);

  print('Multicast message sent');
  await Future.delayed(Duration(seconds: 1));
  socket.close();
}

Lưu ý:

    Broadcast: gửi đến địa chỉ 255.255.255.255 trên mạng LAN.

    Multicast: gửi đến nhóm địa chỉ lớp D (224.0.0.0 đến 239.255.255.255).

    Cần bật broadcastEnabled = true để gửi broadcast.

    Địa chỉ và cổng phải trùng nhau để nhận được.

    Firewall hoặc hệ điều hành có thể chặn gói tin UDP broadcast/multicast, bạn cần đảm bảo cấu hình mạng phù hợp.


 1. Dart WebSocket Server gửi event

import 'dart:io';

void main() async {
  var server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('WebSocket server running on ws://localhost:8080');

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocket ws = await WebSocketTransformer.upgrade(request);
      print('Client connected');

      // Gửi event mỗi 2 giây
      Stream.periodic(Duration(seconds: 2), (count) => "Server Event #$count")
          .listen((event) {
        if (ws.readyState == WebSocket.open) {
          ws.add(event);
          print('Sent: $event');
        }
      });

      // Lắng nghe message từ client
      ws.listen((message) {
        print('Received from client: $message');
      }, onDone: () {
        print('Client disconnected');
      });
    } else {
      // Trả về 403 nếu không phải WebSocket upgrade request
      request.response
        ..statusCode = HttpStatus.forbidden
        ..close();
    }
  }
}

2. Dart WebSocket Client nhận event

import 'dart:io';

void main() async {
  try {
    var socket = await WebSocket.connect('ws://localhost:8080');
    print('Connected to server');

    // Lắng nghe event từ server
    socket.listen((data) {
      print('Received event: $data');
    }, onDone: () {
      print('Connection closed');
    });

    // Gửi message thử nghiệm
    socket.add('Hello from client');
  } catch (e) {
    print('Error connecting to WebSocket: $e');
  }
}

sse

import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

void main() async {
  final handler = (Request request) {
    if (request.url.path == 'sse') {
      final controller = StreamController<String>();

      // Tạo response SSE
      final headers = {
        HttpHeaders.contentTypeHeader: 'text/event-stream',
        HttpHeaders.cacheControlHeader: 'no-cache',
        HttpHeaders.connectionHeader: 'keep-alive',
      };

      final stream = controller.stream.map((event) => 'data: $event\n\n');
      final response = Response.ok(stream, headers: headers);

      // Gửi dữ liệu mỗi 2 giây
      Timer.periodic(Duration(seconds: 2), (timer) {
        final timestamp = DateTime.now().toIso8601String();
        controller.add('Server time: $timestamp');
      });

      return response;
    }

    return Response.notFound('Not Found');
  };

  final server = await io.serve(handler, 'localhost', 8080);
  print('SSE Server running on http://${server.address.host}:${server.port}');
}
import 'dart:io';
import 'dart:async';

void main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  print('SSE Server running on http://${server.address.address}:${server.port}');

  await for (HttpRequest request in server) {
    if (request.uri.path == '/sse') {
      handleSse(request);
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found')
        ..close();
    }
  }
}

void handleSse(HttpRequest request) {
  final response = request.response;

  response.headers.set(HttpHeaders.contentTypeHeader, 'text/event-stream');
  response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
  response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

  Timer.periodic(Duration(seconds: 2), (timer) {
    final time = DateTime.now().toIso8601String();
    response.write('data: Server time is $time\n\n');
    response.flush(); // very important!
  });

  // You can optionally detect if the connection closes and clean up
  request.response.done.then((_) {
    print('Client disconnected');
  });
}

response.flush() là cần thiết để đẩy dữ liệu ra ngay thay vì đợi buffer đầy.

response.write('data: ...\n\n') là định dạng tiêu chuẩn của SSE.

SSE giữ kết nối HTTP mở, nên không cần đóng response.

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final request = http.Request('GET', Uri.parse('http://localhost:8080/sse'))
    ..headers['Accept'] = 'text/event-stream';

  final response = await request.send();

  response.stream
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .listen((line) {
    if (line.startsWith('data:')) {
      print('Received: ${line.substring(5).trim()}');
    }
  });
}

nginx proxy for sse

location /sse {
    proxy_pass http://localhost:PORT;
    proxy_http_version 1.1;
    proxy_set_header Connection '';
    chunked_transfer_encoding off;
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 3600;
}
   
 */