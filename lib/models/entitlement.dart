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

  bool get isActive => status == 'active' || status == 'grace';

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
