/// Standard paginated envelope returned by Garu list endpoints.
///
/// Every list endpoint returns `{ data: [...], meta: {...} }`. This wraps
/// both into a single typed object and exposes `data`/`meta` getters.
class PaginatedList<T> {
  PaginatedList({required this.data, required this.meta});

  final List<T> data;
  final PaginationMeta meta;

  /// Build from a raw response and a per-item parser.
  factory PaginatedList.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    final rawData = (json['data'] as List<dynamic>?) ?? const <dynamic>[];
    return PaginatedList(
      data: rawData.map((e) => parseItem(e as Map<String, dynamic>)).toList(),
      meta: PaginationMeta.fromJson((json['meta'] as Map<String, dynamic>?) ?? const {}),
    );
  }
}

class PaginationMeta {
  const PaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) => PaginationMeta(
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
        total: (json['total'] as num?)?.toInt() ?? 0,
        totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      );
}
