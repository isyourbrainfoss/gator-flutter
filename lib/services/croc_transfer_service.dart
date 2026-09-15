import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gator/core/constants.dart';
import 'package:gator/core/logger.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/services/croc_parser.dart';

/// Builds send argv (ported from CrocSendTransfer._build_args).
///
/// Custom codes are passed via [sendEnvForCode] (`CROC_SECRET`), never `--code`
/// — on UNIX/Android croc treats `--code` without the env var as classic-mode
/// leakage and exits 0 after printing help.
List<String> buildSendArgs({
  required GatorSettings settings,
  required List<String> files,
  required List<String> excluded,
  required String text,
}) {
  final args = [crocBinary, ...buildGlobalArgs(settings), 'send'];

  final hashAlg = settings.hash.trim();
  if (hashAlg.isNotEmpty) args.addAll(['--hash', hashAlg]);

  if (settings.zipFolder) args.add('--zip');
  if (text.isNotEmpty) args.addAll(['--text', text]);
  if (settings.noLocal) args.add('--no-local');
  if (settings.noMulti) args.add('--no-multi');
  if (settings.git) args.add('--git');

  if (settings.port > 0) args.addAll(['--port', '${settings.port}']);

  if (settings.transfers > 0) args.addAll(['--transfers', '${settings.transfers}']);

  if (settings.qr) args.add('--qr');

  if (excluded.isNotEmpty) {
    final names = excluded.map((p) => p.split(Platform.pathSeparator).last);
    args.addAll(['--exclude', names.join(',')]);
  }
  if (files.isNotEmpty) args.addAll(files);
  return args;
}

/// Manages croc send/receive subprocesses and streams parsed events.
class CrocTransferService {
  CrocTransferService({required this.crocPath});

  final String crocPath;
  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  Completer<void>? _waitReleased;
  bool _canceled = false;
  bool _finished = false;
  bool _receiving = false;
  String _readBuf = '';
  final List<String> _lines = [];
  double? _lastProgress;

  final _controller = StreamController<CrocEvent>.broadcast();
  Stream<CrocEvent> get events => _controller.stream;

  bool get isRunning => _process != null && !_finished;
  bool get canceled => _canceled;

  Future<void> startSend({
    required GatorSettings settings,
    required List<String> files,
    required List<String> excluded,
    required String text,
  }) async {
    final args = buildSendArgs(
      settings: settings,
      files: files,
      excluded: excluded,
      text: text,
    ).map((a) => a == crocBinary ? crocPath : a).toList();
    final env = sendEnvForCode(settings.defaultCode);
    await _spawn(
      args,
      env: env.isEmpty ? null : env,
      onLine: _handleSendLine,
    );
  }

  Future<void> startReceive({
    required GatorSettings settings,
    required String code,
    required String saveDir,
    required Set<String> filesBefore,
  }) async {
    final normalized = normalizeCrocCode(code);
    if (normalized.isEmpty) {
      _emit(const CrocLogEvent('Error: no transfer code'));
      _finish(1);
      return;
    }
    final args = buildReceiveArgs(settings, out: saveDir)
        .map((a) => a == crocBinary ? crocPath : a)
        .toList();
    final env = Map<String, String>.from(Platform.environment)
      ..addAll(receiveEnvForCode(normalized));
    await _spawn(
      args,
      env: env,
      cwd: saveDir,
      receiving: true,
      onLine: (line) => _handleReceiveLine(line, saveDir, filesBefore),
    );
  }

  void _handleSendLine(String line) {
    final code = extractCrocCodeFromLine(line);
    if (code != null && code.isNotEmpty) {
      _emit(CrocCodeEvent(code));
    }
    _handleCommonLine(line);
  }

  bool _sawFileIndicator = false;
  int _returnCode = -1;

