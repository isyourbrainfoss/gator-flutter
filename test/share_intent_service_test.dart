import 'package:flutter_test/flutter_test.dart';
import 'package:gator/services/share_intent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('share channels are skipped where the platform has none', () async {
    final service = ShareIntentService(supported: false);
    expect(await service.consumePending(), isNull);
    expect(await service.stream.toList(), isEmpty);
  });
}
