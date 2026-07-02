import 'package:flutter_test/flutter_test.dart';
import 'package:gator/services/croc_binary_locator.dart';

void main() {
  test('locate returns cached path on second call', () async {
    const path = '/tmp/mock-croc';
    final locator = CrocBinaryLocator(cachedPath: path);
    expect(await locator.locate(), path);
    expect(await locator.locate(), path);
  });
}