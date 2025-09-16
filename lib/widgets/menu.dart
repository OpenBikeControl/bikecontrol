import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../pages/device.dart';

List<Widget> buildMenuButtons() {
  return [
    PopupMenuButton(
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem(
            child: Text('via Credit Card, Google Pay, Apple Pay and others'),
            onTap: () {
              final currency = NumberFormat.simpleCurrency(locale: Platform.localeName);
              final link = switch (currency.currencyName) {
                'USD' => 'https://donate.stripe.com/8x24gzc5c4ZE3VJdt36J201',
                _ => 'https://donate.stripe.com/9B6aEX0muajY8bZ1Kl6J200',
              };
              launchUrlString(link);
            },
          ),
          PopupMenuItem(
            child: Text('via PayPal'),
            onTap: () {
              launchUrlString('https://paypal.me/boni');
            },
          ),
        ];
      },
      icon: Text('Donate ♥', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
    ),
    SizedBox(width: 8),
    const MenuButton(),
    SizedBox(width: 8),
  ];
}

class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      itemBuilder:
          (c) => [
            if (kDebugMode) ...[
              ...ZwiftButton.values.map(
                (e) => PopupMenuItem(
                  child: Text(e.name),
                  onTap: () {
                    Future.delayed(Duration(seconds: 2)).then((_) {
                      actionHandler.performAction(e);
                    });
                  },
                ),
              ),
              PopupMenuItem(child: PopupMenuDivider()),
              PopupMenuItem(
                child: Text('Continue'),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => DevicePage()));
                },
              ),
              PopupMenuItem(child: PopupMenuDivider()),
            ],
            PopupMenuItem(
              child: Text('Feedback'),
              onTap: () {
                launchUrlString('https://github.com/jonasbark/swiftcontrol/issues');
              },
            ),
            PopupMenuItem(
              child: Text('License'),
              onTap: () {
                showLicensePage(context: context);
              },
            ),
          ],
    );
  }
}
