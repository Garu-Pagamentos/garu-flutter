/// Query-string building for the `/api/v1` list endpoints.
///
/// The shared HTTP client takes a `Map<String, String>`, which cannot express
/// a repeated parameter. The v1 list endpoints expect `status` repeated
/// (`?status=active&status=defaulted`); comma-joining arrives as a single
/// invalid enum value and is rejected with 400.
String buildV1ListPath(
  String path,
  Map<String, Object?> single, {
  Map<String, List<String>?> repeated = const {},
}) {
  final parts = <String>[];

  single.forEach((key, value) {
    if (value == null) return;
    parts.add('${Uri.encodeQueryComponent(key)}='
        '${Uri.encodeQueryComponent('$value')}');
  });

  repeated.forEach((key, values) {
    if (values == null) return;
    for (final value in values) {
      parts.add('${Uri.encodeQueryComponent(key)}='
          '${Uri.encodeQueryComponent(value)}');
    }
  });

  return parts.isEmpty ? path : '$path?${parts.join('&')}';
}
