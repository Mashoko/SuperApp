import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'kyc_models.dart';

const _fallbackMessage = 'Something went wrong. Please try again.';
const _offlineMessage = 'No connection. Check your internet and try again.';

class KycApiException implements Exception {
  KycApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'KycApiException($statusCode)';
}

class KycValidationException extends KycApiException {
  KycValidationException(this.errors, String message) : super(400, message);

  final KycFieldErrors errors;
}

typedef KycNotificationPage = ({
  List<KycNotification> items,
  int unread,
  int totalPages,
});

class KycService {
  KycService({required http.Client client, String? baseUrl})
      : _client = client,
        _base = baseUrl ?? 'https://superapp-diht.onrender.com/api';

  final http.Client _client;
  final String _base;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_base$path').replace(queryParameters: query);

  Future<KycStatus> getStatus() async {
    final res = await _run(() => _client.get(_uri('/kyc/me')));
    return KycStatus.fromJson(_decode(res));
  }

  Future<void> saveDraft(KycDraft draft) async {
    await _run(() => _client.put(
          _uri('/kyc/draft'),
          headers: _jsonHeaders,
          body: jsonEncode({'data': draft.toJson()}),
        ));
  }

  /// [onProgress] is coarse: 0.0 before the request, 1.0 after it succeeds.
  /// AuthedHttpClient buffers the whole body (so it can replay it after a
  /// token refresh), which rules out true byte-level upload progress.
  Future<KycDocumentInfo> uploadDocument({
    required String kind,
    required List<int> bytes,
    required String filename,
    void Function(double)? onProgress,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/kyc/documents'))
      ..fields['kind'] = kind
      ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename));
    onProgress?.call(0.0);
    final res = await _run(() async {
      final streamed = await _client.send(req);
      return http.Response.fromStream(streamed);
    });
    onProgress?.call(1.0);
    return KycDocumentInfo.fromJson(_decode(res));
  }

  Future<void> deleteDocument(String id) async {
    await _run(() => _client.delete(_uri('/kyc/documents/$id')));
  }

  Future<Uint8List> fetchDocument(String id) async {
    final res = await _run(() => _client.get(_uri('/kyc/documents/$id')));
    return res.bodyBytes;
  }

  Future<void> submit() async {
    await _run(() => _client.post(_uri('/kyc/submit')));
  }

  Future<KycNotificationPage> listNotifications({int page = 1}) async {
    final res = await _run(
        () => _client.get(_uri('/notifications', {'page': '$page'})));
    final j = _decode(res);
    final items = j['items'] is List
        ? [
            for (final e in j['items'] as List)
              if (e is Map)
                KycNotification.fromJson(Map<String, dynamic>.from(e))
          ]
        : <KycNotification>[];
    return (
      items: items,
      unread: j['unread'] is num ? (j['unread'] as num).toInt() : 0,
      totalPages:
          j['totalPages'] is num ? (j['totalPages'] as num).toInt() : 0,
    );
  }

  Future<void> markRead(String id) async {
    await _run(() => _client.post(_uri('/notifications/$id/read')));
  }

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  Future<http.Response> _run(Future<http.Response> Function() call) async {
    final http.Response res;
    try {
      res = await call();
    } on KycApiException {
      rethrow;
    } catch (_) {
      throw KycApiException(0, _offlineMessage);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    throw _errorFor(res);
  }

  KycApiException _errorFor(http.Response res) {
    final body = _tryDecode(res);
    final serverMessage = body?['message'];
    final code = res.statusCode;
    switch (code) {
      case 413:
        return KycApiException(
            code, 'This file is too large. Use a file under 8 MB.');
      case 415:
        return KycApiException(code, 'Upload a JPEG, PNG or PDF file.');
      case 429:
        return KycApiException(
            code, 'Too many attempts. Please wait a few minutes.');
      case 503:
        return KycApiException(code,
            'Verification is temporarily unavailable. Please try again later.');
    }
    final message = serverMessage is String && serverMessage.isNotEmpty
        ? serverMessage
        : _fallbackMessage;
    final errors = body?['errors'];
    if (code == 400 && errors is Map) {
      return KycValidationException({
        for (final e in errors.entries) e.key.toString(): e.value.toString(),
      }, message);
    }
    return KycApiException(code, message);
  }

  Map<String, dynamic>? _tryDecode(http.Response res) {
    try {
      final v = jsonDecode(utf8.decode(res.bodyBytes));
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _decode(http.Response res) =>
      _tryDecode(res) ?? (throw KycApiException(res.statusCode, _fallbackMessage));
}
