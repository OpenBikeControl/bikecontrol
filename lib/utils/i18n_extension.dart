import 'package:flutter/material.dart';
import 'package:bike_control/gen/l10n.dart';

extension Intl on BuildContext {
  AppLocalizations get i18n => AppLocalizations.of(this);
}
