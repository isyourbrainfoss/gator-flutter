import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gator/core/constants.dart';

/// Immutable typed settings model replacing `Map<String, dynamic>` usage.
///
/// All fields correspond to keys in the legacy gatorDefaults.
/// Use [fromMap] to load (applies merge/validate/migrate), [toMap] for
/// persistence roundtrips, and [copyWith] / [withUpdated] for mutations.
@immutable
class GatorSettings {
  const GatorSettings({
    this.colorScheme = 'default',
    this.saveDir,
    this.yes = true,
    this.overwrite = false,
    this.debug = false,
    this.noCompress = false,
    this.ask = false,
    this.local = false,
    this.internalDns = false,
    this.multicast = defaultMulticast,
    this.ip = '',
    this.throttleUpload = '',
    this.relay = defaultRelay,
    this.relay6 = defaultRelay6,
    this.pass = '',
    this.socks5 = '',
    this.connect = '',
    this.defaultCode = '',
    this.hash = defaultHash,
    this.zipFolder = false,
    this.noLocal = false,
    this.noMulti = false,
    this.git = false,
    this.port = defaultPort,
    this.transfers = defaultTransfers,
    this.qr = false,
    this.showQrImage = true,
    this.showShellOutput = false,
    this.showAdvancedSettings = false,
    this.curve = defaultCurve,
    this.testing = false,
    this.quiet = false,
    this.disableClipboard = false,
    this.extendedClipboard = false,
  });

  final String colorScheme;
  final String? saveDir;
  final bool yes;
  final bool overwrite;
  final bool debug;
  final bool noCompress;
  final bool ask;
  final bool local;
  final bool internalDns;
  final String multicast;
  final String ip;
  final String throttleUpload;
  final String relay;
  final String relay6;
  final String pass;
  final String socks5;
  final String connect;
  final String defaultCode;
  final String hash;
  final bool zipFolder;
  final bool noLocal;
  final bool noMulti;
  final bool git;
  final int port;
  final int transfers;
  final bool qr;
  final bool showQrImage;
  final bool showShellOutput;
  final bool showAdvancedSettings;
  final String curve;
  final bool testing;
  final bool quiet;
  final bool disableClipboard;
  final bool extendedClipboard;

  factory GatorSettings.defaults() => const GatorSettings();

  /// Creates from raw (possibly partial/persisted) map.
  /// Applies mergeWithDefaults + validate + migrate exactly as before.
  factory GatorSettings.fromMap(Map<String, dynamic> raw) {
    var m = _mergeWithDefaults(raw);
    m = _validate(m);
    m = _migrateStale(m);
    return GatorSettings._fromMap(m);
  }

  factory GatorSettings._fromMap(Map<String, dynamic> m) {
    return GatorSettings(
      colorScheme: (m['color_scheme'] as String?) ?? 'default',
      saveDir: m['save_dir'] as String?,
      yes: (m['yes'] as bool?) ?? true,
      overwrite: (m['overwrite'] as bool?) ?? false,
      debug: (m['debug'] as bool?) ?? false,
      noCompress: (m['no_compress'] as bool?) ?? false,
      ask: (m['ask'] as bool?) ?? false,
      local: (m['local'] as bool?) ?? false,
      internalDns: (m['internal_dns'] as bool?) ?? false,
      multicast: (m['multicast'] as String?) ?? defaultMulticast,
      ip: (m['ip'] as String?) ?? '',
      throttleUpload: (m['throttle_upload'] as String?) ?? '',
      relay: (m['relay'] as String?) ?? defaultRelay,
      relay6: (m['relay6'] as String?) ?? defaultRelay6,
      pass: (m['pass'] as String?) ?? '',
      socks5: (m['socks5'] as String?) ?? '',
      connect: (m['connect'] as String?) ?? '',
      defaultCode: (m['default_code'] as String?) ?? '',
      hash: (m['hash'] as String?) ?? defaultHash,
      zipFolder: (m['zip_folder'] as bool?) ?? false,
      noLocal: (m['no_local'] as bool?) ?? false,
      noMulti: (m['no_multi'] as bool?) ?? false,
      git: (m['git'] as bool?) ?? false,
      port: (m['port'] as int?) ?? defaultPort,
      transfers: (m['transfers'] as int?) ?? defaultTransfers,
      qr: (m['qr'] as bool?) ?? false,
      showQrImage: (m['show_qr_image'] as bool?) ?? true,
      showShellOutput: (m['show_shell_output'] as bool?) ?? false,
      showAdvancedSettings: (m['show_advanced_settings'] as bool?) ?? false,
      curve: (m['curve'] as String?) ?? defaultCurve,
      testing: (m['testing'] as bool?) ?? false,
      quiet: (m['quiet'] as bool?) ?? false,
      disableClipboard: (m['disable_clipboard'] as bool?) ?? false,
      extendedClipboard: (m['extended_clipboard'] as bool?) ?? false,
    );
  }

