/// A payment method understood by the Garu API. Used as the `methods` of a
/// scheduled charge and reported back on a [Charge] (`transaction`) payload.
///
/// Forward-compatible: a wire value introduced after this SDK build resolves
/// to [PaymentMethod.unknown] rather than throwing — inspect the raw string
/// (e.g. `Charge.paymentMethod`) when you hit it.
enum PaymentMethod {
  /// One-off Pix (QR / copy-paste).
  pix('pix'),

  /// Boleto bancário.
  boleto('boleto'),

  /// Credit card.
  card('card'),

  /// Pix Automático — BACEN auto-debit recurring Pix. The customer authorizes
  /// once (consent link / QR in their bank app); later cycles debit silently.
  ///
  /// Only valid on a **recurring** scheduled charge that also carries a
  /// `productId`. The product must have `pixAutomatic` enabled. See
  /// [CreateScheduledChargeParams.methods].
  pixAutomatic('pix_automatic'),

  /// A value the Garu API introduced after this SDK build. Never thrown on,
  /// for forward compatibility.
  unknown('unknown');

  const PaymentMethod(this.wireValue);

  /// The string the Garu API uses on the wire.
  final String wireValue;

  /// Parse a wire value, falling back to [PaymentMethod.unknown] for `null`
  /// or any value this SDK build doesn't recognize.
  static PaymentMethod fromWire(String? v) {
    if (v == null) return PaymentMethod.unknown;
    for (final m in PaymentMethod.values) {
      if (m.wireValue == v) return m;
    }
    return PaymentMethod.unknown;
  }
}
