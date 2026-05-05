import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

enum UnitSystem {
  metric,
  imperial;

  String get speedSymbol => this == imperial ? 'mph' : 'km/h';
  String get distanceSymbol => this == imperial ? 'mi' : 'km';
  String get weightSymbol => this == imperial ? 'lb' : 'kg';

  double fromKph(double kph) => this == imperial ? kph * 0.621371 : kph;
  double fromKm(double km) => this == imperial ? km * 0.621371 : km;
  double fromKg(double kg) => this == imperial ? kg * 2.20462 : kg;

  double toKgFromDisplay(double v) => this == imperial ? v / 2.20462 : v;
}

const _imperialCountries = {'US', 'LR', 'MM'};

UnitSystem unitSystemFor(Locale locale) =>
    _imperialCountries.contains(locale.countryCode?.toUpperCase()) ? UnitSystem.imperial : UnitSystem.metric;

UnitSystem unitSystemOf(BuildContext context) => unitSystemFor(Localizations.localeOf(context));

UnitSystem get platformUnitSystem => unitSystemFor(PlatformDispatcher.instance.locale);

extension UnitFormatting on double {
  String asSpeed(BuildContext c, {int decimals = 1}) {
    final s = unitSystemOf(c);
    return '${s.fromKph(this).toStringAsFixed(decimals)} ${s.speedSymbol}';
  }

  String asDistance(BuildContext c, {int decimals = 2}) {
    final s = unitSystemOf(c);
    return '${s.fromKm(this).toStringAsFixed(decimals)} ${s.distanceSymbol}';
  }

  String asWeight(BuildContext c, {int decimals = 1}) {
    final s = unitSystemOf(c);
    return '${s.fromKg(this).toStringAsFixed(decimals)} ${s.weightSymbol}';
  }
}
