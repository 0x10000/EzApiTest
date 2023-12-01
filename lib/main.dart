import 'http/http_request.dart';

import 'log/log_config.dart';
import 'log/logger.dart';

void main() async {
  Log.init(LogConfig());
  final resp = await HttpRequest.get("https://www.baidu.com");
  Log.d(resp);
}
