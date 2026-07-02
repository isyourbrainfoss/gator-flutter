import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/services/share_intent_service.dart';

final shareIntentServiceProvider = Provider<ShareIntentService>(
  (ref) => ShareIntentService(),
);