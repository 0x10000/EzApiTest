import 'dart:io';

class FileUtils {
  ///读取文件内容
  static Future readBytes(String filePath) async {
    final file = File(filePath);
    return await file.readAsBytes();
  }

  ///读取文件内容
  static Future<String> readString(String filePath) async {
    final file = File(filePath);
    return await file.readAsString();
  }

  ///判断文件是否存在
  static Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  ///写文件
  static Future writeToFile({
    required String filePath,
    required String content,
    bool append = true,
  }) async {
    final file = File(filePath);
    final exists = await file.exists();
    if (!exists) {
      await file.create(recursive: true);
    }
    final mode = append ? FileMode.append : FileMode.write;
    await file.writeAsString(content, mode: mode);
  }

  ///删除文件
  static Future removeFiles(
    String directoryPath,
    bool Function(FileSystemEntity) test,
  ) async {
    final directory = Directory(directoryPath);
    final files = directory.listSync();
    files.where(test).forEach((file) {
      file.deleteSync();
    });
  }

  /// 列出目录下的文件名
  static Future<List<String>> listFiles(
    String directoryPath,
  ) async {
    final directory = Directory(directoryPath);
    final files = directory.listSync();
    return files.map((e) => e.uri.pathSegments.last).toList();
  }
}
