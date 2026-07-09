import 'dart:io';

import 'package:gator/core/constants.dart';
import 'package:gator/models/gator_settings.dart';

final _progressRe = RegExp(r'(\d{1,3})%');
final _codeIsRe = RegExp(r'^code is:\s*', caseSensitive: false);
final _codeIsExtractRe = RegExp(r'code is:\s*(\S+)', caseSensitive: false);
final _ansiRe = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]');

/// Strip terminal ANSI escape sequences from croc output.
String stripAnsi(String line) => line.replaceAll(_ansiRe, '');

/// Extract a transfer code from a croc output line, if present.
String? extractCrocCodeFromLine(String line) {
  final cleaned = stripAnsi(line).trim();
  final match = _codeIsExtractRe.firstMatch(cleaned);
  if (match != null) return match.group(1);
  if (_codeIsRe.hasMatch(cleaned)) {
    return normalizeCrocCode(cleaned);
  }
  return null;
}
final _acceptPromptRe = RegExp(
  r'^Accept .+ \(.*\)\? \(Y/n\)',
  caseSensitive: false,
);

const _crocStatusPrefixes = [
  'connecting',
  'securing channel',
  'receiving (<-',
  'receiving (->',
  'sending (<-',
  'sending (->',
  'running:',
  'waiting',
  'receiving file (',
  'code is:',
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
];

/// True if [line] is croc CLI status output, not received text payload.
bool isCrocStatusLine(String line) {
  final s = line.trim();
  if (s.isEmpty) return true;
  if (s.contains('%') || s.contains('|')) return true;
  final low = s.toLowerCase();
  for (final prefix in _crocStatusPrefixes) {
    if (low.startsWith(prefix)) return true;
  }
  if (_acceptPromptRe.hasMatch(s)) return true;
  for (final sub in _crocStatusSubstrings) {
    if (low.contains(sub)) return true;
  }
  if (low.startsWith('sending ') && !low.contains('code is:')) return true;
  return false;
}

/// Normalize a user-entered croc code (paste quirks, spacing).
String normalizeCrocCode(String code) {
  var normalized = code.trim();
  normalized = normalized.replaceFirst(_codeIsRe, '');
  return normalized.replaceAll(' ', '-');
}

/// Return 0.0–1.0 if [line] looks like a croc progress update.
double? parseProgressFraction(String line) {
  final match = _progressRe.firstMatch(line);
  if (match == null) return null;
  final value = int.parse(match.group(1)!);
  if (value >= 0 && value <= 100) return value / 100.0;
  return null;
}

/// Return hashing, sending, receiving, or null from a croc line.
String? detectTransferPhase(String line) {
  final low = line.toLowerCase();
  if (low.contains('hashing') && line.contains('%')) return 'hashing';
  if (parseProgressFraction(line) != null) {
    if (low.contains('receiving')) return 'receiving';
    return 'sending';
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
  if (settings.yes) args.add('--yes');
  if (settings.noCompress) args.add('--no-compress');
  if (settings.ask) args.add('--ask');
  if (settings.local) args.add('--local');
  if (settings.overwrite) args.add('--overwrite');
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

  if (Platform.isAndroid) {
    args.add('--ignore-stdin');
    // Android system DNS often fails croc relay lookups; bundled resolver fixes it.
    if (settings.internalDns != false) {
      args.add('--internal-dns');
    }
  }

  return args;
}

/// Build argv for a croc receive invocation (code goes in CROC_SECRET).
List<String> buildReceiveArgs(GatorSettings settings) {
  return [crocBinary, ...buildGlobalArgs(settings)];
}

/// Env vars croc v10+ expects for non-TTY receive.
Map<String, String> receiveEnvForCode(String code) {
  return {'CROC_SECRET': normalizeCrocCode(code)};
}