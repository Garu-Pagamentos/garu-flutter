/// Canonical Garu failure codes (SPEC §6). Stable across gateway changes —
/// route on this enum, log [GaruFailureCode] alongside the raw
/// `gatewayFailureCode` for forensics.
enum GaruFailureCode {
  insufficientFunds('insufficient_funds'),
  cardDeclined('card_declined'),
  cardExpired('card_expired'),
  cardCanceled('card_canceled'),
  processingError('processing_error'),
  issuerUnavailable('issuer_unavailable'),
  fraudSuspected('fraud_suspected'),
  invalidCvv('invalid_cvv'),
  doNotHonorRepeated('do_not_honor_repeated'),
  unknown('unknown');

  const GaruFailureCode(this.wireValue);

  /// The canonical string value sent over the wire (snake_case).
  final String wireValue;

  /// Parse a wire string into the enum. Returns [GaruFailureCode.unknown]
  /// for unrecognized values — the SDK never throws on a forward-compatible
  /// value the gateway might add later.
  static GaruFailureCode fromWire(String? value) {
    if (value == null) return GaruFailureCode.unknown;
    for (final code in GaruFailureCode.values) {
      if (code.wireValue == value) return code;
    }
    return GaruFailureCode.unknown;
  }

  /// Whether this failure code is permanent — i.e., retrying with the
  /// same payment method has no chance of succeeding. Use to gate the
  /// "ask the customer for a new card" UX.
  bool get isPermanent =>
      this == GaruFailureCode.cardExpired ||
      this == GaruFailureCode.cardCanceled ||
      this == GaruFailureCode.fraudSuspected;
}
