import 'dart:convert';

import 'package:garu/garu.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

Map<String, dynamic> offerJson([Map<String, dynamic> extra = const {}]) => {
      'id': 'offer_1Hv7j4EGexuTiOU5BlLNGGuL',
      'productUuid': 'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
      'name': 'Black Friday',
      'slug': 'black-friday',
      'value': 97.0,
      'isActive': true,
      'createdAt': '2026-09-11T14:22:01.000Z',
      'updatedAt': '2026-09-11T14:22:01.000Z',
      ...extra,
    };

void main() {
  group('offers.create', () {
    test('posts reais to the product offer route', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode(offerJson()), 201,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      final offer = await garu.offers.create(
        'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
        const CreateOfferParams(
            name: 'Black Friday', value: 97.0, slug: 'black-friday'),
      );

      expect(captured.url.path,
          '/api/v1/products/b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f/offers');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      // R$97,00. The API floor is 0.01, which is only expressible in reais.
      expect(body['value'], 97.0);
      expect(body['slug'], 'black-friday');
      expect(offer.value, 97.0);
      garu.close();
    });

    test('omits the slug when the seller wants an unguessable link', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode(offerJson({'slug': null})), 201,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      final offer = await garu.offers.create(
        'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
        const CreateOfferParams(name: 'Preço fechado', value: 49.9),
      );

      expect((jsonDecode(captured.body) as Map).containsKey('slug'), isFalse);
      // Without a slug the link has to carry the id instead.
      expect(offer.slug, isNull);
      expect(offer.linkParam, 'offer_1Hv7j4EGexuTiOU5BlLNGGuL');
      garu.close();
    });
  });

  test('linkParam prefers the slug a seller chose', () {
    expect(Offer.fromJson(offerJson()).linkParam, 'black-friday');
  });

  test('offers.list defaults to active and parses the envelope', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(
          jsonEncode({
            'data': [
              offerJson(),
              offerJson({
                'id': 'offer_2',
                'name': 'Lote 2',
                'slug': null,
                'value': 149.9
              })
            ],
            'totalCount': 2,
            'totalPages': 1,
          }),
          200,
          headers: {'content-type': 'application/json'});
    });
    final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

    final page = await garu.offers.list('b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f');

    expect(captured.url.path,
        '/api/v1/products/b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f/offers');
    expect(captured.url.queryParameters.containsKey('active'), isFalse);
    expect(page.data.map((o) => o.name), ['Black Friday', 'Lote 2']);
    expect(page.data.map((o) => o.value), [97.0, 149.9]);
    expect(page.data[1].linkParam, 'offer_2');
    garu.close();
  });

  test('offers.update can end a promo without burning the slug', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(jsonEncode(offerJson({'isActive': false})), 200,
          headers: {'content-type': 'application/json'});
    });
    final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

    final offer = await garu.offers.update(
      'offer_1Hv7j4EGexuTiOU5BlLNGGuL',
      const UpdateOfferParams(isActive: false),
    );

    expect(captured.method, 'PATCH');
    expect(captured.url.path, '/api/v1/offers/offer_1Hv7j4EGexuTiOU5BlLNGGuL');
    expect(jsonDecode(captured.body), {'isActive': false});
    expect(offer.isActive, isFalse);
    expect(offer.slug, 'black-friday');
    garu.close();
  });

  test('offers.get reads a value the API sent as a string', () {
    // Decimal columns reach the wire as text on the older endpoints; parsing
    // must not depend on which shape arrives.
    expect(Offer.fromJson(offerJson({'value': '97.00'})).value, 97.0);
  });
}
