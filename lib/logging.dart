import 'dart:io';

// import 'package:fimber/fimber.dart' as f;
import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:wispatisfactory/pretty_printer_custom.dart';

const logFileName = "TriOS-log.log";
String? logFolderName;
String? logFilePath;

Logger _consoleLogger = Logger();
Logger? _fileLogger;
bool _allowSentryReporting = false;
const useFimber = false;
bool didLoggingInitializeSuccessfully = false;

/// Fine to call multiple times.
configureLogging({
  bool printPlatformInfo = false,
  bool allowSentryReporting = false,
  bool consoleOnly = false,
}) async {
  _allowSentryReporting = allowSentryReporting;
  Fimber.i("Crash reporting is ${allowSentryReporting ? "enabled" : "disabled"}.");
  try {
    // WidgetsFlutterBinding.ensureInitialized();
    // logFolderName = (await configDataFolderPath).absolute.path;
    // logFilePath = p.join(logFolderName!, logFileName);
  } catch (e) {
    Fimber.e("Error getting log folder name.", ex: e);
  }

  if (!useFimber) {
    const stackTraceBeginIndex = 4;
    const methodCount = 7;
    var consolePrinter = PrettyPrinterCustom(
      stackTraceBeginIndex: 0,
      methodCount: 7,
      // Anything other than 0 halves the speed of logging.
      // errorMethodCount: 5,
      // lineLength: 50,
      colors: true,
      printEmojis: true,
      printTime: true,
      // noBoxingByDefault: true,
      stackTraceMaxLines: 20,
    );

    // Handle errors in Flutter.
    FlutterError.onError = (FlutterErrorDetails details) {
      Fimber.e("Error :  ${details.exception}", ex: details.exception, stacktrace: details.stack);
      // if (details.stack != null) {
      //   Fimber.e();
      // }
    };

    _consoleLogger = Logger(
      level: kDebugMode ? Level.debug : Level.error,
      // filter: DevelopmentFilter(), // No console logs in release mode.
      printer: consolePrinter,
      output: ConsoleOutput(),
    );

    if (consoleOnly) {
      _fileLogger = null;
    }
  }

  if (printPlatformInfo) {
    Fimber.i("Logging started.");
    Fimber.i("Platform: ${Platform.operatingSystemVersion}");
  }

  didLoggingInitializeSuccessfully = true;
}

class Fimber {
  /// Logs a verbose message.
  /// [message] is a function that returns the message to log.
  /// Verbose logging is expected to be super spammy, so don't build the message unless we're actually going to log it.
  static void v(String Function() message, {Object? ex, StackTrace? stacktrace}) {
    if (!didLoggingInitializeSuccessfully) {
      print(message());
      return;
    }

    if (useFimber) {
      // f.Fimber.v(() =>message, ex: ex, stacktrace: stacktrace);
    } else {
      final msg = message();
      _consoleLogger.t(msg, error: ex, stackTrace: stacktrace);
      _fileLogger?.t(msg, error: ex, stackTrace: stacktrace);
    }
  }

  static void i(String message, {Object? ex, StackTrace? stacktrace}) {
    if (!didLoggingInitializeSuccessfully) {
      print(message);
      return;
    }

    if (useFimber) {
      // f.Fimber.i(message, ex: ex, stacktrace: stacktrace);
    } else {
      _consoleLogger.i(message, error: ex, stackTrace: stacktrace);
      _fileLogger?.i(message, error: ex, stackTrace: stacktrace);
    }
  }

  static void d(String message, {Object? ex, StackTrace? stacktrace}) {
    if (!didLoggingInitializeSuccessfully) {
      print(message);
      return;
    }

    if (useFimber) {
      // f.Fimber.d(message, ex: ex, stacktrace: stacktrace);
    } else {
      _consoleLogger.d(message, error: ex, stackTrace: stacktrace);
      _fileLogger?.d(message, error: ex, stackTrace: stacktrace);
    }
  }

  static void w(String message, {Object? ex, StackTrace? stacktrace}) {
    if (!didLoggingInitializeSuccessfully) {
      print(message);
      return;
    }

    if (useFimber) {
      // f.Fimber.w(message, ex: ex, stacktrace: stacktrace);
    } else {
      _consoleLogger.w(message, error: ex, stackTrace: stacktrace);
      _fileLogger?.w(message, error: ex, stackTrace: stacktrace);
    }
  }

  static void e(String message, {Object? ex, StackTrace? stacktrace}) {
    if (!didLoggingInitializeSuccessfully) {
      print(message);
      return;
    }

    if (useFimber) {
      // f.Fimber.e(message, ex: ex, stacktrace: stacktrace);
    } else {
      _consoleLogger.e(message, error: ex, stackTrace: stacktrace);
      _fileLogger?.e(message, error: ex, stackTrace: stacktrace);
    }
  }
}
