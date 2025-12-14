library windows_iap;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:windows_iap/models/product.dart';

import 'models/store_license.dart';
import 'windows_iap_platform_interface.dart';


enum StorePurchaseStatus {
  succeeded,
  alreadyPurchased,
  notPurchased,
  networkError,
  serverError,
}

class WindowsIap {
  Future<StorePurchaseStatus?> makePurchase(String storeId) {
    return WindowsIapPlatform.instance.makePurchase(storeId);
  }

  /// throw PlatformException if error
  Future<List<Product>> getProducts() {
    if (Platform.isMacOS) {
      return Future.delayed(const Duration(seconds: 2), () {
        throw PlatformException(code: '123123123', message: 'Products can not loaded now.');
      });
    }
    return WindowsIapPlatform.instance.getProducts();
  }

  /// Check when user has current valid purchase
  ///
  /// - Add-On type: Subscription, Durable
  ///
  /// - Always return false if AppLicense has IsActive status = false.
  ///
  /// - if storeId is Not Empty:
  ///
  /// -- it will return true if Product(storeId) has IsActive status = true.
  ///
  /// -- return false if not.
  ///
  /// - if storeId is Empty:
  ///
  /// -- it will return true if any Add-On have IsActive status = true.
  ///
  /// -- return false if all Add-On have IsActive status = false.
  Future<bool> checkPurchase({String storeId = ''}) {
    if (Platform.isMacOS) {
      return Future.value(false);
    }
    return WindowsIapPlatform.instance.checkPurchase(storeId: storeId);
  }

  /// return the map of StoreLicense
  ///
  /// A map of key and value pairs, where each key is the Store ID of an add-on SKU from the
  /// Microsoft Store catalog and each value is a StoreLicense object that contains license
  /// info for the add-on.
  Future<Map<String, StoreLicense>> getAddonLicenses() {
    return WindowsIapPlatform.instance.getAddonLicenses();
  }
}
