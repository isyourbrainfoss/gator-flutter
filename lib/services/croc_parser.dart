import 'package:gator/core/constants.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/models/transfer_state.dart';

final _codeIsRe = RegExp(r'^code is:\s*', caseSensitive: false);
final _codeIsExtractRe = RegExp(r'code is:\s*(\S+)', caseSensitive: false);
final _ansiRe = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]');
final _crocCmdRe = RegExp(r'^croc(?:\s+(.+))?$', caseSensitive: false);
final _parenNoticeRe = RegExp(r'\s*\(.*\)\s*$');
final _acceptPromptRe = RegExp(
  r'^Accept .+ \(.*\)\? \(Y/n\)',
  caseSensitive: false,
);
final _legacyFileNameRe = RegExp(r'(?:Receiving|Sending) file \(([^)]+)\)');
final _sendingQuotedRe = RegExp(r"^Sending '([^']+)'");
// v11.5 normalized progressbar: optional action, padded %, `|…|` bar.
final _progressLineRe = RegExp(
  r'^(?:(?:Hashing|Uploading|Downloading)\s+)?(.+?)\s+(\d{1,3})%\s*\|',
  caseSensitive: false,
);
// schollz/progressbar v3.19 SI units use a leading space and lowercase kB.
final _speedRe = RegExp(
  r'\(\s*(?:([\d.]+)\s*([kKMGT]?i?B)?/([\d.]+)\s*([kKMGT]?i?B),\s*)?([\d.]+\s*[kKMGT]?i?B/s)\)',
  caseSensitive: false,
);
final _etaRe = RegExp(r'\[([^:\]]+):([^\]]+)\]');
final _fileCountRe = RegExp(r'\s(\d+)/(\d+)\s*$');
final _nFilesRe = RegExp(r'^(\d+)\s+files$', caseSensitive: false);

/// Parsed croc progressbar line (v10/v11 progressbar v3).
class CrocProgressInfo {
  const CrocProgressInfo({
    required this.fraction,
    this.fileName,
    this.speed,
    this.eta,
    this.transferred,
    this.total,
    this.fileIndex,
    this.fileCount,
    this.hashing = false,
  });

  final double fraction;
  final String? fileName;
  final String? speed;
  final String? eta;
  final String? transferred;
  final String? total;
  final int? fileIndex;
  final int? fileCount;
  final bool hashing;

  CrocProgressEvent toEvent() => CrocProgressEvent(
        fraction,
        fileName: fileName,
        speed: speed,
        eta: eta,
        transferred: transferred,
        total: total,
        fileIndex: fileIndex,
        fileCount: fileCount,
        hashing: hashing,
      );
}

/// Strip terminal ANSI escape sequences from croc output.
String stripAnsi(String line) => line.replaceAll(_ansiRe, '');

/// Extract a transfer code from a croc output line, if present.
///
/// Supports:
/// - legacy `Code is: word-word-word` (croc ≤ 11.0.x)
/// - v11.2.4+ `croc [--flags] secret` under "On the other computer, run:"
/// - the same command with a trailing `(code copied to clipboard)` notice
String? extractCrocCodeFromLine(String line) {
  final cleaned = stripAnsi(line).trim();
  if (cleaned.isEmpty) return null;
  final low = cleaned.toLowerCase();
  if (low.contains('getcroc.com') ||
      low.contains('http://') ||
      low.contains('https://')) {
    return null;
  }

  final match = _codeIsExtractRe.firstMatch(cleaned);
  if (match != null) return match.group(1);
  if (_codeIsRe.hasMatch(cleaned)) {
    return normalizeCrocCode(cleaned);
  }

  var cmdLine = cleaned;
  final runIdx = low.indexOf('run:');
  if (runIdx != -1) {
    cmdLine = cleaned.substring(runIdx + 4).trim();
    if (cmdLine.isEmpty) return null;
  }

  final cmd = _crocCmdRe.firstMatch(cmdLine);
  if (cmd != null) {
    final rest = (cmd.group(1) ?? '').trim();
    if (rest.isEmpty) return null;
    final withoutNotice = rest.replaceFirst(_parenNoticeRe, '').trim();
    final tokens = withoutNotice.split(RegExp(r'\s+'));
    String? code;
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.startsWith('-')) {
        if (!token.contains('=') &&
            i + 1 < tokens.length &&
            !tokens[i + 1].startsWith('-')) {
          i++;
        }
        continue;
      }
      code = token;
    }
    if (code != null && code.isNotEmpty) return normalizeCrocCode(code);
  }
  return null;
}

