import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/ui/beta_pill.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

const _supportedTrainersUrl = 'https://bikecontrol.app/virtual-shifting';

/// One-time, full-screen explainer shown the first time the user opens the
/// Smart Trainer page: Virtual Shifting is in beta, works on dozens of
/// trainers, and we're happy to help dial in your setup.
Future<void> showVirtualShiftingIntro(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const VirtualShiftingIntroPage(),
    ),
  );
}

class VirtualShiftingIntroPage extends StatelessWidget {
  const VirtualShiftingIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hero(context, l10n, topInset),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 24,
                      children: [
                        _feature(
                          cs,
                          icon: LucideIcons.circleCheck,
                          color: const Color(0xFF1E9E5A),
                          title: l10n.vsIntroSupportedTitle,
                          body: l10n.vsIntroSupportedBody,
                          below: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Button.text(
                              onPressed: () => launchUrlString(
                                _supportedTrainersUrl,
                                mode: LaunchMode.externalApplication,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.externalLink, size: 15),
                                  const SizedBox(width: 6),
                                  Text(l10n.vsIntroSupportedTrainersCta),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _feature(
                          cs,
                          icon: LucideIcons.triangleAlert,
                          color: const Color(0xFFE5860B),
                          title: l10n.vsIntroBetaTitle,
                          body: l10n.vsIntroBetaBody,
                        ),
                        _feature(
                          cs,
                          icon: LucideIcons.messageCircle,
                          color: BKColor.main,
                          title: l10n.vsIntroFeedbackTitle,
                          body: l10n.vsIntroFeedbackBody,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                PrimaryButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(l10n.vsIntroGotIt),
                ),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, AppLocalizations l10n, double topInset) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(24, topInset + 30, 24, 36),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [BKColor.main, BKColor.mainEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Container(
                width: 78,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(46),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(64)),
                ),
                child: const Icon(LucideIcons.sparkles, size: 38, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      l10n.vsIntroTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const BetaPill(),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.vsIntroSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: Colors.white.withAlpha(225),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: topInset + 4,
          right: 6,
          child: IconButton.ghost(
            icon: const Icon(LucideIcons.x, size: 22, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }

  Widget _feature(
    ColorScheme cs, {
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    Widget? below,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withAlpha(28),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, letterSpacing: -0.2),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(fontSize: 14, height: 1.4, color: cs.mutedForeground),
              ),
              if (below != null) ...[
                const SizedBox(height: 4),
                below,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
