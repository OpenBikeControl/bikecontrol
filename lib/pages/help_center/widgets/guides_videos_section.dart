// "Tutorials & Videos" section body — the how-to-connect article link and
// the Tutorials link. The article link is lifted unchanged from the old
// help-button dropdown (Task 8). The YouTube instruction-videos drawer that
// used to close this list was removed (its videos were mostly outdated). The
// tutorials link replaced the blog list that used to sit below
// this card in design round 1 (blog coverage now lives only on the overview
// page). Bug 4: the tutorials link used to point at
// bikecontrol.app/tutorials, which 404s — the website only has /blog and
// /blog/:slug, and the tutorials the row promises ARE blog posts (see the
// "Blog-derived seeds" comment on guides_videos_section.dart's tests /
// the seed migration), so it now points at /blog.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/help_article.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// The how-to article this section lists: the first connected controller's
/// guide for the active trainer app, or null. Exposed so the page can keep
/// the personalized "Your setup" card from repeating it.
HelpArticle? guidesSectionArticle(BuildContext context) {
  final controllers = core.connection.controllerDevices;
  return helpArticleFor(
    context,
    controller: controllers.isEmpty ? null : controllers.first,
    app: core.settings.getTrainerApp(),
  );
}

class GuidesVideosSection extends StatelessWidget {
  const GuidesVideosSection({super.key});

  @override
  Widget build(BuildContext context) {
    final article = guidesSectionArticle(context);

    // Matches the mockup's row padding (`padding:11px 14px`) now that the
    // card itself carries no padding — rows run edge-to-edge and supply
    // their own inset.
    final rowStyle = ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14));

    final rows = <Widget>[
      if (article != null)
        Button.ghost(
          style: rowStyle,
          onPressed: () => launchUrlString(article.url),
          child: Basic(
            leading: const Icon(LucideIcons.bookOpen, size: 18),
            title: Text(article.label),
            trailing: const Icon(LucideIcons.chevronRight, size: 16).iconMutedForeground,
          ),
        ),
      Button.ghost(
        key: const ValueKey('help-center-tutorials'),
        style: rowStyle,
        // bikecontrol.app/tutorials does not exist (website only has
        // /blog and /blog/:slug) — the tutorials are blog posts, so this
        // points there. TODO: point at a dedicated /tutorials index once
        // the website has one.
        onPressed: () => launchUrlString('https://bikecontrol.app/blog'),
        child: Basic(
          leading: const Icon(LucideIcons.circlePlay, size: 18),
          title: Text(AppLocalizations.of(context).tutorials),
          trailing: const Icon(LucideIcons.chevronRight, size: 16).iconMutedForeground,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(),
          rows[i],
        ],
      ],
    );
  }
}
