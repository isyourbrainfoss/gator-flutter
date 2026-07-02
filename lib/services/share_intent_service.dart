import 'dart:async';

import 'package:flutter/services.dart';

/// Payload from Android share intent (ACTION_SEND / ACTION_SEND_MULTIPLE).
class SharePayload {
  const SharePayload({required this.paths, this.text});

  final List<String> paths;
  final String? text;

  bool get isEmpty => paths.isEmpty && (text == null || text!.isEmpty);

  factory SharePayload.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const SharePayload(paths: []);
    final rawPaths = map['paths'];
    final paths = rawPaths is List
        ? rawPaths.whereType<String>().toList()
        : <String>[];
    final text = map['text'] as String?;
    return SharePayload(paths: paths, text: text);
  }
}

/// Receives files/text shared to Gator from other Android apps.
class ShareIntentService {
  ShareIntentService();

  static const _method = MethodChannel('org.gator.gator/share');
  static const _events = EventChannel('org.gator.gator/share/events');

  Stream<SharePayload> get stream =>
      _events.receiveBroadcastStream().map(
            (event) => SharePayload.fromMap(
              event is Map ? Map<dynamic, dynamic>.from(event) : null,
            ),
          );

  Future<SharePayload?> consumePending() async {
    final result = await _method.invokeMethod<Map<dynamic, dynamic>?>(
      'getPendingShare',
    );
    if (result == null) return null;
    final payload = SharePayload.fromMap(result);
    return payload.isEmpty ? null : payload;
  }
}