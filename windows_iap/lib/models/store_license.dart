class StoreLicense {
  final bool? isActive;
  final String? skuStoreId;
  final String? inAppOfferToken;
  final num? expirationDate;

  const StoreLicense({
    this.isActive,
    this.skuStoreId,
    this.inAppOfferToken,
    this.expirationDate,
  });

  /// get Expiration date in DateTime format.
  DateTime? getExpirationDate() {
    if (expirationDate == null) {
      return null;
    }

    var magic = num.tryParse(expirationDate.toString().substring(0, 14));
    if (magic == null) {
      return null;
    }
    // 11644499200000 is the count of millis from DateTime(1601,1,1) -> DateTime(1970,1,1)
    // more docs: https://docs.microsoft.com/en-us/uwp/cpp-ref-for-winrt/clock
    // https://docs.microsoft.com/en-us/uwp/api/windows.foundation.datetime?view=winrt-22621#remarks
    // https://docs.microsoft.com/en-us/uwp/api/windows.services.store.storelicense.expirationdate?view=winrt-22621
    magic = magic - 11644499200000;
    return DateTime.fromMillisecondsSinceEpoch(magic.toInt());
  }

  factory StoreLicense.fromJson(Map<String, dynamic> json) {
    return StoreLicense(
        isActive: json['isActive'],
        skuStoreId: json['skuStoreId'],
        inAppOfferToken: json['inAppOfferToken'],
        expirationDate: json['expirationDate']);
  }

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'skuStoreId': skuStoreId,
      'inAppOfferToken': inAppOfferToken,
      'expirationDate': expirationDate,
    };
  }
}
