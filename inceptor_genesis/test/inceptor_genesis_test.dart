import 'package:inceptor_genesis/inceptor_genesis.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    var nodeAddress= StringCipher.instance.generate();
   FullNode fullNode =FullNode("0.0.0.0:21213",[]);

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      expect(fullNode!=null, isTrue);
    });
  });
}
