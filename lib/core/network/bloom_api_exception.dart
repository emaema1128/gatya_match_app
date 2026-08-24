/// Thrown when bloom's route_api.php responds with `result: '2'`.
///
/// Deliberately does NOT cover legacy quirks where an endpoint returns
/// `result: '1'` (success) while still nesting an `error_detail` inside
/// `data` (e.g. sendMail on insufficient points) — those are the concern
/// of the specific call site, not this shared exception type.
class BloomApiException implements Exception {
  const BloomApiException(this.errorDetail, {this.executeFunction});

  final String errorDetail;
  final String? executeFunction;

  @override
  String toString() => 'BloomApiException(${executeFunction ?? '?'}): $errorDetail';
}