const _crocStatusPrefixes = [
  'connecting',
  'securing channel',
  'receiving (',
  'sending (',
  'running:',
  'waiting',
  'receiving file (',
  'code is:',
  'looking for',
  'authenticating',
  'opening transfer',
  'on the other computer',
  'or open:',
  'retrying',
  'already up to date',
  'no files transferred',
  'uploading',
  'downloading',
  'hashing',
];

const _crocStatusSubstrings = [
  'transfer finished',
  'code is invalid',
  'on unix systems',
  'croc_secret',
  'classic mode',
  'enter receive code',
  '(y/n)',
  'room (secure channel)',
  'peer disconnected',
  'peer error',
  'refusing files',
  'unsupported pake',
  'incompatible pake',
  'waiting for sender',
  'waiting for file list',
  'waiting for receiver',
  'tailcat is unavailable',
  'transfer interruption',
  'code copied to clipboard',
  'command copied to clipboard',
];

/// True if [line] is croc CLI status output, not received text payload.
bool isCrocStatusLine(String line) {
  final s = stripAnsi(line).trim();
  if (s.isEmpty) return true;
  if (s.contains('|') && s.contains('%')) return true;
  final low = s.toLowerCase();
  for (final prefix in _crocStatusPrefixes) {
    if (low.startsWith(prefix)) return true;
  }
  if (_acceptPromptRe.hasMatch(s)) return true;
  for (final sub in _crocStatusSubstrings) {
    if (low.contains(sub)) return true;
  }
  if (low.startsWith('sending ') && !low.contains('code is:')) return true;
  if (low.startsWith('hashing ')) return true;
  if (_crocCmdRe.hasMatch(s)) return true;
  return false;
}

/// Normalize a user-entered croc code (paste quirks, spacing).
String normalizeCrocCode(String code) {
  var normalized = code.trim();
  normalized = normalized.replaceFirst(_codeIsRe, '');
  return normalized.replaceAll(' ', '-');
}

/// Return 0.0–1.0 if [line] looks like a croc progress update.
double? parseProgressFraction(String line) => parseProgressLine(line)?.fraction;

String? _joinByteCount(String? amount, String? unit) {
  if (amount == null) return null;
  final u = (unit ?? '').trim();
  if (u.isEmpty) return amount;
  return '$amount $u';
}

/// Parse a real croc progressbar line, or null.
CrocProgressInfo? parseProgressLine(String line) {
  final cleaned = stripAnsi(line).trimRight();
  final match = _progressLineRe.firstMatch(cleaned);
  if (match == null) return null;
  final value = int.tryParse(match.group(2)!);
  if (value == null || value < 0 || value > 100) return null;

  var name = match.group(1)!.trim();
  final low = cleaned.toLowerCase();
  final hashing = low.startsWith('hashing');
  name = name.replaceAll(RegExp(r'\.+$'), '').trim();

  String? speed;
  String? transferred;
  String? total;
  final speedMatch = _speedRe.firstMatch(cleaned);
  if (speedMatch != null) {
    speed = speedMatch.group(5)?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (speedMatch.group(1) != null && speedMatch.group(3) != null) {
      final totalUnit = speedMatch.group(4);
      final fromUnit = speedMatch.group(2) ?? totalUnit;
      transferred = _joinByteCount(speedMatch.group(1), fromUnit);
      total = _joinByteCount(speedMatch.group(3), totalUnit);
    }
  }

  String? eta;
  final etaMatch = _etaRe.firstMatch(cleaned);
  if (etaMatch != null) {
    final remaining = etaMatch.group(2)!.trim();
    if (remaining.isNotEmpty) eta = remaining;
  }

  int? fileIndex;
  int? fileCount;
  final countMatch = _fileCountRe.firstMatch(cleaned);
  if (countMatch != null) {
    fileIndex = int.tryParse(countMatch.group(1)!);
    fileCount = int.tryParse(countMatch.group(2)!);
  }
  final nFiles = _nFilesRe.firstMatch(name);
  if (nFiles != null) {
    fileCount ??= int.tryParse(nFiles.group(1)!);
  }

  return CrocProgressInfo(
    fraction: value / 100.0,
    fileName: name.isEmpty ? null : name,
    speed: speed,
    eta: eta,
    transferred: transferred,
    total: total,
    fileIndex: fileIndex,
    fileCount: fileCount,
    hashing: hashing,
  );
}

