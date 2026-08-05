import 'dart:async';

import 'package:dio/dio.dart';

import 'failures.dart';

enum AppErrorKind {
  network,
  timeout,
  auth,
  notFound,
  conflict,
  validation,
  server,
  unknown,
}

class AppError {
  const AppError({
    required this.title,
    required this.message,
    this.kind = AppErrorKind.unknown,
    this.statusCode,
    this.raw,
  });

  final String title;
  final String message;
  final AppErrorKind kind;

  final int? statusCode;

  final Object? raw;

  bool get isRetryable =>
      kind == AppErrorKind.network ||
      kind == AppErrorKind.timeout ||
      kind == AppErrorKind.server;

  factory AppError.from(Object? error) {
    if (error is AppError) return error;
    if (error is DioException) return _fromDio(error);
    if (error is Failure) return _fromFailure(error);
    if (error is TimeoutException) {
      return const AppError(
        title: 'Taking too long',
        message: 'The server did not answer in time. Please try again.',
        kind: AppErrorKind.timeout,
      );
    }
    if (error is FormatException) {
      return AppError(
        title: 'Unexpected reply',
        message: 'The server sent something the app could not read.',
        kind: AppErrorKind.server,
        raw: error,
      );
    }
    return _fromText(error?.toString(), raw: error);
  }

  static String messageOf(Object? error) => AppError.from(error).message;

  @override
  String toString() => '$title: $message';

  static AppError _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppError(
          title: 'Taking too long',
          message:
              'The server is slow to respond right now. Please try again in a moment.',
          kind: AppErrorKind.timeout,
          raw: e,
        );

      case DioExceptionType.connectionError:
        return AppError(
          title: 'No connection',
          message:
              'Could not reach the server. Check your internet and try again.',
          kind: AppErrorKind.network,
          raw: e,
        );

      case DioExceptionType.badCertificate:
        return AppError(
          title: 'Connection not secure',
          message: 'The secure connection to the server could not be verified.',
          kind: AppErrorKind.network,
          raw: e,
        );

      case DioExceptionType.cancel:
        return AppError(
          title: 'Cancelled',
          message: 'The request was cancelled.',
          kind: AppErrorKind.unknown,
          raw: e,
        );

      case DioExceptionType.badResponse:
        return _fromResponse(e.response, raw: e);

      case DioExceptionType.unknown:
        