  GatorSettings copyWith({
    String? colorScheme,
    String? saveDir,
    bool? yes,
    bool? overwrite,
    bool? debug,
    bool? noCompress,
    bool? ask,
    bool? local,
    bool? internalDns,
    String? multicast,
    String? ip,
    String? throttleUpload,
    String? relay,
    String? relay6,
    String? pass,
    String? socks5,
    String? connect,
    String? defaultCode,
    String? hash,
    bool? zipFolder,
    bool? noLocal,
    bool? noMulti,
    bool? git,
    int? port,
    int? transfers,
    bool? qr,
    bool? showQrImage,
    bool? showShellOutput,
    bool? showAdvancedSettings,
    String? curve,
    bool? testing,
    bool? quiet,
    bool? disableClipboard,
    bool? extendedClipboard,
  }) {
    return GatorSettings(
      colorScheme: colorScheme ?? this.colorScheme,
      saveDir: saveDir ?? this.saveDir,
      yes: yes ?? this.yes,
      overwrite: overwrite ?? this.overwrite,
      debug: debug ?? this.debug,
      noCompress: noCompress ?? this.noCompress,
      ask: ask ?? this.ask,
      local: local ?? this.local,
      internalDns: internalDns ?? this.internalDns,
      multicast: multicast ?? this.multicast,
      ip: ip ?? this.ip,
      throttleUpload: throttleUpload ?? this.throttleUpload,
      relay: relay ?? this.relay,
      relay6: relay6 ?? this.relay6,
      pass: pass ?? this.pass,
      socks5: socks5 ?? this.socks5,
      connect: connect ?? this.connect,
      defaultCode: defaultCode ?? this.defaultCode,
      hash: hash ?? this.hash,
      zipFolder: zipFolder ?? this.zipFolder,
      noLocal: noLocal ?? this.noLocal,
      noMulti: noMulti ?? this.noMulti,
      git: git ?? this.git,
      port: port ?? this.port,
      transfers: transfers ?? this.transfers,
      qr: qr ?? this.qr,
      showQrImage: showQrImage ?? this.showQrImage,
      showShellOutput: showShellOutput ?? this.showShellOutput,
      showAdvancedSettings: showAdvancedSettings ?? this.showAdvancedSettings,
      curve: curve ?? this.curve,
      testing: testing ?? this.testing,
      quiet: quiet ?? this.quiet,
      disableClipboard: disableClipboard ?? this.disableClipboard,
      extendedClipboard: extendedClipboard ?? this.extendedClipboard,
    );
  }

