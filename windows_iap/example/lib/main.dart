// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:andesgroup_common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:windows_iap/windows_iap.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _windowsIapPlugin = WindowsIap();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                    onPressed: () async {
                      final result = await _windowsIapPlugin.checkPurchase();
                      showAlertDialog(context,
                          content: 'checkPurchase: $result');
                    },
                    child: const Text('checkPurchase')),
                const Gap(16),
                ElevatedButton(
                    onPressed: () async {
                      final result =
                          await _windowsIapPlugin.makePurchase('hihi');
                      print('result is $result');
                    },
                    child: const Text('makePurchase')),
                const Gap(16),
                ElevatedButton(
                    onPressed: () async {
                      try {
                        final products = await _windowsIapPlugin.getProducts();
                        print('products: $products');
                      } on PlatformException catch (e, s) {
                        print('error');
                        print(e.toString());
                      }
                    },
                    child: const Text('getProducts')),
                const Gap(16),
                ElevatedButton(
                    onPressed: () async {
                      final result = await _windowsIapPlugin.getAddonLicenses();
                      print('licenses: $result');
                    },
                    child: const Text('getAddonLicenses')),
              ],
            ),
          ),
        );
      }),
    );
  }
}
