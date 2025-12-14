import 'package:ios_receipt/models/transaction.dart';

import 'ios_receipt_platform_interface.dart';

class IosReceipt {
  @Deprecated('Use getAllTransactions from StoreKit2')
  static Future<String?> getAppleReceipt() {
    return IosReceiptPlatform.instance.getAppleReceipt();
  }

  static Future<List<Transaction>> getAllTransactions() async {
    final list = await IosReceiptPlatform.instance.getAllTransactions();
    final result = <Transaction>[];
    for (var data in list) {
      result.add(Transaction.fromMap(data));
    }
    return result..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
  }
}