/// Return hashing, sending, receiving, connecting, waiting, retrying, or null.
///
/// Percent-only bars do **not** imply sending — callers should keep the
/// session role (send vs receive) when the bar has no verb.
String? detectTransferPhase(String line) {
  final low = stripAnsi(line).toLowerCase();
  if (low.contains('hashing') && line.contains('%')) return 'hashing';
  if (low.contains('retrying')) return 'retrying';
  if (low.contains('looking for') ||
      low.contains('connecting') ||
      low.contains('authenticating') ||
      low.contains('securing channel') ||
      low.contains('opening transfer')) {
    return 'connecting';
  }
  if (low.contains('waiting for') ||
      low.startsWith('code is:') ||
      low.startsWith('on the other computer')) {
    return 'waiting';
  }
  // v11.5: "Receiving (<-ip)", "Receiving (local<-peer)", "Downloading …"
  if (low.contains('receiving (') ||
      low.startsWith('receiving ') ||
      low.startsWith('downloading')) {
    return 'receiving';
  }
  // v11.5: "Sending (->ip)", "Sending (local->peer)"; keep quoted collection.
  if (low.startsWith('sending (') ||
      low.contains('sending (->') ||
      low.startsWith("sending '") ||
      low.startsWith('uploading')) {
    return 'sending';
  }
  return null;
}

/// Try to extract the current filename from a croc status or progress line.
String? extractFileName(String line) {
  final cleaned = stripAnsi(line);
  final progress = parseProgressLine(cleaned);
  if (progress?.fileName != null && progress!.fileName!.isNotEmpty) {
    return progress.fileName;
  }
  final quoted = _sendingQuotedRe.firstMatch(cleaned);
  if (quoted != null) return quoted.group(1);
  final match = _legacyFileNameRe.firstMatch(cleaned);
  return match?.group(1);
}

/// Map a croc log line to a short user-facing error, or null.
String? explainCrocFailure(String line) {
  final low = stripAnsi(line).toLowerCase();
  if (low.contains('code is invalid')) {
    return 'That transfer code is invalid or expired. Ask the sender for a new code.';
  }
  if (low.contains('could not secure channel') ||
      low.contains('pake not successful')) {
    return 'Could not establish a secure channel. Check the code and try again.';
  }
  if (low.contains('unsupported pake') ||
      low.contains('incompatible pake') ||
      low.contains('unsupported pake protocol version')) {
    return 'The other device is using an older croc (need v11). Update both sides.';
  }
  if (low.contains('peer disconnected') || low.contains('peer error')) {
    return 'The other device disconnected before the transfer finished.';
  }
  if (low.contains('refusing files')) {
    return 'The receiver declined the files.';
  }
  if (low.contains('could not connect') ||
      low.contains('i/o timeout') ||
      low.contains('connection refused') ||
      low.contains('no such host') ||
      low.contains('lookup ') ||
      (low.contains('relay') && (low.contains('error') || low.contains('fail')))) {
    return 'Could not reach the croc relay. Check the network, or set a custom relay in Preferences.';
  }
  if (low.contains('classic mode') && low.contains('croc_secret')) {
    return 'Could not start the transfer. Try again without a custom code, or use a longer phrase.';
  }
  return null;
}

/// Walk logs newest-first for a mapped error.
String? explainFromLogs(Iterable<String> lines) {
  for (final line in lines.toList().reversed) {
    final msg = explainCrocFailure(line);
    if (msg != null) return msg;
  }
  return null;
}

