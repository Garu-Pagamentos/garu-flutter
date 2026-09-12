import '../http.dart';
import '../models/offer.dart';

/// Inputs for `offers.create`.
class CreateOfferParams {
  const CreateOfferParams({
    required this.name,
    required this.value,
    this.slug,
    this.isActive,
  });

  /// Internal name for the offer.
  final String name;

  /// Price in **reais** (decimal BRL) — `97.0` is R$97,00, not 97 centavos. It
  /// may be HIGHER than the product's price: an offer works as a premium link
  /// just as well as a discount.
  final num value;

  /// Optional identifier for the link (`?offer=black-friday`): lowercase
  /// letters, digits and hyphens, 3 to 40 characters, unique per product.
  ///
  /// A slug is PUBLIC and guessable. For pricing that should not circulate,
  /// omit it — the link then carries the unguessable offer id.
  final String? slug;

  /// Defaults to true on the server.
  final bool? isActive;

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        if (slug != null) 'slug': slug,
        if (isActive != null) 'isActive': isActive,
      };
}

/// Inputs for `offers.update`. Only the fields you set are sent.
class UpdateOfferParams {
  const UpdateOfferParams({this.name, this.value, this.slug, this.isActive});

  final String? name;

  /// Price in **reais** (decimal BRL).
  final num? value;
  final String? slug;
  final bool? isActive;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (value != null) 'value': value,
        if (slug != null) 'slug': slug,
        if (isActive != null) 'isActive': isActive,
      };
}

/// Offers — sell the same product at more than one price, each behind its own
/// link (Garu v0.23.0).
///
/// Two ways to sell through an offer:
///
/// 1. Hand out the hosted link — `/pay/{productUuid}?offer={slug or id}`
/// 2. Charge it directly — `charges.create(productId: ..., offer: ...)`
///
/// Either way the SERVER resolves the price from the offer. The amount is never
/// taken from the caller.
///
/// Offers are refused on subscription products, which select their price with a
/// subscription price id instead.
class Offers {
  Offers(this._http);

  final HttpRunner _http;

  /// List a product's offers. Defaults to active offers only; pass
  /// `active: 'all'` to include deactivated ones, or `'false'` for only those.
  Future<OfferList> list(
    String productUuid, {
    String? active,
    int? page,
    int? limit,
  }) async {
    final query = <String, String>{
      if (active != null) 'active': active,
      if (page != null) 'page': '$page',
      if (limit != null) 'limit': '$limit',
    };
    final json = await _http.request(
      'GET',
      '/api/v1/products/${Uri.encodeComponent(productUuid)}/offers',
      query: query,
    );
    return OfferList.fromJson(json);
  }

  /// Fetch one offer by id.
  Future<Offer> get(String offerId) async {
    final json = await _http.request(
      'GET',
      '/api/v1/offers/${Uri.encodeComponent(offerId)}',
    );
    return Offer.fromJson(json);
  }

  /// Create an offer on a product.
  ///
  /// Answers 409 when the product has fixed-share co-producers the offer price
  /// could not cover, and 400 on a subscription product.
  ///
  /// ```dart
  /// final offer = await garu.offers.create(
  ///   'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
  ///   const CreateOfferParams(
  ///     name: 'Black Friday',
  ///     value: 97.0, // R$97,00 in reais, NOT centavos
  ///     slug: 'black-friday',
  ///   ),
  /// );
  /// // -> https://garu.com.br/pay/b3f2c1e8-...?offer=black-friday
  /// ```
  Future<Offer> create(String productUuid, CreateOfferParams params) async {
    final json = await _http.request(
      'POST',
      '/api/v1/products/${Uri.encodeComponent(productUuid)}/offers',
      body: params.toJson(),
    );
    return Offer.fromJson(json);
  }

  /// Update an offer (partial — only the fields you pass change).
  ///
  /// Repricing takes effect on the next sale. It does not rewrite history: past
  /// transactions froze the amount they actually collected.
  ///
  /// ```dart
  /// // End a promo without burning the slug
  /// await garu.offers.update(offerId, const UpdateOfferParams(isActive: false));
  /// ```
  Future<Offer> update(String offerId, UpdateOfferParams params) async {
    final json = await _http.request(
      'PATCH',
      '/api/v1/offers/${Uri.encodeComponent(offerId)}',
      body: params.toJson(),
    );
    return Offer.fromJson(json);
  }

  /// Delete an offer. Works only while it has never sold — once a transaction
  /// points at it the answer is 409, so past sales keep their attribution.
  /// Deactivate it instead.
  Future<void> del(String offerId) async {
    await _http.request(
      'DELETE',
      '/api/v1/offers/${Uri.encodeComponent(offerId)}',
    );
  }
}
