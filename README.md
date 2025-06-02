# dart-run-as-httpserver-api-sse-ws

inceptor_genesis_node/bin/inceptor_genesis_node.dart

                sample code connect
                client_connect() 

                server run as service: websocket, apirestful, server send event 
                void main()

# dart run 

                        cd inceptor_genesis_node
                        dart run

# docker file 

check dockerfile

# dart create -t package-simple my_package

                    my_package/
                    ├── lib/
                    │   └── my_package.dart   <-- file chính export code của bạn
                    ├── test/
                    ├── pubspec.yaml


# dart create -t console-full my_blockchain_node


                    my_blockchain_node/
                    ├── bin/
                    │   └── main.dart        👈 Entry point (start node here)
                    ├── lib/
                    │   ├── blockchain.dart  👈 Block & Chain logic
                    │   ├── p2p.dart         👈 P2P networking logic
                    │   └── node.dart        👈 Full node controller
                    ├── data/
                    │   └── blockchain.json  👈 Lưu local blockchain
                    ├── pubspec.yaml

# Sử dụng package trong project console-full

                    /workspace
                    ├── my_package/
                    └── my_console_app/

                    
                    Trong my_console_app/pubspec.yaml, thêm phần path dependency:

                    dependencies:
                    my_package:
                        path: ../my_package


# publish một package Dart lên pub.dev

Chuẩn bị pubspec.yaml

                    name: my_package                 # Tên package, viết thường, không dấu
                    description: A sample Dart package for XYZ functionality.
                    version: 0.0.1                  # Phiên bản, bắt đầu từ 0.0.1
                    homepage: https://github.com/yourname/my_package  # URL repo/code hoặc homepage
                    author: Your Name <youremail@example.com>
                    environment:
                    sdk: ">=2.18.0 <4.0.0"

                    dependencies:
                    # Các dependencies cần thiết

                    dev_dependencies:
                    test: ^1.21.0                 # Nên có test package


Tạo thư mục test/

Viết ít nhất 1 test dùng package test

                    import 'package:test/test.dart';
                    import 'package:my_package/my_package.dart';

                    void main() {
                    test('greet returns correct greeting', () {
                        expect(greet('World'), 'Hello, World!');
                    });
                    }
