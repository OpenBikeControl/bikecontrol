class Transaction {
  const Transaction({
    required this.jws,
    required this.productId,
    required this.transactionId,
    required this.purchaseDate,
    required this.originalTransactionId,
  });

  final String? jws;
  final String productId;
  final String transactionId;
  final DateTime purchaseDate;
  final String originalTransactionId;

  @override
  bool operator ==(covariant Transaction other) {
    if (identical(this, other)) return true;
    return other.jws == jws &&
        other.productId == productId &&
        other.transactionId == transactionId &&
        other.purchaseDate == purchaseDate &&
        other.originalTransactionId == originalTransactionId;
  }

  @override
  int get hashCode =>
      jws.hashCode ^
      productId.hashCode ^
      transactionId.hashCode ^
      purchaseDate.hashCode ^
      originalTransactionId.hashCode;

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
        jws: map['jws'] as String?,
        productId: map['productId'] as String,
        transactionId: map['transactionId'] as String,
        purchaseDate: DateTime.parse(map['purchaseDate'] as String),
        originalTransactionId: map['originalTransactionId'] as String,
      );
}
