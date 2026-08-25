import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gator/core/logger.dart';
import 'package:open_filex/open_filex.dart';

/// Opens a directory in the platform file manager.
abstract final class FolderOpener {
  static const _channel = MethodChannel('org.gator.gator/files');

  static Future<bool> open(String path) async {
    if (path.isEmpty) return false;

    if (Platform.isAndroid) {
      try {
        final ok = await _channel.invokeMethod<bool>(
          'openDirectory',
          {'path': path},
        );
        if (ok == true) return true;
      } on PlatformException catch (e, st) {
        GatorLog.e('FolderOpener', 'openDirectory channel failed', e, st);
      }
    }

    final result = await OpenFilex.open(path);
    return result.type == ResultType.done;
  }
}