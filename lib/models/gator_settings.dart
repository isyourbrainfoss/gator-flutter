import 'package:gator/core/constants.dart';

/// Canonical default settings (ported from Gator settings.py DEFAULTS).
const Map<String, dynamic> gatorDefaults = {
  'color_scheme': 'default',
  'save_dir': null,
  'yes': true,
  'overwrite': false,
  'debug': false,
  'no_compress': false,
  'ask': false,
  'local': false,
  'internal_dns': false,
  'multicast': defaultMulticast,
  'ip': '',
  'throttle_upload': '',
  'relay': defaultRelay,
  'relay6': defaultRelay6,
  'pass': '',
  'socks5': '',
  'connect': '',
  'default_code': '',
  'hash': defaultHash,
  'zip_folder': false,
  'no_local': false,
  'no_multi': false,
  'git': false,
  'port': defaultPort,
  'transfers': defaultTransfers,
  'qr': false,
  'show_qr_image': true,
  'show_shell_output': false,
  'curve': defaultCurve,
  'testing': false,
  'quiet': false,
  'disable_clipboard': false,
  'extended_clipboard': false,
};

/// Merge user overrides with defaults without mutating the input.
Map<String, dynamic> mergeWithDefaults(Map<String, dynamic> settings) {
  final merged = Map<String, dynamic>.from(gatorDefaults);
  for (final entry in settings.entries) {
    if (gatorDefaults.containsKey(entry.key)) {
      merged[entry.key] = entry.value;
    }
  }
  return merged;
}

/// Clamp and normalize known fields.
Map<String, dynamic> validateSettings(Map<String, dynamic> settings) {
  final s = Map<String, dynamic>.from(settings);

  try {
    final p = int.tryParse(s['port']?.toString() ?? '') ?? defaultPort;
    s['port'] = p <= 0 ? 0 : p.clamp(1, 65535);
  } catch (_) {
    s['port'] = defaultPort;
  }

  try {
    final t = int.tryParse(s['transfers']?.toString() ?? '') ?? defaultTransfers;
    s['transfers'] = t <= 0 ? 0 : t.clamp(1, 100);
  } catch (_) {
    s['transfers'] = defaultTransfers;
  }

  s['multicast'] = (s['multicast'] as String? ?? '').trim();
  final h = (s['hash'] as String? ?? '').trim();
  if (h.isNotEmpty && !{'xxhash', 'imohash', 'md5'}.contains(h)) {
    s['hash'] = defaultHash;
  } else {
    s['hash'] = h;
  }
  s['curve'] = (s['curve'] as String? ?? '').trim();

  if (!{'default', 'light', 'dark'}.contains(s['color_scheme'])) {
    s['color_scheme'] = 'default';
  }

  return s;
}

/// Clear stale relay/multicast/hash values from older Gator versions.
Map<String, dynamic> migrateStaleSettings(Map<String, dynamic> settings) {
  final s = Map<String, dynamic>.from(settings);
  if (s['relay'] == legacyRelay) s['relay'] = '';
  if (s['relay6'] == legacyRelay6) s['relay6'] = '';
  if (s['multicast'] == crocDefaultMulticast) s['multicast'] = '';
  if (s['hash'] == crocDefaultHash) s['hash'] = '';
  if (s['curve'] == crocDefaultCurve) s['curve'] = '';
  if (s['port'] == crocDefaultPort) s['port'] = 0;
  if (s['transfers'] == crocDefaultTransfers) s['transfers'] = 0;
  return s;
}

/// Load, validate, and migrate settings from raw persisted data.
Map<String, dynamic> processSettings(Map<String, dynamic> raw) {
  return migrateStaleSettings(validateSettings(mergeWithDefaults(raw)));
}

/// Resolve the default save directory label (actual path resolved at runtime).
String getDefaultSaveDirLabel() => 'Downloads/Gator';