class Product {
  final String? title;
  final String? description;
  final String? price;
  final bool? inCollection;
  final String? productKind;
  final String? storeId;

  const Product({
    required this.title,
    required this.description,
    required this.price,
    required this.inCollection,
    required this.productKind,
    required this.storeId,
  });

  String? get formattedTitle {
    return "$title ($productKind) $price, InUserCollection: $inCollection";
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
        title: json['title'] as String?,
        description: json['description'] as String?,
        price: json['price'] as String?,
        inCollection: json['inCollection'] as bool?,
        productKind: json['productKind'] as String?,
        storeId: json['storeId'] as String?);
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'price': price,
      'inCellection': inCollection,
      'productKind': productKind,
      'storeId': storeId,
    };
  }
}
