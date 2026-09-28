// "Tutorials & Videos" section body — the how-to-connect article link, the
// Tutorials link, and the instruction-videos drawer. The article link and
// the videos drawer are lifted unchanged from the old help-button dropdown
// (Task 8); the tutorials link replaced the blog list that used to sit below
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

import 'instruction_videos_section.dart';

class GuidesVideosSection extends StatelessWidget {
  const GuidesVideosSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controllers = core.connection.controllerDevices;
    final article = helpArticleFor(
      context,
      controller: controllers.isEmpty ? null : controllers.first,
      app: core.settings.getTrainerApp(),
    );

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
            leading: const Icon(Icons.menu_book_outlined, size: 18),
            title: Text(article.label),
            trailing: const Icon(Icons.chevron_right, size: 16).iconMutedForeground,
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
          leading: const Icon(Icons.play_circle_outline, size: 18),
          title: Text(AppLocalizations.of(context).tutorials),
          trailing: const Icon(Icons.chevron_right, size: 16).iconMutedForeground,
        ),
      ),
      Button.ghost(
        style: rowStyle,
        onPressed: () {
          openDrawer(
            context: context,
            position: OverlayPosition.bottom,
            builder: (c) => const InstructionVideosDrawer(),
          );
        },
        child: Basic(
          leading: const Icon(Icons.ondemand_video, size: 18),
          title: Text(AppLocalizations.of(context).instructionVideos),
          trailing: const Icon(Icons.chevron_right, size: 16).iconMutedForeground,
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
