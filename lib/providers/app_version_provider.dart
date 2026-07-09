import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Exposes the application version string obtained at runtime via PackageInfo.fromPlatform().
/// Format: 'version+buildNumber' (e.g. '1.5.11+12') when build number is available.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final version = info.version;
  final buildNumber = info.buildNumber;
  if (buildNumber.isNotEmpty) {
    return '$version+$buildNumber';
  }
  return version;
});
