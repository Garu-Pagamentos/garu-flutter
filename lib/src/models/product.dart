/// A Garu product record. The `uuid` is the identifier accepted by the
/// charge tools — pass it as `productId` to `charges.create`.
class Product {
  Product({
    required this.id,
    required this.uuid,
    required this.name,
    this.value,
    this.sellerId,
    this.raw = const {},
  });

  final int id;
  final String uuid;
  final String name;
  final num? value;
  final int? sellerId;

  final Map<String, dynamic> raw;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: (json['id'] as num).toInt(),
        uuid: (json['uuid'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        value: json['value'] as num?,
        sellerId: (json['sellerId'] as num?)?.toInt(),
        raw: json,
      );
}

/// Per-product portal customization (SPEC §4.1, B2B2C primitive).
///
/// Returned by `products.portalConfig.get/set/patch`. `null` from `get`
/// means the product has no per-product config and falls back to the
/// seller-level config.
class ProductPortalConfig {
  ProductPortalConfig({
    required this.productId,
    this.businessName,
    this.logoUrl,
    this.primaryColor,
    this.allowCancelSubscription,
    this.allowUpdatePaymentMethod,
    this.allowUpdateBillingInfo,
    this.allowViewInvoices,
    this.allowApplyCoupons,
    this.requireCancelReason,
    this.cancelAtPeriodEndOnly,
    this.sendCancellationEmail,
    this.sendPaymentMethodUpdatedEmail,
    this.customSuccessMessage,
    this.customCancellationMessage,
    this.customWelcomeText,
    this.raw = const {},
  });

  final String productId;
  final String? businessName;
  final String? logoUrl;
  final String? primaryColor;
  final bool? allowCancelSubscription;
  final bool? allowUpdatePaymentMethod;
  final bool? allowUpdateBillingInfo;
  final bool? allowViewInvoices;
  final bool? allowApplyCoupons;
  final bool? requireCancelReason;
  final bool? cancelAtPeriodEndOnly;
  final bool? sendCancellationEmail;
  final bool? sendPaymentMethodUpdatedEmail;
  final String? customSuccessMessage;
  final String? customCancellationMessage;
  final String? customWelcomeText;

  final Map<String, dynamic> raw;

  factory ProductPortalConfig.fromJson(Map<String, dynamic> json) => ProductPortalConfig(
        productId: (json['productId'] as num?)?.toString() ?? '',
        businessName: json['businessName'] as String?,
        logoUrl: json['logoUrl'] as String?,
        primaryColor: json['primaryColor'] as String?,
        allowCancelSubscription: json['allowCancelSubscription'] as bool?,
        allowUpdatePaymentMethod: json['allowUpdatePaymentMethod'] as bool?,
        allowUpdateBillingInfo: json['allowUpdateBillingInfo'] as bool?,
        allowViewInvoices: json['allowViewInvoices'] as bool?,
        allowApplyCoupons: json['allowApplyCoupons'] as bool?,
        requireCancelReason: json['requireCancelReason'] as bool?,
        cancelAtPeriodEndOnly: json['cancelAtPeriodEndOnly'] as bool?,
        sendCancellationEmail: json['sendCancellationEmail'] as bool?,
        sendPaymentMethodUpdatedEmail: json['sendPaymentMethodUpdatedEmail'] as bool?,
        customSuccessMessage: json['customSuccessMessage'] as String?,
        customCancellationMessage: json['customCancellationMessage'] as String?,
        customWelcomeText: json['customWelcomeText'] as String?,
        raw: json,
      );
}

/// Mutable input for `products.portalConfig.set/patch`. Each field is
/// nullable: omit to preserve the persisted value, pass `null` to inherit
/// from the seller-level config.
class SetProductPortalConfigParams {
  const SetProductPortalConfigParams({
    this.businessName,
    this.logoUrl,
    this.primaryColor,
    this.allowCancelSubscription,
    this.allowUpdatePaymentMethod,
    this.allowUpdateBillingInfo,
    this.allowViewInvoices,
    this.allowApplyCoupons,
    this.requireCancelReason,
    this.cancelAtPeriodEndOnly,
    this.sendCancellationEmail,
    this.sendPaymentMethodUpdatedEmail,
    this.customSuccessMessage,
    this.customCancellationMessage,
    this.customWelcomeText,
  });

  final String? businessName;
  final String? logoUrl;
  final String? primaryColor;
  final bool? allowCancelSubscription;
  final bool? allowUpdatePaymentMethod;
  final bool? allowUpdateBillingInfo;
  final bool? allowViewInvoices;
  final bool? allowApplyCoupons;
  final bool? requireCancelReason;
  final bool? cancelAtPeriodEndOnly;
  final bool? sendCancellationEmail;
  final bool? sendPaymentMethodUpdatedEmail;
  final String? customSuccessMessage;
  final String? customCancellationMessage;
  final String? customWelcomeText;

  Map<String, dynamic> toJson() => {
        if (businessName != null) 'businessName': businessName,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (primaryColor != null) 'primaryColor': primaryColor,
        if (allowCancelSubscription != null) 'allowCancelSubscription': allowCancelSubscription,
        if (allowUpdatePaymentMethod != null) 'allowUpdatePaymentMethod': allowUpdatePaymentMethod,
        if (allowUpdateBillingInfo != null) 'allowUpdateBillingInfo': allowUpdateBillingInfo,
        if (allowViewInvoices != null) 'allowViewInvoices': allowViewInvoices,
        if (allowApplyCoupons != null) 'allowApplyCoupons': allowApplyCoupons,
        if (requireCancelReason != null) 'requireCancelReason': requireCancelReason,
        if (cancelAtPeriodEndOnly != null) 'cancelAtPeriodEndOnly': cancelAtPeriodEndOnly,
        if (sendCancellationEmail != null) 'sendCancellationEmail': sendCancellationEmail,
        if (sendPaymentMethodUpdatedEmail != null)
          'sendPaymentMethodUpdatedEmail': sendPaymentMethodUpdatedEmail,
        if (customSuccessMessage != null) 'customSuccessMessage': customSuccessMessage,
        if (customCancellationMessage != null) 'customCancellationMessage': customCancellationMessage,
        if (customWelcomeText != null) 'customWelcomeText': customWelcomeText,
      };
}
