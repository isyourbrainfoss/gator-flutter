import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gator/services/croc_binary_locator.dart';

final crocBinaryLocatorProvider = Provider<CrocBinaryLocator>(
  (ref) => CrocBinaryLocator(),
);

/// Path of a locatable croc binary. Does not wait on `--version`.
final crocAvailableProvider = FutureProvider<String?>((ref) async {
  final locator = ref.watch(crocBinaryLocatorProvider);
  return locator.locate();
});