/// Split croc stdout on newlines and carriage returns.
///
/// Returns (remainingBuffer, [(segment, fromNewline), ...]).
(String, List<(String, bool)>) splitCrocOutput(String chunk, {String buffer = ''}) {
  var buf = buffer + chunk;
  final segments = <(String, bool)>[];
  while (true) {
    final idxN = buf.indexOf('\n');
    final idxR = buf.indexOf('\r');
    if (idxN == -1 && idxR == -1) break;
    final int idx;
    final bool fromNewline;
    if (idxN == -1) {
      idx = idxR;
      fromNewline = false;
    } else if (idxR == -1) {
      idx = idxN;
      fromNewline = true;
    } else if (idxR < idxN) {
      idx = idxR;
      fromNewline = false;
    } else {
      idx = idxN;
      fromNewline = true;
    }
    final segment = buf.substring(0, idx);
    buf = buf.substring(idx + 1);
    if (segment.isNotEmpty) {
      segments.add((segment, fromNewline));
    }
  }
  return (buf, segments);
}

const _allowedHashes = {'xxhash', 'imohash', 'md5', 'highway'};

/// Build croc global flags from typed settings.
List<String> buildGlobalArgs(GatorSettings settings) {
  final args = <String>[];
  final curve = settings.curve.trim();
  if (curve.isNotEmpty) args.addAll(['--curve', curve]);

  final relay = settings.relay.trim();
  if (relay.isNotEmpty) args.addAll(['--relay', relay]);

  final relay6 = settings.relay6.trim();
  if (relay6.isNotEmpty) args.addAll(['--relay6', relay6]);

  final relayPass = settings.pass.trim();
  if (relayPass.isNotEmpty) args.addAll(['--pass', relayPass]);

  if (settings.internalDns) args.add('--internal-dns');
  if (settings.debug) args.add('--debug');
  // GUI never answers TTY prompts; always auto-accept after the user starts Receive.
  args.add('--yes');
  if (settings.noCompress) args.add('--no-compress');
  if (settings.ask) args.add('--ask');
  if (settings.local) args.add('--local');
  if (settings.overwrite && !settings.rename) args.add('--overwrite');
  if (settings.rename) args.add('--rename');
  if (settings.testing) args.add('--testing');
  if (settings.quiet) args.add('--quiet');
  if (settings.disableClipboard) args.add('--disable-clipboard');
  if (settings.extendedClipboard) args.add('--extended-clipboard');

  final multicast = settings.multicast.trim();
  if (multicast.isNotEmpty) args.addAll(['--multicast', multicast]);

  final ip = settings.ip.trim();
  if (ip.isNotEmpty) args.addAll(['--ip', ip]);

  final socks5 = settings.socks5.trim();
  if (socks5.isNotEmpty) args.addAll(['--socks5', socks5]);

  final connect = settings.connect.trim();
  if (connect.isNotEmpty) args.addAll(['--connect', connect]);

  final throttleUpload = settings.throttleUpload.trim();
  if (throttleUpload.isNotEmpty) args.addAll(['--throttleUpload', throttleUpload]);

  final transport = settings.transport.trim();
  if (transport.isNotEmpty) args.addAll(['--transport', transport]);

  // GUI never answers croc's TTY prompts; always ignore stdin.
  args.add('--ignore-stdin');

  return args;
}

/// Build argv for a croc receive invocation (code goes in CROC_SECRET).
List<String> buildReceiveArgs(GatorSettings settings, {String? out}) {
  final args = [crocBinary, ...buildGlobalArgs(settings)];
  final dest = (out ?? '').trim();
  if (dest.isNotEmpty) args.addAll(['--out', dest]);
  return args;
}

/// Env vars croc v10+ expects for non-TTY receive.
Map<String, String> receiveEnvForCode(String code) {
  return {'CROC_SECRET': normalizeCrocCode(code)};
}

/// Env vars for a send with an optional custom code (never pass `--code` on UNIX).
Map<String, String> sendEnvForCode(String code) {
  final normalized = normalizeCrocCode(code);
  if (normalized.isEmpty) return const {};
  return {'CROC_SECRET': normalized};
}

bool isAllowedHash(String hash) =>
    hash.isEmpty || _allowedHashes.contains(hash);
