import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gator/core/constants.dart';
import 'package:gator/models/transfer_state.dart';
import 'package:gator/services/croc_parser.dart';

/// Builds send argv (ported from CrocSendTransfer._build_args).
List<String> buildSendArgs({
  required Map<String, dynamic> settings,
  required List<String> files,
  required List<String> excluded,
  required String text,
}) {
  final args = [crocBinary, ...buildGlobalArgs(settings), 'send'];
  final custom = (settings['default_code'] as String? ?? '').trim();
  if (custom.isNotEmpty) args.addAll(['--code', custom]);

  final hashAlg = (settings['hash'] as String? ?? '').trim();
  if (hashAlg.isNotEmpty) args.addAll(['--hash', hashAlg]);

  if (settings['zip_folder'] == true) args.add('--zip');
  if (text.isNotEmpty) args.addAll(['--text', text]);
  if (settings['no_local'] == true) args.add('--no-local');
  if (settings['no_multi'] == true) args.add('--no-multi');
  if (settings['git'] == true) args.add('--git');

  final port = int.tryParse(settings['port']?.toString() ?? '') ?? 0;
  if (port > 0) args.addAll(['--port', '$port']);

  final transfers = int.tryParse(settings['transfers']?.toString() ?? '') ?? 0;
  if (transfers > 0) args.addAll(['--transfers', '$transfers']);

  if (settings['qr'] == true) args.add('--qr');

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
  String _readBuf = '';
  final List<String> _lines = [];

  final _controller = StreamController<CrocEvent>.broadcast();
  Stream<CrocEvent> get events => _controller.stream;

  bool get isRunning => _process != null && !_finished;
  bool get canceled => _canceled;

  Future<void> startSend({
    required Map<String, dynamic> settings,
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
    await _spawn(args, onLine: _handleSendLine);
  }

  Future<void> startReceive({
    required Map<String, dynamic> settings,
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
    final args = buildReceiveArgs(settings)
        .map((a) => a == crocBinary ? crocPath : a)
        .toList();
    final env = Map<String, String>.from(Platform.environment)
      ..addAll(receiveEnvForCode(normalized));
    await _spawn(
      args,
      env: env,
      cwd: saveDir,
      onLine: (line) => _handleReceiveLine(line, saveDir, filesBefore),
    );
  }

  void _handleSendLine(String line) {
    final code = extractCrocCodeFromLine(line);
    if (code != null && code.isNotEmpty) {
      _emit(CrocCodeEvent(code));
    }
    _handleCommonLine(stripAnsi(line));
  }

  bool _sawFileIndicator = false;
  int _returnCode = -1;

  void _handleReceiveLine(
    String line,
    String saveDir,
    Set<String> filesBefore,
  ) {
    if (line.contains('Receiving file (')) _sawFileIndicator = true;
    _handleCommonLine(line);
    // Post-process happens in _finish for receive.
    _receiveContext = (saveDir: saveDir, filesBefore: filesBefore);
  }

  ({String saveDir, Set<String> filesBefore})? _receiveContext;

  void _handleCommonLine(String line) {
    final phase = detectTransferPhase(line);
    if (phase != null) _emit(CrocStatusEvent(phase));
    final fraction = parseProgressFraction(line);
    if (fraction != null) _emit(CrocProgressEvent(fraction));
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
      // script(1) allocates a PTY so croc flushes "Code is:" immediately.
      final script = await _resolveHostTool('script');
      final cmd = _buildShellCommand(args, env: env);
      try {
        return await Process.start(
          script,
          ['-q', '-c', cmd, '/dev/null'],
          workingDirectory: cwd,
          runInShell: false,
        );
      } on ProcessException {
        // Fallback: line-buffered pipes if script is unavailable.
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
    } catch (_) {
      return extra ?? const {};
    }
  }

  Future<void> _spawn(
    List<String> args, {
    Map<String, String>? env,
    String? cwd,
    required void Function(String line) onLine,
  }) async {
    _reset();
    final display = args.map((a) => a.contains(' ') ? '"$a"' : a).join(' ');
    final mode = Platform.isLinux ? 'script' : 'direct';
    _emit(CrocLogEvent('Running ($mode): $display'));

    _process = await _startProcess(args, env: env, cwd: cwd);
    _waitReleased = Completer<void>();

    final stdoutClosed = Completer<void>();
    final stderrClosed = Completer<void>();
    void completeOnce(Completer<void> c) {
      if (!c.isCompleted) c.complete();
    }

    _stdoutSub = _process!.stdout.transform(utf8.decoder).listen(
          (chunk) => _consumeOutput(chunk, onLine),
          onDone: () => completeOnce(stdoutClosed),
          onError: (_) => completeOnce(stdoutClosed),
        );
    // Desktop wrappers merge croc stderr; still read stderr for script/sh errors.
    _stderrSub = _process!.stderr.transform(utf8.decoder).listen(
          (chunk) => _consumeOutput(chunk, onLine),
          onDone: () => completeOnce(stderrClosed),
          onError: (_) => completeOnce(stderrClosed),
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
    final trailing = _readBuf.replaceAll(RegExp(r'[\r\n]+$'), '');
    if (trailing.isNotEmpty) onLine(trailing);
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
    final stripped = segment.trimRight();
    if (stripped.isEmpty) return;
    final isProgress = parseProgressFraction(stripped) != null;
    if (fromNewline || !isProgress) {
      _lines.add(stripped);
      _emit(CrocLogEvent(stripped));
    }
    onLine(stripped);
  }

  Future<void> _postProcessReceive(void Function(String line) onLine) async {
    final ctx = _receiveContext;
    if (ctx == null) return;

    var receivedFiles = false;
    try {
      final after = await Directory(ctx.saveDir).list().map((e) => e.path.split(Platform.pathSeparator).last).toSet();
      final newItems = after.difference(ctx.filesBefore);
      final nonText = newItems.where((n) => !n.startsWith('croc-stdin-'));
      if (nonText.isNotEmpty) receivedFiles = true;
    } catch (_) {
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
      final entries = await dir.list().toList();
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
    } catch (_) {}
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
      } catch (_) {}
    }
    proc.kill(ProcessSignal.sigkill);
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
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