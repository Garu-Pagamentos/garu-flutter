import '../json.dart';

/// A named price on a product, reachable at its own link.
///
/// An offer overrides the PRICE and nothing else: payment methods, the
/// instalment ceiling, carnê, name, description and image all stay on the
/// product, and a bare product link keeps charging `product.value` — so nothing
/// you already published changes when you add one.
class Offer {
  const Offer({
    required this.id,
    required this.productUuid,
    required this.name,
    required this.value,
    required this.isActive,
    this.slug,
    this.createdAt,
    this.updatedAt,
  });

  /// `offer_1Hv7j4EGexuTiOU5BlLNGGuL`.
  final String id;
  final String productUuid;

  /// Internal name — the buyer never sees it.
  final String name;

  /// Price in **reais** (decimal BRL), the same unit as `product.value`.
  final num value;

  final bool isActive;

  /// The identifier used in the public link (`?offer=black-friday`), or null
  /// when the offer has none and the link carries [id] instead.
  ///
  /// A slug is PUBLIC and guessable by anyone holding the product link.
  final String? slug;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// What to put after `?offer=` in a payment link: the slug when there is one,
  /// otherwise the id.
  String get linkParam => slug ?? id;

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
        id: (json['id'] as String?) ?? '',
        productUuid: (json['productUuid'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        value: toNumOr(json['value'], 0),
        isActive: json['isActive'] == true,
        slug: json['slug'] as String?,
        createdAt: _parseDate(json['createdAt']),
        updatedAt: _parseDate(json['updatedAt']),
      );
}

/// One page of `offers.list`.
class OfferList {
  const OfferList({
    required this.data,
    required this.totalCount,
    required this.totalPages,
  });

  final List<Offer> data;
  final int totalCount;
  final int totalPages;

  factory OfferList.fromJson(Map<String, dynamic> json) => OfferList(
        data: (json['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Offer.fromJson)
            .toList(),
        totalCount: toNumOr(json['totalCount'], 0).toInt(),
        totalPages: toNumOr(json['totalPages'], 0).toInt(),
      );
}

DateTime? _parseDate(Object? v) {
  if (v is String) return DateTime.tryParse(v);
  return null;
}