  void _handleReceiveLine(
    String line,
    String saveDir,
    Set<String> filesBefore,
  ) {
    final cleaned = stripAnsi(line);
    if (cleaned.contains('Receiving file (') ||
        cleaned.contains('Receiving (') ||
        parseProgressLine(cleaned) != null) {
      _sawFileIndicator = true;
    }
    _handleCommonLine(cleaned);
    _receiveContext = (saveDir: saveDir, filesBefore: filesBefore);
  }

  ({String saveDir, Set<String> filesBefore})? _receiveContext;

  void _handleCommonLine(String line) {
    final cleaned = stripAnsi(line);
    final info = parseProgressLine(cleaned);
    if (info != null) {
      if (_lastProgress != info.fraction) {
        _lastProgress = info.fraction;
        _emit(info.toEvent());
      }
      if (info.hashing) {
        _emit(const CrocStatusEvent('hashing'));
      } else if (_receiving) {
        _emit(const CrocStatusEvent('receiving'));
      } else {
        _emit(const CrocStatusEvent('sending'));
      }
      return;
    }
    final phase = detectTransferPhase(cleaned);
    if (phase != null) _emit(CrocStatusEvent(phase));
  }

  static String _shellQuote(String arg) =>
      "'${arg.replaceAll("'", r"'\''")}'";

  /// GUI apps often ship with a minimal PATH — resolve host tools explicitly.
  static Future<String> _resolveHostTool(String name) async {
    for (final dir in (Platform.environment['PATH'] ?? '').split(':')) {
      if (dir.isEmpty) continue;
      final candidate = '$dir/$name';
      if (await File(candidate).exists()) return candidate;
    }
    for (final path in ['/usr/bin/$name', '/usr/local/bin/$name']) {
      if (await File(path).exists()) return path;
    }
    return name;
  }

  String _buildShellCommand(
    List<String> args, {
    Map<String, String>? env,
  }) {
    final parts = <String>[];
    if (env != null) {
      for (final entry in env.entries) {
        parts.add('${_shellQuote(entry.key)}=${_shellQuote(entry.value)}');
      }
    }
    parts.addAll(args.map(_shellQuote));
    return parts.join(' ');
  }

  Future<Process> _startProcess(
    List<String> args, {
    Map<String, String>? env,
    String? cwd,
  }) async {
    if (Platform.isLinux) {
      // script(1) allocates a PTY so croc flushes the receive code immediately.
      // setsid so cancel can kill the whole process group (script → sh → croc).
      final script = await _resolveHostTool('script');
      final setsid = await _resolveHostTool('setsid');
      final cmd = _buildShellCommand(args, env: env);
      try {
        return await Process.start(
          setsid,
          [script, '-q', '-c', cmd, '/dev/null'],
          workingDirectory: cwd,
          runInShell: false,
        );
      } on ProcessException {
        try {
          return await Process.start(
            script,
            ['-q', '-c', cmd, '/dev/null'],
            workingDirectory: cwd,
            runInShell: false,
          );
        } on ProcessException {
          final stdbuf = await _resolveHostTool('stdbuf');
          final merged = '$cmd 2>&1';
          if (await File(stdbuf).exists()) {
            return Process.start(
              stdbuf,
              ['-oL', '-eL', 'sh', '-c', merged],
              workingDirectory: cwd,
              runInShell: false,
            );
          }
          return Process.start(
            await _resolveHostTool('sh'),
            ['-c', merged],
            workingDirectory: cwd,
            runInShell: false,
          );
        }
      }
    }
    if (Platform.isMacOS) {
      final cmd = _buildShellCommand(args, env: env);
      return Process.start(
        await _resolveHostTool('sh'),
        ['-c', '$cmd 2>&1'],
        workingDirectory: cwd,
        runInShell: false,
      );
    }
    if (Platform.isAndroid) {
      final crocEnv = await _androidCrocEnvironment(env);
      return Process.start(
        args.first,
        args.sublist(1),
        environment: crocEnv,
        workingDirectory: cwd,
        runInShell: false,
      );
    }
    return Process.start(
      args.first,
      args.sublist(1),
      environment: env,
      workingDirectory: cwd,
      runInShell: false,
    );
  }

