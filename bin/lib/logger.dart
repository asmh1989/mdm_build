import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:stack_trace/stack_trace.dart';

/// Middleware which prints the time of the request, the elapsed time for the
/// inner handlers, the response's status code and the request URI.
///
/// If [logger] is passed, it's called for each request. The `msg` parameter is
/// a formatted string that includes the request time, duration, request method,
/// and requested path. When an exception is thrown, it also includes the
/// exception's string and stack trace; otherwise, it includes the status code.
/// The `isError` parameter indicates whether the message is caused by an error.
///
/// If [logger] is not passed, the message is just passed to [print].
Middleware logRequests({void Function(String msg, bool isError) logger}) =>
    (innerHandler) {
      logger ??= _defaultLogger;

      return (request) {
        var startTime = DateTime.now();
        var watch = Stopwatch()..start();

        return Future.sync(() => innerHandler(request)).then((response) {
          var msg = _getMessage(startTime, response.statusCode,
              request.requestedUri, request.method, watch.elapsed);

          logger(msg, false);

          return response;
        }, onError: (error, StackTrace stackTrace) {
          if (error is HijackException) throw error;

          var msg = _getErrorMessage(startTime, request.requestedUri,
              request.method, watch.elapsed, error, stackTrace);

          logger(msg, true);

          throw error;
        });
      };
    };

String _formatQuery(String query) {
  return query == '' ? '' : '?${Uri.decodeFull(query)}';
}

String _getMessage(DateTime requestTime, int statusCode, Uri requestedUri,
    String method, Duration elapsedTime) {
  return '${requestTime.toIso8601String()} '
      '${elapsedTime.toString().padLeft(15)} '
      '${method.padRight(7)} [$statusCode] ' // 7 - longest standard HTTP method
      '${requestedUri.path}${_formatQuery(requestedUri.query)}';
}

String _getErrorMessage(DateTime requestTime, Uri requestedUri, String method,
    Duration elapsedTime, Object error, StackTrace stack) {
  var chain = Chain.current();
  if (stack != null) {
    chain = Chain.forTrace(stack)
        .foldFrames((frame) => frame.isCore || frame.package == 'shelf')
        .terse;
  }

  var msg = '$requestTime\t$elapsedTime\t$method\t${requestedUri.path}'
      '${_formatQuery(requestedUri.query)}\n$error';
  if (chain == null) return msg;

  return '$msg\n$chain';
}

void _defaultLogger(String msg, bool isError) {
  if (isError) {
    print('[ERROR] $msg');
  } else {
    print(msg);
  }
}
