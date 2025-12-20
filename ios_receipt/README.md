# IosReceipt

The IosReceipt package allows you to easily fetch the App Store receipt in your Flutter application on the iOS platform.

## Installation

Add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  ios_receipt: ^0.0.1  # Use the latest version of the package
```
Then, run flutter pub get to install the package.

## Usage
Method for get transactions with StoreKit2
```dart
final transactions = await IosReceipt.getAllTransactions();
```

## Based on
This package is based on the [appStoreReceiptURL](https://developer.apple.com/documentation/foundation/nsbundle/1407276-appstorereceipturl) from the official Apple documentation.

## Note
- The receipt isn't necessary if you use AppTransaction to validate the app download, or Transaction to validate in-app purchases.
- If the receipt is invalid or missing in your app, use SKReceiptRefreshRequest to request a new receipt.

## Testing Environments
Keep in mind that receipts aren't initially present in iOS and iPadOS apps in the sandbox environment and in Xcode. Apps receive a receipt after the tester completes the first in-app purchase.

## License
This project is licensed under the MIT License.