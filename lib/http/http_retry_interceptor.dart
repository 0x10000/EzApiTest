import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

class HttpRetryInterceptor extends RetryInterceptor {
  HttpRetryInterceptor({
    required super.dio,
    super.logPrint = print,
    super.retries = 3,
    super.retryDelays = const [Duration.zero],
  }) : super(retryEvaluator: HttpRetryEvaluator().evaluate);
}

class HttpRetryEvaluator extends DefaultRetryEvaluator {
  HttpRetryEvaluator() : super(defaultRetryableStatuses);

  @override
  FutureOr<bool> evaluate(DioException error, int attempt) {
    bool shouldRetry;
    if (error.type == DioExceptionType.badResponse) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        shouldRetry = isRetryable(statusCode);
      } else {
        shouldRetry = true;
      }
    } else {
      shouldRetry = error.type != DioExceptionType.cancel &&
          error.type != DioExceptionType.receiveTimeout &&
          error.error is! FormatException;
    }
    currentAttempt = attempt;
    return shouldRetry;
  }
}
