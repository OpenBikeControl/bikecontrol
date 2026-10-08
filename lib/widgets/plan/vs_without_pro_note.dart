import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/paywall.dart' show paywallShiftAppName;
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// The blog post comparing virtual shifting with and without BikeControl, per
/// language it is translated into on the website. Languages without a
/// translation get the English post.
const vsBlogPostUrls = {
  'en': 'https://bikecontrol.app/blog/virtual-shifting-with-and-without-bikecontrol/',
  'de': 'https://bikecontrol.app/de/blog/virtuelles-schalten-mit-und-ohne-bikecontrol/',
  'fr': 'https://bikecontrol.app/fr/blog/passage-de-vitesses-virtuel-bikecontrol/',
  'es': 'https://bikecontrol.app/es/blog/cambio-virtual-con-y-sin-bikecontrol/',
  'it': 'https://bikecontrol.app/it/blog/cambio-virtuale-con-e-senza-bikecontrol/',
};

/// The comparison post in [languageCode], or in English.
String vsBlogPostUrl(String languageCode) => vsBlogPostUrls[languageCode] ?? vsBlogPostUrls['en']!;

/// Opens the comparison post in the rider's language, in the browser.
Future<void> openVsBlogPost(BuildContext context) async {
  final url = vsBlogPostUrl(Localizations.localeOf(context).languageCode);
  try {
    final opened = await launchUrlString(url, mode: LaunchMode.externalApplication);
    if (!opened) throw StateError('No app could open $url');
  } catch (e, s) {
    recordError(e, s, context: 'Virtual shifting blog post');
  }
}

/// What happens to virtual shifting without Pro: [app] (the rider's trainer
/// app, or "your trainer app") does it, without what BikeControl Pro adds.
String vsWithoutProText(BuildContext context, SupportedApp? app) {
  final l10n = AppLocalizations.of(context);
  final name = paywallShiftAppName(app);
  return name == null ? l10n.vsWithoutProNoteYourApp : l10n.vsWithoutProNote(name);
}

/// "Learn more ›", opening the comparison post. 48dp on phones.
class VsWithoutProLearnMore extends StatelessWidget {
  const VsWithoutProLearnMore({super.key = const ValueKey('vs-without-pro-learn-more'), this.alignStart = false});

  /// Lines the label up with text above it instead of centring it.
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return BkTouchTarget(
      child: Button(
        style: alignStart
            ? const ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(vertical: 8))
            : const ButtonStyle.ghost(),
        alignment: alignStart ? Alignment.centerLeft : Alignment.center,
        onPressed: () => openVsBlogPost(context),
        child: Text(
          AppLocalizations.of(context).vsWithoutProLearnMore,
          style: context.typography.small.copyWith(color: bkAccentText(context), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// The paywall's line under both plans: [vsWithoutProText], then
/// [VsWithoutProLearnMore], centred.
class VsWithoutProNote extends StatelessWidget {
  const VsWithoutProNote({super.key, required this.app});

  /// The rider's trainer app, if one is picked.
  final SupportedApp? app;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          vsWithoutProText(context, app),
          textAlign: TextAlign.center,
          style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
        ),
        const VsWithoutProLearnMore(),
      ],
    );
  }
}
