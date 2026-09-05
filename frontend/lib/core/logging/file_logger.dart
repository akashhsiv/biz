import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Appends every uncaught error (Flutter framework errors and async/zone errors alike) to a plain
/// .txt file on disk, timestamped — so a crash a user hits once, with no debugger attached, still
/// leaves a trail someone can open and read instead of just "it broke and we don't know why".
class FileLogger {
  static const _maxBytes = 2 * 1024 * 1024; // trim the file once it passes ~2MB
  static File? _file;

  static Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/error_log.txt');
    if (!await _file!.exists()) await _file!.create(recursive: true);
    return _file!;
  }

  static Future<String> filePath() async => (await _getFile()).path;

  static Future<void> log(String message, {StackTrace? stackTrace}) async {
    try {
      final file = await _getFile();
      final entry = StringBuffer()
        ..writeln('---- ${DateTime.now().toIso8601String()} ----')
        ..writeln(message);
      if (stackTrace != null) entry.writeln(stackTrace.toString());
      entry.writeln();

      await file.writeAsString(entry.toString(), mode: FileMode.append);

      final length = await file.length();
      if (length > _maxBytes) {
        final content = await file.readAsString();
        await file.writeAsString(content.substring(content.length - (_maxBytes ~/ 2)));
      }
    } catch (_) {
      // Logging must never itself throw and mask the original error.
    }
  }

  static Future<String> read() async {
    final file = await _getFile();
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  static Future<void> clear() async {
    final file = await _getFile();
    await file.writeAsString('');
  }

  /// Installs global handlers so every uncaught error — whether thrown during a widget build or
  /// in an unrelated async callback — gets written to the log file. Call once, wrapping runApp.
  static void install(void Function() runApp) {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      log(details.exceptionAsString(), stackTrace: details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      log('PlatformDispatcher error: $error', stackTrace: stack);
      return true;
    };

    runZonedGuarded(runApp, (error, stack) {
      log('Uncaught zone error: $error', stackTrace: stack);
    });
  }
}
