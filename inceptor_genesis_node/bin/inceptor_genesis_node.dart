import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

import 'package:inceptor_genesis_node/inceptor_genesis_node.dart'
    as inceptor_genesis_node;
import 'package:inceptor_genesis/inceptor_genesis.dart';

Future<void> client_connect() async {
  await Isolate.spawn((apiurl) async {
    var r = await http.post(
      Uri.parse(apiurl),
      body: {"date": "request test at ${DateTime.now().toIso8601String()}"},
    );

    print("reponse from api: ${r.body}");
  }, "http://127.0.0.1:21213/api/ping");

  await Isolate.spawn((urisse) async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('$urisse'));

    // Quan trọng: đặt đúng header để server hiểu đây là SSE
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    request.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    request.headers.set(HttpHeaders.contentTypeHeader, 'text/event-stream');
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    //

    final response = await request.close();

    print('SseCli Connected to SSE stream... $urisse');

    response
        .transform(utf8.decoder)
        //.transform(const LineSplitter())
        .listen(
          (line) {
            print('---------- SseCli Received: ${line}');
            // if (line.startsWith('data:')) {
            //   print('SseCli Received: ${line.substring(5).trim()}');
            // }
          },
          onError: (e) {
            print('SseCli Error: $e');
          },
          onDone: () {
            print('SseCli Connection closed');
          },
        );
  }, "http://127.0.0.1:21213/sse");

  await Isolate.spawn((uriws) async {
    //client web socket
    print("start ws client node connect to: ${uriws}");
    final channel = WebSocketChannel.connect(Uri.parse("$uriws"));
    final name = 'WsClient#${Isolate.current.hashCode}';

    // Nghe tin nhắn từ server
    channel.stream.listen(
      (message) async {
        print('$name received: $message');
        await Future.delayed(Duration(seconds: 5));
        channel.sink.add('$name:PING');
      },
      onDone: () {
        print('$name disconnected');
      },
      onError: (e) {
        print('$name error: $e');
      },
    );

    // Gửi tin nhắn sau khi kết nối
    channel.sink.add('$name:PING');
  }, "ws://0.0.0.0:21213/ws");
}

Future<void> main(List<String> arguments) async {
  print('Hello world: ${inceptor_genesis_node.calculate()}!');

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 21213);
  print(
    'WebSocket server running on ws://${server.address.address}:${server.port}/ws',
  );

  client_connect();

  final Set<HttpResponse> _sse_clients = {};

  await for (HttpRequest request in server) {
    final response = request.response;

    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Headers', 'Cache-Control');

    if (request.uri.path.startsWith('/ws') &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocket socket = await WebSocketTransformer.upgrade(request);
      print('Ws Client connected');

      socket.listen(
        (data) async {
          final now = DateTime.now().toIso8601String();

          print('WS Server Received: $data');
          socket.add('PONG:$data at $now'); // Trả lời client
        },
        onDone: () => print('WSClient disconnected'),
        onError: (err) => print('WSSocket error: $err'),
      );
      continue;
    } else if (request.uri.path.startsWith('/sse')) {
      response.contentLength = -1;
      response.bufferOutput = false;
      response.headers.set('Content-Type', 'text/event-stream; charset=utf-8');
      response.headers.set(
        'Cache-Control',
        'no-cache, no-store, must-revalidate',
      );
      response.headers.set('Connection', 'keep-alive');
      response.headers.set(
        'X-Accel-Buffering',
        'no',
      ); // Nginx buffering disable

      print('SSe Client connected: ${request.connectionInfo?.remoteAddress}');
      print('Received request: ${request.method} ${request.uri}');
      Timer? timer;
      if (response.persistentConnection) {
        try {
          // CRITICAL: Set headers BEFORE checking persistentConnection

          // Add client to the set
          _sse_clients.add(response);
          print('SSE Client connected. Total clients: ${_sse_clients.length}');

          // Send comment to keep connection alive (optional but good practice)
          response.write(':\n\n');
          // response.close();
          await response
              .flush()
              .whenComplete(() async {
                print('SSE Initial flush init done -------------------');
              })
              .catchError((e) {
                print('SSE Initial flush error: $e');
              });

          // Periodically send data
          final timer = Timer.periodic(Duration(seconds: 2), (t) async {
            final now = DateTime.now().toIso8601String();

            response.write("data: SSE Server time: ${now}\n\n");

            await response.flush().catchError((e) {
              t.cancel();
              print('SSE Initial flush error: $e');
            });

            print('SSE flush msg done ------------------- at: $now ');
          });

          // Clean up when client disconnects
          // Handle client disconnect - CRITICAL: Use unawaited
          response.done
              .then((_) {
                print('Client disconnected normally');
                timer?.cancel();
                _sse_clients.remove(response);
                print('Total clients after disconnect: ${_sse_clients.length}');
              })
              .catchError((error) {
                print('Client connection error: $error');
                timer?.cancel();
                _sse_clients.remove(response);
                print('Total clients after error: ${_sse_clients.length}');
              });
        } catch (ex) {
          _sse_clients.remove(response);
          print('SSE Client Failed. Total clients: ${_sse_clients.length}');
          print("Err SSE");
          print(ex);
        }
      } else {
        _sse_clients.remove(response);
        print('SSE Client Failed. Total clients: ${_sse_clients.length}');
      }

      continue;
    } else if (request.uri.path.startsWith('/api/ping')) {
      final bodyString = await utf8.decoder.bind(request).join();

      final now = DateTime.now().toIso8601String();
      response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            "api": "api called",
            'message': 'Hello from API $now',
            "request": bodyString,
          }),
        )
        ..close();
      continue;
    } else {
      final now = DateTime.now().toIso8601String();

      response.statusCode = HttpStatus.notFound;
      response.write(jsonEncode({"message": '404 Page not found at $now'}));
      await response.close();
    }
  }
  var a = Awesome();
  print(a);

  while (true) {
    await Future.delayed(Duration(seconds: 1));
  }
}
