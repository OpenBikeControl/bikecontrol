import 'package:flutter/widgets.dart';
import 'package:swift_control/gen/app_localizations.dart';

/// Extension to access AppLocalizations from BuildContext
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get i18n => AppLocalizations.of(this);
}