  /// String-keyed update helper for legacy-style updateSetting(key, value).
  /// Handles minor type coercion for numeric fields.
  GatorSettings withUpdated(String key, dynamic value) {
    switch (key) {
      case 'color_scheme':
        return copyWith(colorScheme: value as String);
      case 'save_dir':
        return copyWith(saveDir: value as String?);
      case 'yes':
        return copyWith(yes: value as bool);
      case 'overwrite':
        return copyWith(overwrite: value as bool);
      case 'debug':
        return copyWith(debug: value as bool);
      case 'no_compress':
        return copyWith(noCompress: value as bool);
      case 'ask':
        return copyWith(ask: value as bool);
      case 'local':
        return copyWith(local: value as bool);
      case 'internal_dns':
        return copyWith(internalDns: value as bool);
      case 'multicast':
        return copyWith(multicast: value as String);
      case 'ip':
        return copyWith(ip: value as String);
      case 'throttle_upload':
        return copyWith(throttleUpload: value as String);
      case 'relay':
        return copyWith(relay: value as String);
      case 'relay6':
        return copyWith(relay6: value as String);
      case 'pass':
        return copyWith(pass: value as String);
      case 'socks5':
        return copyWith(socks5: value as String);
      case 'connect':
        return copyWith(connect: value as String);
      case 'default_code':
        return copyWith(defaultCode: value as String);
      case 'hash':
        return copyWith(hash: value as String);
      case 'zip_folder':
        return copyWith(zipFolder: value as bool);
      case 'no_local':
        return copyWith(noLocal: value as bool);
      case 'no_multi':
        return copyWith(noMulti: value as bool);
      case 'git':
        return copyWith(git: value as bool);
      case 'port':
        final p = value is int
            ? value
            : (int.tryParse(value?.toString() ?? '') ?? port);
        return copyWith(port: p);
      case 'transfers':
        final t = value is int
            ? value
            : (int.tryParse(value?.toString() ?? '') ?? transfers);
        return copyWith(transfers: t);
      case 'qr':
        return copyWith(qr: value as bool);
      case 'show_qr_image':
        return copyWith(showQrImage: value as bool);
      case 'show_shell_output':
        return copyWith(showShellOutput: value as bool);
      case 'show_advanced_settings':
        return copyWith(showAdvancedSettings: value as bool);
      case 'curve':
        return copyWith(curve: value as String);
      case 'testing':
        return copyWith(testing: value as bool);
      case 'quiet':
        return copyWith(quiet: value as bool);
      case 'disable_clipboard':
        return copyWith(disableClipboard: value as bool);
      case 'extended_clipboard':
        return copyWith(extendedClipboard: value as bool);
      default:
        return this;
    }
  }

  /// Full map representation using legacy snake_case keys (for persistence,
  /// croc arg builders during transition, and compat).
  Map<String, dynamic> toMap() => {
        'color_scheme': colorScheme,
        'save_dir': saveDir,
        'yes': yes,
        'overwrite': overwrite,
        'debug': debug,
        'no_compress': noCompress,
        'ask': ask,
        'local': local,
        'internal_dns': internalDns,
        'multicast': multicast,
        'ip': ip,
        'throttle_upload': throttleUpload,
        'relay': relay,
        'relay6': relay6,
        'pass': pass,
        'socks5': socks5,
        'connect': connect,
        'default_code': defaultCode,
        'hash': hash,
        'zip_folder': zipFolder,
        'no_local': noLocal,
        'no_multi': noMulti,
        'git': git,
        'port': port,
        'transfers': transfers,
        'qr': qr,
        'show_qr_image': showQrImage,
        'show_shell_output': showShellOutput,
        'show_advanced_settings': showAdvancedSettings,
        'curve': curve,
        'testing': testing,
        'quiet': quiet,
        'disable_clipboard': disableClipboard,
        'extended_clipboard': extendedClipboard,
      };

  /// Alias for toMap() usable by arg builders.
  Map<String, dynamic> toArgsMap() => toMap();

  /// Returns a diff map containing only values that differ from defaults.
  /// Used by repository save to avoid persisting defaults.
  Map<String, dynamic> toDiffMap() {
    final full = toMap();
    final defs = GatorSettings.defaults().toMap();
    final diff = <String, dynamic>{};
    for (final entry in full.entries) {
      if (entry.value != defs[entry.key]) {
        diff[entry.key] = entry.value;
      }
    }
    return diff;
  }

  // --- internal processing logic (moved from top-level) ---

