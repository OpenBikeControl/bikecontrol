class Entitlement {
  final String productKey;
  final String status;
  final DateTime? activeUntil;
  final String source;

  const Entitlement({
    required this.productKey,
    required this.status,
    required this.activeUntil,
    required this.source,
  });

  bool get isActive => isActiveAt(DateTime.now());

  /// Store and Stripe rows are kept current by webhooks, and their
  /// `activeUntil` can lag a renewal, so only their status counts. Nothing
  /// flips a manual grant's status, so it ends at its `activeUntil`.
  bool isActiveAt(DateTime now) {
    if (status != 'active') return false; // || status == 'grace';
    final until = activeUntil;
    if (source == 'manual' && until != null && !until.isAfter(now)) return false;
    return true;
  }

  factory Entitlement.fromJson(Map<String, dynamic> json) {
    return Entitlement(
      productKey: json['product_key'] as String? ?? '',
      status: json['status'] as String? ?? 'expired',
      activeUntil: _parseDateTime(json['active_until']),
      source: json['source'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_key': productKey,
      'status': status,
      'active_until': activeUntil?.toIso8601String(),
      'source': source,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
