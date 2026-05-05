// ignore_for_file: avoid_print
import 'dart:io';

import 'package:garu/garu.dart';

Future<void> main() async {
  final apiKey = Platform.environment['GARU_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set GARU_API_KEY first.');
    exit(1);
  }

  final garu = Garu(apiKey: apiKey);

  try {
    final charge = await garu.charges.create(
      productId: 'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
      paymentMethod: 'pix',
      customer: const CustomerInput(
        name: 'Maria Silva',
        email: 'maria@exemplo.com.br',
        document: '12345678909',
        phone: '11987654321',
      ),
    );
    print('Charge created: ${charge['id']} status=${charge['status']}');
  } on GaruValidationError catch (e) {
    stderr.writeln('Validation failed: ${e.message}');
  } on GaruApiError catch (e) {
    stderr.writeln('API error ${e.status}: ${e.message}');
  } on GaruConnectionError catch (e) {
    stderr.writeln('Network failure: ${e.message}');
  } finally {
    garu.close();
  }
}
