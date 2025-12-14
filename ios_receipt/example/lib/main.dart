import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:ios_receipt/ios_receipt.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _getReceipt() async {
    try {
      final receiptInBase64 = await IosReceipt.getAppleReceipt();
      print(receiptInBase64);
    } on PlatformException {
      print('PlatformException');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: _getReceipt,
            child: const Text('Get receipt'),
          ),
        ),
      ),
    );
  }
}
