import Flutter
import UIKit
import StoreKit

public class IosReceiptPlugin: NSObject, FlutterPlugin {

    private func getAppleReceipt() -> String? {
        guard let url = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try? Data(contentsOf: url, options: .alwaysMapped)
        return data?.base64EncodedString()
    }

    private func getAllTransactions() async -> [[String: Any]] {
        var list: [[String: Any]] = []
        if #available(iOS 15.0, *) {
            for await result in Transaction.all {
                switch result {
                case .verified(let tx):
                    var item: [String: Any] = [
                        "productId": tx.productID,
                        "transactionId": String(tx.id),               
                        "originalTransactionId": String(tx.originalID),
                        "purchaseDate": ISO8601DateFormatter().string(from: tx.purchaseDate)
                    ]
                    if let revocationDate = tx.revocationDate {
                        item["revocationDate"] = ISO8601DateFormatter().string(from: revocationDate)
                    }
                    if let reason = tx.revocationReason {
                        item["revocationReason"] = reason.rawValue
                    }
                    if #available(iOS 16.0, *) {
                        item["jws"] = result.jwsRepresentation
                    }
                    list.append(item)

                case .unverified(_, _):
                    continue
                }
            }
        }
        return list
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ios_receipt", binaryMessenger: registrar.messenger())
        let instance = IosReceiptPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "getAppleReceipt":
            result(getAppleReceipt())
        case "getAllTransactions":
            Task { result(await self.getAllTransactions()) }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}