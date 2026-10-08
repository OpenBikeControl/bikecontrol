// When connecting a trainer from the picker fails, the toast says what to do,
// in words — never the raw exception text.
import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/trainer_connect.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main() async {
  final l = await AppLocalizations.load(const Locale('en'));

  test('a Bluetooth timeout reads as "couldn\'t reach the trainer", with what to check', () {
    final message = trainerConnectErrorMessage(l, TimeoutException('Future not completed', const Duration(seconds: 10)), 'Wahoo KICKR 1EB7');
    expect(message, l.trainerConnectTimeout('Wahoo KICKR 1EB7'));
    expect(message, isNot(contains('Exception')));
  });

  test('any other failure gets a plain "couldn\'t connect", not the exception', () {
    final message = trainerConnectErrorMessage(l, StateError('GATT 133'), 'Wahoo KICKR 1EB7');
    expect(message, l.trainerConnectFailed('Wahoo KICKR 1EB7'));
    expect(message, isNot(contains('GATT')));
  });
}
