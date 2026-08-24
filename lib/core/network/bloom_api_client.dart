import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/token_storage.dart';
import 'bloom_api_exception.dart';
import 'dio_provider.dart';

part 'bloom_api_client.g.dart';

// No staging environment exists for bloom; environment switching is out of
// scope for Stage 0, so this is a plain hardcoded constant.
const _kBloomApiUrl = 'https://bloom-developer.com/app/api/route_api.php';

@Riverpod(keepAlive: true)
BloomApiClient bloomApiClient(Ref ref) => BloomApiClient(ref);

/// Thin, generic wrapper around bloom's single-endpoint execute_function
/// API. Deliberately untyped per-endpoint (Stage 0 scope) — callers pass the
/// execute_function name and its params, and get back the raw `data` map
/// (or `{}` if the endpoint omitted `data`, e.g. simple ack calls). Typed
/// request/response models get added per-feature as screens are built.
///
/// KNOWN QUIRK: sendMail returns `result: '1'` (success) with
/// `data.error_detail` set when the user has insufficient points. This
/// wrapper does NOT special-case it — the sendMail call site must check for
/// `data['error_detail']` itself.
class BloomApiClient {
  BloomApiClient(this._ref);

  final Ref _ref;

  Future<Map<String, dynamic>> callApi(
    String executeFunction,
    Map<String, dynamic> params,
  ) async {
    final dio = _ref.read(dioProvider);
    final systemId = await _ref.read(tokenStorageProvider).readSystemId() ?? -1;

    try {
      final response = await dio.post<Map<String, dynamic>>(
        _kBloomApiUrl,
        data: {
          'system_id': systemId,
          'execute_function': executeFunction,
          ...params,
        },
      );
      return (response.data?['data'] as Map<String, dynamic>?) ?? const {};
    } on DioException catch (e) {
      final error = e.error;
      if (error is BloomApiException) throw error;
      rethrow;
    }
  }
}
