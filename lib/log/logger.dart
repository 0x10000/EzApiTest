import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'dart:developer' as developer;

import '../utils/file_utils.dart';
import 'log_config.dart';

abstract class LogListener {
  void onRecord(LogRecord record);
}

class Log {
  static final Logger _defalutLogger = Logger('Log');
  static final List<String> _logBuffer = [];
  static String? _logDir;
  static SendPort? _sendPort;
  static int _maxKeepDays = 3;

  /// [maxKeepDays] 日志保留天数
  /// [logDir] 日志文件存储目录
  /// [listener] 日志监听器
  static void init(LogConfig config) {
    _maxKeepDays = config.maxKeepDays;
    _logDir = config.logDir;
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      config.listener?.onRecord(record);
      var start = '\x1b[32m';
      const end = '\x1b[0m';

      switch (record.level.name) {
        case 'INFO':
          start = '\x1b[90m';
          break;
        case 'WARNING':
          start = '\x1b[93m';
          break;
        case 'SEVERE':
          start = '\x1b[31m';
          break;
        case 'SHOUT':
          start = '\x1b[95m';
          break;
      }

      final message = '$start[${record.time}][${record.level.name}]'
          '\n------------------------------------'
          '\n${record.message}$end';
      // developer.log(
      //   message,
      //   name: record.loggerName,
      //   level: record.level.value,
      //   time: record.time,
      // );
      print(message);

      //写入本地日志文件
      final log = '\n[${record.time}][${record.level.name}]'
          '\n------------------------------------'
          '\n${record.message}';
      _startWriteIsolate(log);
    });
  }

  static Future _startWriteIsolate(String content) async {
    if (_logDir == null) {
      _logDir = 'logs';
    }

    if (_sendPort == null) {
      final ReceivePort receivePort = ReceivePort();
      final isolatePort = Completer<SendPort>();
      final subscription = receivePort.listen((message) {
        if (message is SendPort) {
          isolatePort.complete(message);
        }
      });
      await Isolate.spawn(_entryPoint, [
        receivePort.sendPort,
        _logDir,
        _maxKeepDays,
      ]);
      _sendPort = await isolatePort.future;
      _sendPort?.send(content);
      subscription.cancel();
    } else {
      _sendPort?.send(content);
    }
  }

  static void _entryPoint(List args) {
    final SendPort sendPort = args[0];
    final String logDir = args[1];
    final int maxKeepDays = args[2];
    final ReceivePort receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    receivePort.listen((message) {
      _writeToFile(logDir, message, maxKeepDays);
    });
  }

  ///写入日志文件，所有参数需要通过sendPort发送过来，不可使用外部变量(会被复制一份，导致变更无法生效)
  static Future _writeToFile(
      String logDir, String content, int maxKeepDays) async {
    //采用队列方式写入，防止并行写入导致错乱
    if (_logBuffer.isNotEmpty) {
      _logBuffer.add(content);
      return;
    }
    _logBuffer.add(content);
    while (_logBuffer.isNotEmpty) {
      final first = _logBuffer.first;
      final date = _formatDate(DateTime.now());
      final fileName = '$date.log';
      final filePath = '$logDir/$fileName';
      await FileUtils.writeToFile(filePath: filePath, content: first);
      _logBuffer.removeAt(0);
    }
    _removeExpiredFiles(logDir, maxKeepDays);
  }

  //删除最大保留(活跃)天数以外的日志文件
  static Future _removeExpiredFiles(String logDir, int maxKeepDays) async {
    final files = await FileUtils.listFiles(logDir);
    if (files.length <= maxKeepDays) {
      return;
    }
    final List<String> keepFiles = [];
    final Map<int, String> filesMap = {};
    final List<int> times = [];
    for (final file in files) {
      final date = file.split('.').first;
      final time = DateTime.tryParse(date);
      if (time != null) {
        times.add(time.millisecondsSinceEpoch);
        filesMap[time.millisecondsSinceEpoch] = file;
      }
    }

    times.sort();
    while (keepFiles.length < maxKeepDays && times.isNotEmpty) {
      final time = times.last;
      keepFiles.add(filesMap[time]!);
      times.removeLast();
    }

    await FileUtils.removeFiles(logDir, (file) {
      final fileName = file.uri.pathSegments.last;
      return !keepFiles.contains(fileName);
    });
  }

  static String _formatDate(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}'
        '-${time.day.toString().padLeft(2, '0')}';
  }

  ///verbose
  static void v(Object? msg, [Object? error, StackTrace? stackTrace]) {
    _defalutLogger.finest(msg, error, stackTrace);
  }

  ///info
  static void i(Object? msg, [Object? error, StackTrace? stackTrace]) {
    _defalutLogger.info(msg, error, stackTrace);
  }

  ///debug
  static void d(Object? msg, [Object? error, StackTrace? stackTrace]) {
    _defalutLogger.warning(msg, error, stackTrace);
  }

  ///error
  static void e(Object? msg, [Object? error, StackTrace? stackTrace]) {
    _defalutLogger.severe(msg, error, stackTrace);
  }
}
