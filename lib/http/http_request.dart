import 'dart:convert';
import 'dart:io';
import 'dart:core';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:curl_logger_dio_interceptor/curl_logger_dio_interceptor.dart';
import 'package:logging/logging.dart';

import 'http_config.dart';
import 'http_retry_interceptor.dart';

class HttpRequest {
  static final BaseOptions baseOptions = BaseOptions(
    baseUrl: config.baseUrl,
    connectTimeout: Duration(milliseconds: config.connectTimeout),
    sendTimeout: Duration(milliseconds: config.sendTimeout),
    receiveTimeout: Duration(milliseconds: config.receiveTimeout),
  );

  static Dio dio = _initDio();

  static HttpConfig config = HttpConfig();

  static Dio _initDio() {
    final io = Dio(baseOptions);
    io.interceptors.add(
      CurlLoggerDioInterceptor(printOnSuccess: true),
    );
    if (config.proxy != null) {
      //设置代理,信任证书
      final adapter = io.httpClientAdapter as IOHttpClientAdapter;
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.findProxy = (url) => config.proxy!;
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }
    io.interceptors.add(HttpRetryInterceptor(
      dio: io,
      logPrint: print,
      retries: config.retries,
      retryDelays: config.retryDelays,
    ));

    return io;
  }

  static Future<T?> request<T>(
    String url, {
    String method = 'GET',
    Map<String, dynamic>? params,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? headers,
    bool useGlobalHeaders = true,
    XCancelToken? cancelToken,
    Options? options,
    bool disableRetry = false,
    bool enableLog = true,
  }) async {
    final Map<String, dynamic> mHeaders = {};
    if (useGlobalHeaders) {
      mHeaders.addAll(config.globalHeaders());
    }
    if (headers != null) {
      mHeaders.addAll(headers);
    }

    final extra = options?.extra ?? {};
    extra['ro_disable_retry'] = disableRetry;
    extra['requst_timestamp'] = DateTime.now().toString();

    final Options mOptions;
    if (options == null) {
      mOptions = Options(
        method: method,
        headers: mHeaders,
        extra: extra,
      );
    } else {
      mOptions = options.copyWith(
        method: method,
        headers: mHeaders,
        extra: extra,
      );
    }

    try {
      final response = await dio.request<T>(
        url,
        data: data ?? params,
        options: mOptions,
        cancelToken: cancelToken,
        queryParameters: queryParameters,
      );

      if (enableLog) {
        _log(options: response.requestOptions, response: response);
      }
      return response.data;
    } on DioException catch (e) {
      if (enableLog && e.type != DioExceptionType.cancel) {
        _log(
          options: e.requestOptions,
          response: e.response,
          error: e.toString(),
        );
      }
      return Future.error(e);
    }
  }

  static Future<T?> get<T>(
    String url, {
    Map<String, dynamic>? headers,
    bool useGlobalHeaders = true,
    bool useToken = true,
    Map<String, dynamic>? queryParameters,
    XCancelToken? cancelToken,
    Options? options,
    bool disableRetry = false,
    bool enableLog = true,
  }) {
    return request<T>(
      url,
      method: 'GET',
      queryParameters: queryParameters,
      headers: headers,
      useGlobalHeaders: useGlobalHeaders,
      cancelToken: cancelToken,
      options: options,
      disableRetry: disableRetry,
      enableLog: enableLog,
    );
  }

  static Future<T?> delete<T>(
    String url, {
    bool useGlobalHeaders = true,
    bool useToken = true,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? params,
    Map<String, dynamic>? queryParameters,
    XCancelToken? cancelToken,
    Options? options,
    bool disableRetry = false,
    bool enableLog = true,
  }) {
    return request<T>(
      url,
      method: 'DELETE',
      useGlobalHeaders: useGlobalHeaders,
      headers: headers,
      params: params,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: options,
      disableRetry: disableRetry,
      enableLog: enableLog,
    );
  }

