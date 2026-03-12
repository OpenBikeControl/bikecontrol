import 'package:bike_control/gen/l10n.dart';
import 'package:flutter/material.dart';

extension Intl on BuildContext {
  AppLocalizations get i18n => AppLocalizations.of(this);

  Future<void> push(Widget widget) {
    return Navigator.of(this).push(
      MaterialPageRoute(builder: (_) => widget),
    );
  }
}
