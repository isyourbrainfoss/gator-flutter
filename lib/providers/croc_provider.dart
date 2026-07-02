import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/services/croc_binary_locator.dart';

final crocBinaryLocatorProvider = Provider<CrocBinaryLocator>(
  (ref) => CrocBinaryLocator(),
);

final crocAvailableProvider = FutureProvider<String?>((ref) async {
  final locator = ref.watch(crocBinaryLocatorProvider);
  return locator.verify();
});