  static Future<T?> post<T>(
    String url, {
    Map<String, dynamic>? params,
    dynamic data,
    Map<String, dynamic>? headers,
    bool useGlobalHeaders = true,
    bool useToken = true,
    XCancelToken? cancelToken,
    Options? options,
    bool disableRetry = false,
    bool enableLog = true,
  }) async {
    return request<T>(
      url,
      method: 'POST',
      params: params,
      data: data,
      headers: headers,
      useGlobalHeaders: useGlobalHeaders,
      cancelToken: cancelToken,
      options: options,
      disableRetry: disableRetry,
      enableLog: enableLog,
    );
  }

  static Future<T?> put<T>(
    String url, {
    Map<String, dynamic>? params,
    dynamic data,
    Map<String, dynamic>? headers,
    bool useGlobalHeaders = true,
    bool useToken = true,
    XCancelToken? cancelToken,
    Options? options,
    bool disableRetry = false,
    bool enableLog = true,
  }) async {
    return request<T>(
      url,
      method: 'PUT',
      params: params,
      data: data,
      headers: headers,
      useGlobalHeaders: useGlobalHeaders,
      // onSendProgress: onSendProgress,
      cancelToken: cancelToken,
      options: options,
      disableRetry: disableRetry,
      enableLog: enableLog,
    );
  }

  static Future<T?> patch<T>(
    String url, {
    Map<String, dynamic>? params,
    bool useGlobalHeaders = true,
    bool useToken = true,
    Map<String, dynamic>? headers,
    dynamic data,
    XCancelToken? cancelToken,
    Options? options,
    bool disableRetry = false,
    bool enableLog = true,
  }) {
    return request<T>(
      url,
      method: 'PATCH',
      params: params,
      data: data,
      useGlobalHeaders: useGlobalHeaders,
      headers: headers,
      cancelToken: cancelToken,
      options: options,
      disableRetry: disableRetry,
      enableLog: enableLog,
    );
  }

  ///下载
  static Future<Response<Uint8List>> download(
    String path, {
    Map<String, dynamic>? queryParameters,
    XCancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    Options? options,
    bool disableRetry = true,
  }) {
    final mOptions =
        options ?? Options(receiveTimeout: const Duration(milliseconds: 15000));
    final extra = mOptions.extra ?? {};
    extra['ro_disable_retry'] = disableRetry;
    mOptions.extra = extra;
    return dio.get<Uint8List>(
      path,
      queryParameters: queryParameters,
      options: mOptions.copyWith(responseType: ResponseType.bytes),
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  ///上传
  static Future<T?> upload<T>({
    required String url,
    required FormData data,
    Map<String, dynamic>? headers,
    XCancelToken? cancelToken,
    Options? options,
  }) {
    final mOptions = options ??
        Options(
          sendTimeout: const Duration(milliseconds: 20000),
          receiveTimeout: const Duration(milliseconds: 20000),
        );

    return post<T>(
      url,
      data: data,
      cancelToken: cancelToken,
      options: mOptions,
      disableRetry: true,
    );
  }
}

Future _log({
  required RequestOptions options,
  Response? response,
  String? error,
}) async {
  final url = options.uri.toString();
  StringBuffer buffer = StringBuffer();
  buffer.writeln("${error == null ? '✅' : '❌'}${options.method}: $url");
  buffer.writeln("--------------Summary---------------");

  final requstTime = options.extra['requst_timestamp'];
  buffer.writeln('RequestTime: $requstTime');
  buffer.writeln('ResponseTime: ${DateTime.now()}');

  buffer.writeln("------------Request Headers----------");
  for (var e in options.headers.entries) {
    buffer.writeln("${e.key} : ${e.value}");
  }
  buffer.writeln("-------------Request Body------------");
  if (options.data is Map) {
    final Map body = options.data;
    buffer.writeln(jsonEncode(body));
  } else {
    buffer.writeln("${options.data}");
  }
  if (response != null) {
    buffer.writeln("------------Response------------");
    if (response.data is Map) {
      buffer.writeln(jsonEncode(response.data));
    } else {
      buffer.writeln(response.data.toString());
    }
  }
  if (error != null) {
    buffer.writeln("------------Error------------");
    buffer.writeln('❌$error');
  }
  final content = buffer.toString();
  final logger = Logger('HTTP');
  if (error == null) {
    logger.fine(content);
  } else {
    logger.severe(content);
  }
}

class XCancelToken extends CancelToken {}
