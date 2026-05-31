import 'dart:convert';

import 'package:garu/garu.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('products.create', () {
    test('POSTs to /api/products and parses the created product', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'id': 42,
            'uuid': 'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
            'name': 'Plano Pro',
            'value': 2990,
            'pixAutomatic': true,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      final product = await garu.products.create(
        const CreateProductParams(
          name: 'Plano Pro',
          value: 2990,
          description: 'Acesso completo',
          tags: ['saas', 'pro'],
          pix: true,
          pixAutomatic: true,
          isSubscription: true,
          subscriptionType: 'monthly',
        ),
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/products');
      expect(captured.headers['authorization'], 'Bearer sk_test_x');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['name'], 'Plano Pro');
      expect(body['value'], 2990);
      expect(body['description'], 'Acesso completo');
      expect(body['tags'], ['saas', 'pro']);
      expect(body['pix'], true);
      expect(body['pixAutomatic'], true);
      expect(body['isSubscription'], true);
      expect(body['subscriptionType'], 'monthly');

      expect(product.id, 42);
      expect(product.uuid, 'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f');
      expect(product.name, 'Plano Pro');
      expect(product.pixAutomatic, isTrue);

      garu.close();
    });

    test('auto-attaches a UUIDv4 X-Idempotency-Key when none is supplied',
        () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'id': 1, 'uuid': 'u', 'name': 'Curso'}),
          201,
        );
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.products.create(const CreateProductParams(name: 'Curso'));

      expect(
        captured.headers['x-idempotency-key'],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );

      garu.close();
    });

    test('respects a caller-supplied idempotencyKey and omits it from the body',
        () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'id': 1, 'uuid': 'u', 'name': 'Curso'}),
          201,
        );
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.products.create(
        const CreateProductParams(name: 'Curso', idempotencyKey: 'my-custom-key'),
      );

      expect(captured.headers['x-idempotency-key'], 'my-custom-key');
      // The key travels in the header only — never in the JSON body.
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body, {'name': 'Curso'});

      garu.close();
    });

    test('omits null fields from the request body', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'id': 1, 'uuid': 'u', 'name': 'Bare'}),
          201,
        );
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.products.create(const CreateProductParams(name: 'Bare'));

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body.keys, ['name']);
      expect(body['name'], 'Bare');

      garu.close();
    });
  });

  group('products.update', () {
    test('PATCHes /api/products/{id} with a numeric id and partial body',
        () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'id': 42, 'uuid': 'u', 'name': 'Plano Pro+'}),
          200,
        );
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      final product = await garu.products.update(
        42,
        const UpdateProductParams(name: 'Plano Pro+', value: 3990),
      );

      expect(captured.method, 'PATCH');
      expect(captured.url.path, '/api/products/42');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      // Partial: only the fields we set are present.
      expect(body.keys.toSet(), {'name', 'value'});
      expect(body['name'], 'Plano Pro+');
      expect(body['value'], 3990);

      expect(product.name, 'Plano Pro+');

      garu.close();
    });

    test('accepts a UUID string id', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'id': 42, 'uuid': 'b3f2c1e8', 'name': 'X'}),
          200,
        );
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.products.update(
        'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
        const UpdateProductParams(pixAutomatic: true),
      );

      expect(captured.url.path,
          '/api/products/b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body, {'pixAutomatic': true});

      garu.close();
    });

    test('URL-encodes the id so it cannot inject path/query segments',
        () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'id': 1, 'uuid': 'u', 'name': 'X'}),
          200,
        );
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.products.update(
        '1/../999?x=1',
        const UpdateProductParams(name: 'X'),
      );

      expect(captured.url.pathSegments, ['api', 'products', '1/../999?x=1']);
      expect(captured.url.query, isEmpty);

      garu.close();
    });
  });
}