        final inner = '${e.error ?? ''} ${e.message ?? ''}'.toLowerCase();
        if (inner.contains('socketexception') ||
            inner.contains('failed host lookup') ||
            inner.contains('network is unreachable') ||
            inner.contains('connection refused') ||
            inner.contains('connection closed') ||
            inner.contains('clientexception')) {
          return AppError(
            title: 'No connection',
            message:
                'Could not reach the server. Check your internet and try again.',
            kind: AppErrorKind.network,
            raw: e,
          );
        }
        return _fromText(e.message, raw: e);
    }
  }

  static AppError _fromResponse(Response<dynamic>? response, {Object? raw}) {
    final status = response?.statusCode;
    final fromServer = _humanize(_serverMessage(response?.data));

    if (status == null) {
      return AppError(
        title: 'Something went wrong',
        message: fromServer ?? 'Please try again in a moment.',
        kind: AppErrorKind.server,
        raw: raw,
      );
    }

    final (title, fallback, kind) = _forStatus(status);
    return AppError(
      title: title,
      message: fromServer ?? fallback,
      kind: kind,
      statusCode: status,
      raw: raw,
    );
  }

  static (String, String, AppErrorKind) _forStatus(int status) {
    switch (status) {
      case 400:
      case 422:
        return (
          'Check your details',
          'Some of the information sent was not accepted.',
          AppErrorKind.validation,
        );
      case 401:
        return (
          'Session expired',
          'Please sign in again to continue.',
          AppErrorKind.auth,
        );
      case 403:
        return (
          'Not allowed',
          'You do not have permission to do that.',
          AppErrorKind.auth,
        );
      case 404:
        return (
          'Not found',
          'That item no longer exists.',
          AppErrorKind.notFound,
        );
      case 409:
        return (
          'Already exists',
          'That conflicts with something already saved.',
          AppErrorKind.conflict,
        );
      case 413:
        return (
          'File too large',
          'Pick a smaller photo and try again.',
          AppErrorKind.validation,
        );
      case 429:
        return (
          'Slow down',
          'Too many requests. Please wait a moment and try again.',
          AppErrorKind.server,
        );
      case 502:
      case 503:
      case 504:
        return (
          'Server unavailable',
          'The server is waking up or busy. Please try again shortly.',
          AppErrorKind.server,
        );
      default:
        if (status >= 500) {
          return (
            'Server problem',
            'Something went wrong on our side. Please try again.',
            AppErrorKind.server,
          );
        }
        return (
          'Request failed',
          'The server rejected the request.',
          AppErrorKind.unknown,
        );
    }
  }

  static AppError _fromFailure(Failure failure) {
    final message = _humanize(failure.message);
    final kind = switch (failure) {
      AuthFailure() => AppErrorKind.auth,
      ValidationFailure() => AppErrorKind.validation,
      ServerFailure() => AppErrorKind.server,
      _ => AppErrorKind.unknown,
    };
    final title = switch (kind) {
      AppErrorKind.auth => 'Sign in problem',
      AppErrorKind.validation => 'Check your details',
      AppErrorKind.server => 'Server problem',
      _ => 'Something went wrong',
    };
    return AppError(
      title: title,
      message: message ?? 'Please try again in a moment.',
      kind: kind,
      raw: failure,
    );
  }

  static AppError _fromText(String? text, {Object? raw}) {
    
    final status = RegExp(r'status(?: error)?\s*(?:\[|code of )(\d{3})')
        .firstMatch(text?.toLowerCase() ?? '')
        ?.group(1);
    if (status != null) {
      final (title, fallback, kind) = _forStatus(int.parse(status));
      return AppError(
        title: title,
        message: fallback,
        kind: kind,
        statusCode: int.parse(status),
        raw: raw,
      );
    }

    final message = _humanize(text);
    if (message == null) {
      return AppError(
        title: 'Something went wrong',
        message: 'Please try again in a moment.',
        raw: raw,
      );
    }

    final lower = message.toLowerCase();
    if (lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('host lookup') ||
        lower.contains('offline')) {
      return AppError(
        title: 'No connection',
        message: 'Could not reach the server. Check your internet and try again.',
        kind: AppErrorKind.network,
        raw: raw,
      );
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return AppError(
        title: 'Taking too long',
        message: 'The server did not answer in time. Please try again.',
        kind: AppErrorKind.timeout,
        raw: raw,
      );
    }
    if (lower.contains('no token') ||
        lower.contains('not signed in') ||
        lower.contains('session expired') ||
        lower.contains('unauthorized')) {
      return AppError(
        title: 'Session expired',
        message: 'Please sign in again to continue.',
        kind: AppErrorKind.auth,
        raw: raw,
      );
    }
    return AppError(
      title: 'Something went wrong',
      message: message,
      raw: raw,
    );
  }

  static String? _serverMessage(dynamic data) {
    if (data == null) return null;

    if (data is String) {
      final text = data.trim();
      if (text.isEmpty || text.startsWith('<')) return null; 
      return text;
    }

    if (data is Map) {
      for (final key in const ['message', 'error', 'errorMessage', 'detail']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
        
        if (value is Map && value['message'] is String) {
          return (value['message'] as String).trim();
        }
      }
      
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        return errors.entries
            .map((e) => '${e.key} ${e.value}')
            .join(', ');
      }
      if (data['data'] is Map) return _serverMessage(data['data']);
    }

    return null;
  }

  static String? _humanize(String? input) {
    if (input == null) return null;

    var text = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;

    final wrappers = RegExp(
      r'^(Exception|_Exception|Error|StateError|ArgumentError|HttpException|DioException(\s*\[[^\]]*\])?)\s*:\s*',
      caseSensitive: false,
    );
    final prefixes = RegExp(
      r'^(sign in|sign up|sign out|log in|profile update|password reset|avatar upload|failed to get current user|change password)\s+failed\s*:\s*',
      caseSensitive: false,
    );
    for (var i = 0; i < 5; i++) {
      final before = text;
      text = text.replaceFirst(wrappers, '').replaceFirst(prefixes, '').trim();
      if (text == before) break;
    }

    text = text
        .replaceFirst(RegExp(r'^something went wrong\s*:\s*', caseSensitive: false), '')
        .trim();

    if (text.isEmpty) return null;

    final database = _databaseMessage(text);
    if (database != null) return database;

    if (_looksTechnical(text)) return null;

    if (text.length > 160) {
      final cut = text.lastIndexOf(' ', 157);
      text = '${text.substring(0, cut > 40 ? cut : 157).trimRight()}…';
    }

    text = text[0].toUpperCase() + text.substring(1);
    if (!RegExp(r'[.!?…]$').hasMatch(text)) text = '$text.';
    return text;
  }

  static String? _databaseMessage(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('duplicate key') || lower.contains('unique constraint')) {
      return 'That already exists. Try a different value.';
    }
    if (lower.contains('foreign key constraint')) {
      return 'This is linked to something else, so it cannot be changed right now.';
    }
    if (lower.contains('not-null constraint') ||
        lower.contains('null value in column')) {
      return 'A required field was left empty.';
    }
    if (lower.contains('value too long')) {
      return 'One of the fields is too long.';
    }
    if (lower.contains('invalid input syntax') ||
        lower.contains('datatype mismatch') ||
        lower.contains('could not be converted')) {
      return 'Some of the information was not in the expected format.';
    }
    if (lower.contains('deadlock') ||
        lower.contains('connection is closed') ||
        lower.contains('connection pool') ||
        lower.contains('too many connections')) {
      return 'The database is busy. Please try again in a moment.';
    }
    
    if (lower.contains('sqlexception') ||
        lower.contains('psqlexception') ||
        lower.contains('jdbc') ||
        lower.contains('hibernate') ||
        lower.contains('constraintviolation') ||
        lower.contains('dataintegrityviolation')) {
      return 'The server had a database problem. Please try again.';
    }
    return null;
  }

  static bool _looksTechnical(String text) {
    if (text.length > 400) return true;
    return RegExp(
      r'(Exception\b|Throwable|StackTrace|#\d+\s+\w+|\bat [\w$.]+\(|'
      r'\b(java|javax|jakarta|org\.springframework|com\.ctrc|kotlin|dart:)[\w.]*\.|'
      r'Instance of |<!DOCTYPE|<html)',
      caseSensitive: false,
    ).hasMatch(text);
  }
}
