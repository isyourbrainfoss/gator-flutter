/// Application-wide constants (ported from Gator settings.py).
library;

const String appId = 'org.gator.Gator';
const String appName = 'Gator';
// appVersion removed: prefer runtime value from appVersionProvider (package_info_plus).
const String crocVersion = '11.6.6';
const String crocBinary = 'croc';

/// `croc --version` prints `croc version 11.6.6` (optional leading v).
final RegExp _reportedCrocVersionRe = RegExp(
  r'\bversion\s+v?(\d+\.\d+\.\d+)\b',
  caseSensitive: false,
);

/// Release from raw `croc --version` output, or null when it is not a release.
String? reportedCrocVersion(String? output) {
  if (output == null) return null;
  return _reportedCrocVersionRe.firstMatch(output)?.group(1);
}

/// About label, e.g. `croc v11.6.6`. Uses [reported] when it parses, else the pin.
String crocAboutLabel([String? reported]) {
  final version = reportedCrocVersion(reported) ?? crocVersion;
  return 'croc v$version';
}

const String codeIsPrefix = 'Code is: ';

const int defaultPort = 0;
const int defaultTransfers = 0;
const String defaultMulticast = '';
const String defaultRelay = '';
const String defaultRelay6 = '';
const String defaultHash = '';
const String defaultCurve = '';

const int crocDefaultPort = 9009;
const int crocDefaultTransfers = 4;
const String crocDefaultMulticast = '239.255.255.250';
const String crocDefaultHash = 'xxhash';
const String crocDefaultCurve = 'p256';

const String legacyRelay = '37.27.244.215:9009';
const String legacyRelay6 = '[2a01:4f9:c013:7b04::1]:9009';

const String settingsStorageKey = 'gator_settings';

/// Maximum number of shell log lines to retain in send/receive states.
/// Prevents unbounded memory growth for long-running or verbose transfers.
const int kMaxLogLines = 300;
