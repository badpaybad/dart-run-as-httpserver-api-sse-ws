import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

class ObjectId {
  static Future<String> getMachineId() async {
    if (Platform.isLinux) {
      final result = await Process.run('cat', ['/etc/machine-id']);
      return result.stdout.toString().trim();
    }

    if (Platform.isMacOS) {
      final result = await Process.run('ioreg', [
        '-rd1',
        '-c',
        'IOPlatformExpertDevice',
      ]);
      final match = RegExp(
        r'"IOPlatformUUID" = "(.+)"',
      ).firstMatch(result.stdout);
      return match?.group(1) ?? '';
    }

    if (Platform.isWindows) {
      final result = await Process.run('wmic', ['csproduct', 'get', 'UUID']);
      final lines = result.stdout.toString().trim().split('\n');
      if (lines.length >= 2) {
        return lines[1].trim();
      } else {
        return '';
      }
    }

    return '';
  }

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