  static Map<String, dynamic> _mergeWithDefaults(Map<String, dynamic> settings) {
    final merged = Map<String, dynamic>.from(_kDefaults);
    if (Platform.isAndroid && !settings.containsKey('internal_dns')) {
      merged['internal_dns'] = true;
    }
    for (final entry in settings.entries) {
      if (_kDefaults.containsKey(entry.key)) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  static Map<String, dynamic> _validate(Map<String, dynamic> settings) {
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

  static Map<String, dynamic> _migrateStale(Map<String, dynamic> settings) {
    final s = Map<String, dynamic>.from(settings);
    if (s['relay'] == legacyRelay) s['relay'] = '';
    if (s['relay6'] == legacyRelay6) s['relay6'] = '';
    if (s['multicast'] == crocDefaultMulticast) s['multicast'] = '';
    if (s['hash'] == crocDefaultHash) s['hash'] = '';
    if (s['curve'] == crocDefaultCurve) s['curve'] = '';
    if (s['port'] == crocDefaultPort) s['port'] = 0;
    if (s['transfers'] == crocDefaultTransfers) s['transfers'] = 0;
    if (Platform.isAndroid && s['internal_dns'] != true) {
      s['internal_dns'] = true;
    }
    return s;
  }

  /// Canonical defaults as map (source for legacy compat).
  static const Map<String, dynamic> _kDefaults = {
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
    'show_advanced_settings': false,
    'curve': defaultCurve,
    'testing': false,
    'quiet': false,
    'disable_clipboard': false,
    'extended_clipboard': false,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GatorSettings &&
          runtimeType == other.runtimeType &&
          colorScheme == other.colorScheme &&
          saveDir == other.saveDir &&
          yes == other.yes &&
          overwrite == other.overwrite &&
          debug == other.debug &&
          noCompress == other.noCompress &&
          ask == other.ask &&
          local == other.local &&
          internalDns == other.internalDns &&
          multicast == other.multicast &&
          ip == other.ip &&
          throttleUpload == other.throttleUpload &&
          relay == other.relay &&
          relay6 == other.relay6 &&
          pass == other.pass &&
          socks5 == other.socks5 &&
          connect == other.connect &&
          defaultCode == other.defaultCode &&
          hash == other.hash &&
          zipFolder == other.zipFolder &&
          noLocal == other.noLocal &&
          noMulti == other.noMulti &&
          git == other.git &&
          port == other.port &&
          transfers == other.transfers &&
          qr == other.qr &&
          showQrImage == other.showQrImage &&
          showShellOutput == other.showShellOutput &&
          showAdvancedSettings == other.showAdvancedSettings &&
          curve == other.curve &&
          testing == other.testing &&
          quiet == other.quiet &&
          disableClipboard == other.disableClipboard &&
          extendedClipboard == other.extendedClipboard;

  @override
  int get hashCode => Object.hashAll([
        colorScheme,
        saveDir,
        yes,
        overwrite,
        debug,
        noCompress,
        ask,
        local,
        internalDns,
        multicast,
        ip,
        throttleUpload,
        relay,
        relay6,
        pass,
        socks5,
        connect,
        defaultCode,
        hash,
        zipFolder,
        noLocal,
        noMulti,
        git,
        port,
        transfers,
        qr,
        showQrImage,
        showShellOutput,
        showAdvancedSettings,
        curve,
        testing,
        quiet,
        disableClipboard,
        extendedClipboard,
      ]);

  @override
  String toString() => 'GatorSettings(colorScheme: $colorScheme, ... )';
}

/// Canonical default settings (ported from Gator settings.py DEFAULTS).
/// Derived from typed model for exact compat.
Map<String, dynamic> get gatorDefaults => GatorSettings._kDefaults;

/// Merge user overrides with defaults without mutating the input.
Map<String, dynamic> mergeWithDefaults(Map<String, dynamic> settings) {
  return GatorSettings.fromMap(settings).toMap();
}

/// Clamp and normalize known fields.
Map<String, dynamic> validateSettings(Map<String, dynamic> settings) {
  // Run validate step and return map form (used by repo/tests)
  final validated = GatorSettings._validate(
    Map<String, dynamic>.from(settings),
  );
  // To fully match old process, but validate alone returns clamped map.
  // For legacy validateSettings callers (mainly tests), return as-is after validate.
  return validated;
}

/// Clear stale relay/multicast/hash values from older Gator versions.
Map<String, dynamic> migrateStaleSettings(Map<String, dynamic> settings) {
  final migrated = GatorSettings._migrateStale(
    Map<String, dynamic>.from(settings),
  );
  return migrated;
}

/// Load, validate, and migrate settings from raw persisted data.
Map<String, dynamic> processSettings(Map<String, dynamic> raw) {
  return GatorSettings.fromMap(raw).toMap();
}

/// Resolve the default save directory label (actual path resolved at runtime).
String getDefaultSaveDirLabel() => 'Downloads/Gator';