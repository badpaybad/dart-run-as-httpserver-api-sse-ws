import 'dart:math';
import 'dart:typed_data';

class ObjectId {
  static final Random _random = Random.secure();
  static final int _machineId = _random.nextInt(0xFFFFFF); // 3 bytes
  static final int _processId = _random.nextInt(0xFFFF); // 2 bytes
  static int _counter = _random.nextInt(0xFFFFFF); // 3 bytes

  final Uint8List _idBytes;

  ObjectId._(this._idBytes);

  factory ObjectId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final buffer = BytesBuilder();

    // 4-byte timestamp
    buffer.add(_intToBytes(timestamp, 4));

    // 3-byte machine ID
    buffer.add(_intToBytes(_machineId, 3));

    // 2-byte process ID
    buffer.add(_intToBytes(_processId, 2));

    // 3-byte counter
    buffer.add(_intToBytes(_counter++ % 0xFFFFFF, 3));

    return ObjectId._(buffer.toBytes());
  }

  static List<int> _intToBytes(int value, int byteCount) {
    final bytes = Uint8List(byteCount);
    for (int i = 0; i < byteCount; i++) {
      bytes[byteCount - i - 1] = (value >> (8 * i)) & 0xFF;
    }
    return bytes;
  }

  @override
  String toString() {
    return _idBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Optional: convert from hex string
  factory ObjectId.fromHex(String hexString) {
    if (hexString.length != 24)
      throw FormatException('Invalid ObjectId hexString');
    final bytes = Uint8List(12);
    for (int i = 0; i < 12; i++) {
      bytes[i] = int.parse(hexString.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return ObjectId._(bytes);
  }
}
