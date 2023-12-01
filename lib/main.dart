import 'dart:io';

import 'package:ez_api_test/utils/file_utils.dart';
import 'package:http_multi_server/http_multi_server.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'log/log_config.dart';
import 'log/logger.dart';

void main(List args) async {
  Log.init(LogConfig());
  int port = 8080;
  if (args.isNotEmpty) {
    final p = int.tryParse(args[0]);
    if (p != null) {
      port = p;
    } else {
      Log.e("Invalid port: ${args[0]}");
      Log.i("Use default port: $port");
    }
  }

  HttpServer? server;
  try {
    server = await HttpMultiServer.loopback(port);
    Log.i("Server running on http://localhost:${server.port}");
  } catch (e) {
    Log.e("Failed to start server: $e");
    exit(1);
  }

  shelf_io.serveRequests(server, (request) async {
    var path = request.requestedUri.path;
    if (path == '/') {
      path = '/index.html';
    }
    final fullPath = 'lib/web$path';
    final isExists = await FileUtils.fileExists(fullPath);
    if (isExists) {
      final mime = lookupMimeType(fullPath) ?? 'application/*';
      final content = await FileUtils.readBytes(fullPath);
      return shelf.Response.ok(content, headers: {
        'Content-Type': mime,
      });
    }
    return shelf.Response.notFound('Not Found');
  });
}
