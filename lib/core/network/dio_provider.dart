import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/token_storage.dart';
import 'bloom_api_exception.dart';

part 'dio_provider.g.dart';

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(BaseOptions(contentType: Headers.jsonContentType));
  dio.transformer = _AlwaysJsonTransformer();
  dio.interceptors.add(_BloomAuthInterceptor(ref));
  return dio;
}

/// route_api.php always echoes `json_encode(...)` but never sends
/// `Content-Type: application/json` (PHP defaults to `text/html`), so dio's
/// default transformer — which only auto-decodes JSON when the response
/// Content-Type says so — leaves the body as a raw String instead of a Map.
/// Rewriting the header before delegating to [FusedTransformer] (dio's
/// actual default, per DioMixin) keeps every other behavior (streams, bytes,
/// the fast-path UTF8+JSON decode, custom responseDecoder) intact.
class _AlwaysJsonTransformer extends FusedTransformer {
  @override
  Future<dynamic> transformResponse(RequestOptions options, ResponseBody responseBody) {
    responseBody.headers[Headers.contentTypeHeader] = [Headers.jsonContentType];
    return super.transformResponse(options, responseBody);
  }
}

/// Attaches the bloom `Authorization: Bearer <token>` header to every
/// request, and translates `result: '2'` responses into a thrown
/// [BloomApiException]. A malformed (non-JSON) response body — possible
/// when route_api.php hits an uncaught PHP error — is handled for free by
/// dio's default JSON decoding, which surfaces as an ordinary [DioException]
/// before [onResponse] ever runs.
class _BloomAuthInterceptor extends Interceptor {
  _BloomAuthInterceptor(this._ref);

  final Ref _ref;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _attachToken(options, handler);
  }

  Future<void> _attachToken(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _ref.read(tokenStorageProvider).readToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final body = response.data;
    if (body is Map<String, dynamic> && body['result'] == '2') {
      final requestBody = response.requestOptions.data;
      final function = requestBody is Map ? requestBody['execute_function'] as String? : null;
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: BloomApiException(
            (body['error_detail'] as String?) ?? 'unknown error',
            executeFunction: function,
          ),
        ),
      );
      return;
    }
    handler.next(response);
  }
}
