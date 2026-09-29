import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The app shell for the trainer overlay's own engine (the Android overlay
/// window and the desktop overlay sub-window).
///
/// Same light/dark themes as the main app, following the system brightness
/// like the main app does, and the app's localizations so the overlay's
/// controls can be labelled in the rider's language.
class OverlayShadcnApp extends StatelessWidget {
  const OverlayShadcnApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      debugShowCheckedModeBanner: false,
      scaling: BkTheme.scaling,
      theme: BkTheme.build(Brightness.light),
      darkTheme: BkTheme.build(Brightness.dark),
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: BkComponentThemes(child: home),
    );
  }
}