  static Future<Map<String, String>> _androidCrocEnvironment(
    Map<String, String>? extra,
  ) async {
    const channel = MethodChannel('org.gator.gator/croc');
    try {
      final base = await channel.invokeMethod<Map<Object?, Object?>>('getCrocEnv');
      final merged = <String, String>{};
      if (base != null) {
        for (final entry in base.entries) {
          if (entry.key is String && entry.value is String) {
            merged[entry.key as String] = entry.value as String;
          }
        }
      }
      if (extra != null) merged.addAll(extra);
      return merged;
    } catch (e, st) {
      GatorLog.e('CrocTransferService', 'Failed to get Android croc env', e, st);
      return extra ?? const {};
    }
  }

  Future<void> _spawn(
    List<String> args, {
    Map<String, String>? env,
    String? cwd,
    bool receiving = false,
    required void Function(String line) onLine,
  }) async {
    if (_process != null) {
      await _tearDownProcess();
    }
    _reset();
    _receiving = receiving;
    final display = args.map((a) => a.contains(' ') ? '"$a"' : a).join(' ');
    final mode = Platform.isLinux ? 'script' : 'direct';
    _emit(CrocLogEvent('Running ($mode): $display'));

    _process = await _startProcess(args, env: env, cwd: cwd);
    try {
      await _process!.stdin.close();
    } catch (e) {
      GatorLog.d('CrocTransferService', 'stdin close: $e');
    }
    _waitReleased = Completer<void>();

    final stdoutClosed = Completer<void>();
    final stderrClosed = Completer<void>();
    void completeOnce(Completer<void> c) {
      if (!c.isCompleted) c.complete();
    }

    _stdoutSub = _process!.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          (chunk) => _consumeOutput(chunk, onLine),
          onDone: () => completeOnce(stdoutClosed),
          onError: (e, st) {
            GatorLog.e('CrocTransferService', 'stdout error', e, st);
            _emit(CrocLogEvent('croc output error: $e'));
            completeOnce(stdoutClosed);
          },
        );
    _stderrSub = _process!.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          (chunk) => _consumeOutput(chunk, onLine),
          onDone: () => completeOnce(stderrClosed),
          onError: (e, st) {
            GatorLog.e('CrocTransferService', 'stderr error', e, st);
            completeOnce(stderrClosed);
          },
        );

    await Future.any([
      Future.wait([
        stdoutClosed.future,
        stderrClosed.future,
        _process!.exitCode.then((code) => _returnCode = code),
      ]),
      _waitReleased!.future,
    ]);
    _flushBuffer(onLine);
    await _postProcessReceive(onLine);
    if (!_finished) _finish(_returnCode);
  }

  void _consumeOutput(String chunk, void Function(String line) onLine) {
    final (buf, segments) = splitCrocOutput(chunk, buffer: _readBuf);
    _readBuf = buf;
    for (final (segment, fromNewline) in segments) {
      _emitSegment(segment, fromNewline: fromNewline, onLine: onLine);
    }
    // Probe trailing buffer for a receive code only — do not emit progress
    // twice from an incomplete \r line.
    final trailing = _readBuf.replaceAll(RegExp(r'[\r\n]+$'), '');
    if (trailing.isNotEmpty) {
      final code = extractCrocCodeFromLine(trailing);
      if (code != null && code.isNotEmpty) {
        _emit(CrocCodeEvent(code));
      }
    }
  }

  void _flushBuffer(void Function(String line) onLine) {
    final trailing = _readBuf.trim();
    if (trailing.isNotEmpty) {
      _emitSegment(trailing, fromNewline: true, onLine: onLine);
    }
    _readBuf = '';
  }

  void _emitSegment(
    String segment, {
    required bool fromNewline,
    required void Function(String line) onLine,
  }) {
    final stripped = stripAnsi(segment).trimRight();
    if (stripped.isEmpty) return;
    final isProgress = parseProgressLine(stripped) != null;
    if (fromNewline || !isProgress) {
      _lines.add(stripped);
      if (_lines.length > kMaxLogLines) {
        _lines.removeRange(0, _lines.length - kMaxLogLines);
      }
      _emit(CrocLogEvent(stripped));
    }
    onLine(stripped);
  }

  Future<void> _postProcessReceive(void Function(String line) onLine) async {
    final ctx = _receiveContext;
    if (ctx == null) return;

    var receivedFiles = false;
    try {
      final after = await Directory(ctx.saveDir)
          .list(followLinks: false)
          .map((e) => e.path.split(Platform.pathSeparator).last)
          .toSet();
      final newItems = after.difference(ctx.filesBefore);
      final nonText = newItems.where((n) => !n.startsWith('croc-stdin-'));
      if (nonText.isNotEmpty) receivedFiles = true;
    } catch (e, st) {
      GatorLog.e('CrocTransferService', 'Post-process dir snapshot failed', e, st);
      receivedFiles = _sawFileIndicator;
    }

    final textLines = _lines.where((ln) => !isCrocStatusLine(ln)).toList();
    var textDelivered = false;

    if (textLines.isNotEmpty && !receivedFiles && !_sawFileIndicator) {
      final text = textLines.join('\n').trim();
      if (text.isNotEmpty) {
        _emit(CrocTextReceivedEvent(text));
        textDelivered = true;
      }
    }

    if (!textDelivered && _returnCode == 0 && !_canceled) {
      textDelivered = await _checkTempTextFile(ctx.saveDir);
    }

    if (_returnCode == 0 && !_canceled && receivedFiles && !textDelivered) {
      _emit(const CrocTransferCompleteEvent());
    }
  }

  Future<bool> _checkTempTextFile(String saveDir) async {
    try {
      final dir = Directory(saveDir);
      final entries = await dir.list(followLinks: false).toList();
      for (final entry in entries) {
        if (entry is File) {
          final name = entry.path.split(Platform.pathSeparator).last;
          if (name.startsWith('croc-stdin-')) {
            final text = (await entry.readAsString()).trim();
            await entry.delete();
            if (text.isNotEmpty) {
              _emit(CrocTextReceivedEvent(text));
              return true;
            }
          }
        }
      }
    } catch (e, st) {
      GatorLog.e('CrocTransferService', 'Temp text file check failed', e, st);
    }
    return false;
  }

  Future<void> cancel() async {
    if (_canceled || _finished) return;
    _canceled = true;
    await _tearDownProcess();
    if (_waitReleased != null && !_waitReleased!.isCompleted) {
      _waitReleased!.complete();
    }
    _finish(-1);
  }

  /// Kill wrapper + child croc; cancel stream subs so [_spawn] can exit.
  Future<void> _tearDownProcess() async {
    final proc = _process;
    if (proc == null) return;
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        await Process.run(
          await _resolveHostTool('pkill'),
          ['-KILL', '-P', '${proc.pid}'],
        );
      } catch (e) {
        GatorLog.w('CrocTransferService', 'pkill failed during teardown: $e');
      }
      try {
        Process.killPid(-proc.pid, ProcessSignal.sigkill);
      } catch (e) {
        GatorLog.d('CrocTransferService', 'process-group kill: $e');
      }
    }
    proc.kill(ProcessSignal.sigkill);
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _process = null;
  }

  void _reset() {
    _canceled = false;
    _finished = false;
    _readBuf = '';
    _lines.clear();
    _sawFileIndicator = false;
    _returnCode = -1;
    _receiveContext = null;
    _waitReleased = null;
    _stdoutSub = null;
    _stderrSub = null;
    _lastProgress = null;
    _receiving = false;
  }

  void _emit(CrocEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void _finish(int exitCode) {
    if (_finished) return;
    _finished = true;
    _process = null;
    _emit(CrocFinishedEvent(exitCode: exitCode));
  }

  Future<void> dispose() async {
    await cancel();
    await _controller.close();
  }
}
