import 'package:dio/dio.dart';

class Api {
  Api._();
  static final Api instance = Api._();

  final Dio dio = Dio(
    BaseOptions(
      baseUrl:
          'https://student-details-worker.student-project-2026.workers.dev',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  String? token;
  String? username;

  /// Normal College Management login:
  /// - token identifies the role
  /// - username identifies the individual college account
  void setIdentity(String valueUsername, String valueToken) {
    username = valueUsername.trim();
    token = valueToken.trim();
  }

  /// Kept for compatibility with existing code that only sets a token.
  void setToken(String value) {
    token = value.trim();
  }

  void clearToken() {
    token = null;
    username = null;
  }

  Future<Response<dynamic>> get(
    String path, [
    Map<String, dynamic>? query,
  ]) =>
      dio.get(
        path,
        queryParameters: query,
        options: _options(),
      );

  Future<Response<dynamic>> post(String path, dynamic data) =>
      dio.post(path, data: data, options: _options());

  Future<Response<dynamic>> put(String path, dynamic data) =>
      dio.put(path, data: data, options: _options());

  Future<Response<dynamic>> delete(String path) =>
      dio.delete(path, options: _options());

  Options _options() {
    final headers = <String, dynamic>{};

    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (username != null && username!.isNotEmpty) {
      headers['X-College-Username'] = username;
    }

    return Options(headers: headers.isEmpty ? null : headers);
  }
}
