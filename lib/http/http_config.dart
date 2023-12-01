class HttpConfig {
  String baseUrl = '';

  /// 连接服务器超时时间，单位是毫秒.
  int connectTimeout = 10000;

  /// 发送超时
  int sendTimeout = 5000;

  /// 接收超时
  int receiveTimeout = 30000;

  /// 代理
  String? proxy;

  /// 全局Header头
  Map<String, dynamic> Function() globalHeaders = () => {};

  /// 重试次数
  int retries = 2;

  /// 重试间隔
  List<Duration> retryDelays = [Duration.zero];
}
