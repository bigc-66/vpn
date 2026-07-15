import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io;

import 'api_exception.dart';

class ApiClient {
  ApiClient({required String baseUrl, http.Client? httpClient})
      : _baseUrl = _normalizeBaseUrl(baseUrl),
        _client = httpClient ?? _createDefaultClient();

  String _baseUrl;
  final http.Client _client;

  /// 创建默认 HTTP 客户端，跳过 SSL 证书校验（VPN 自部署服务器常见场景）。
  static http.Client _createDefaultClient() {
    final ioc = HttpClient()
      ..badCertificateCallback = (_, __, ___) => true;
    return io.IOClient(ioc);
  }

  /// 当前 HTTP 基地址（无末尾 `/`），供路由表相对 URL 等使用。
  String get baseUrl => _baseUrl;

  /// 登录或切换服务后，将 API 请求指向用户填入的服务域名（与 fetchLiInfo(`/api/v1/li/info`) 同源）。
  void setBaseUrl(String url) {
    _baseUrl = _normalizeBaseUrl(url);
  }

  static String _normalizeBaseUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    if (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// 发送流式请求（用于带进度的下载）。
  Future<http.StreamedResponse> sendStreaming(
    http.BaseRequest request,
  ) {
    return _client.send(request);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? headers,
    int retries = 2,
  }) async {
    return _withRetry(
      () async {
        final uri = Uri.parse('$_baseUrl$path');
        final response = await _client
            .get(uri, headers: _jsonHeaders(headers))
            .timeout(const Duration(seconds: 12));
        return _parseJsonResponse(response);
      },
      retries: retries,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    int retries = 2,
  }) async {
    return _withRetry(
      () async {
        final uri = Uri.parse('$_baseUrl$path');
        final response = await _client
            .post(
              uri,
              headers: _jsonHeaders(headers),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 12));
        return _parseJsonResponse(response);
      },
      retries: retries,
    );
  }

  Map<String, String> _jsonHeaders(Map<String, String>? headers) {
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };
  }

  Future<T> _withRetry<T>(Future<T> Function() operation, {required int retries}) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await operation();
      } on ApiException catch (e) {
        if (!e.isRetryable || attempt > retries) rethrow;
      } on TimeoutException {
        if (attempt > retries) {
          throw ApiException('请求超时，请检查网络', isRetryable: true);
        }
      } on SocketException {
        if (attempt > retries) {
          throw ApiException('网络不可用，请检查网络连接', isRetryable: true);
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
    }
  }

  Map<String, dynamic> _parseJsonResponse(http.Response response) {
    final body = _decodeBody(response).trim();
    final status = response.statusCode;

    if (status >= 200 && status < 300) {
      if (body.isEmpty) return <String, dynamic>{};
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw ApiException('响应格式错误：期望JSON对象', statusCode: status);
    }

    final retryable = status >= 500 || status == 429;
    throw ApiException(
      body.isEmpty ? '服务端错误($status)' : body,
      statusCode: status,
      isRetryable: retryable,
    );
  }

  String _decodeBody(http.Response response) {
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) return '';
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        return latin1.decode(bytes);
      }
    }
  }

  void dispose() {
    _client.close();
  }
}
