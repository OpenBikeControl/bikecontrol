import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/blog_news.dart';
import 'package:bike_control/services/blog_service.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_brand_band.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: context.typography.caption.copyWith(color: cs.primaryForeground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// News's place on Activity: the newest posts as one banner on the brand
/// band above the log and the rides — the title, the excerpt,
/// the date (with "New" while recent), "Read post" and "All news", and the
/// cover beside it on a wide window. A phone gets the same banner, tighter. Dots step through the three newest posts. Nothing shows
/// while there is nothing to show (no posts, or a failed load).
class NewsBanner extends StatefulWidget {
  const NewsBanner({super.key, required this.controller});

  final BlogNewsController controller;

  /// How many of the newest posts the dots step through.
  static const int maxPosts = 3;

  /// The banner's least height, so loading and loaded take the same room; a
  /// long title (German wraps wide) grows it instead of overflowing.
  static const double minHeight = 208;

  /// From this width the cover sits beside the text, which then still has
  /// ~600 px: below it the cover would squeeze the title and the actions.
  static const double coverBreakpoint = 980;

  /// The cover's width beside the text, at the blog's 1200 × 630.
  static const double coverWidth = 300;

  /// The excerpt's measure: about 70 characters, not the banner's width.
  static const double excerptMaxWidth = 560;

  @override
  State<NewsBanner> createState() => _NewsBannerState();
}

class _NewsBannerState extends State<NewsBanner> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  void didUpdateWidget(NewsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _index = 0;
      widget.controller.load();
    }
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url));
    } catch (e, s) {
      recordError(e, s, context: 'NewsBanner.open');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NewsState>(
      valueListenable: widget.controller.state,
      builder: (context, state, _) => switch (state) {
        NewsLoading() => _band(
          context,
          SizedBox(height: _compact(context) ? 150 : NewsBanner.minHeight - 48),
        ).asSkeleton(),
        NewsLoaded(:final posts) when posts.isNotEmpty => _loaded(
          context,
          posts.take(NewsBanner.maxPosts).toList(),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  /// A phone's banner: tighter, its height set by the content.
  static bool _compact(BuildContext context) => isCompactWindow(context);

  Widget _band(BuildContext context, Widget child) {
    final compact = _compact(context);
    return ConstrainedBox(
      key: const ValueKey('news-banner'),
      constraints: BoxConstraints(minHeight: compact ? 0 : NewsBanner.minHeight),
      child: BkBrandBand(
        borderRadius: const BorderRadius.all(Radius.circular(BkComponentThemes.cardRadius + 4)),
        contours: const BkContourPlacement.card(),
        padding: EdgeInsets.all(compact ? 18 : 24),
        child: child,
      ),
    );
  }

  Widget _loaded(BuildContext context, List<BlogPost> posts) {
    final index = _index.clamp(0, posts.length - 1);
    final post = posts[index];
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final languageCode = locale.languageCode;
    final title = post.titleForLanguage(languageCode);
    final excerpt = post.excerptForLanguage(languageCode);
    final date = DateFormat.yMMMd(locale.toLanguageTag()).format(post.date);
    final isNew = widget.controller.isNew(post);
    final image = post.imageUrl;
    final blogUrl = post.translationFor(languageCode) != null
        ? 'https://bikecontrol.app/$languageCode/blog/'
        : 'https://bikecontrol.app/blog/';

    return LayoutBuilder(
      builder: (context, constraints) {
        final withCover = image != null && constraints.maxWidth >= NewsBanner.coverBreakpoint;
        return _band(
          context,
          Builder(
            builder: (context) {
              // On the band every text is full white: anything fainter drops
              // under 4.5:1 on its light-mode blue.
              final text = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      key: const ValueKey('news-banner-title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (_compact(context) ? context.typography.xLarge : context.typography.x2Large).copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ),
                  if (excerpt != null && excerpt.isNotEmpty) ...[
                    const Gap(8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: NewsBanner.excerptMaxWidth),
                      child: Text(
                        excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.small.copyWith(height: 1.45),
                      ),
                    ),
                  ],
                  const Gap(10),
                  Row(
                    spacing: 8,
                    children: [
                      if (isNew) _NewBadge(label: l10n.newsNewBadge),
                      Text(date, style: context.typography.small.copyWith(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      // The dots with the date: on a phone the actions fill
                      // their own line.
                      if (posts.length > 1)
                        for (final (i, p) in posts.indexed)
                          _PagerDot(
                            key: ValueKey('news-banner-dot-$i'),
                            selected: i == index,
                            label: p.titleForLanguage(languageCode),
                            onPressed: () => setState(() => _index = i),
                          ),
                    ],
                  ),
                  const Gap(18),
                  // Wraps rather than overflows: German labels are long.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      BkTouchTarget(
                        child: Button.primary(
                          key: const ValueKey('news-banner-read'),
                          alignment: Alignment.center,
                          onPressed: () => _open(post.urlForLanguage(languageCode)),
                          child: Text(l10n.newsReadPost),
                        ),
                      ),
                      BkTouchTarget(
                        child: Button.ghost(
                          key: const ValueKey('news-banner-all'),
                          alignment: Alignment.center,
                          onPressed: () => _open(blogUrl),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 6,
                            children: [Text(l10n.newsAllPosts), const Icon(LucideIcons.externalLink, size: 14)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
              if (!withCover) return text;
              return Row(
                spacing: 28,
                children: [
                  Expanded(child: text),
                  // The whole cover, never cropped: the blog's covers carry
                  // their own lettering.
                  SizedBox(
                    width: NewsBanner.coverWidth,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 1200 / 630,
                        child: ExcludeSemantics(
                          child: Image.network(
                            image,
                            key: ValueKey('news-banner-cover-${post.slug}'),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// One of the banner's dots: the chosen post's is a wider pill.
class _PagerDot extends StatelessWidget {
  const _PagerDot({super.key, required this.selected, required this.label, required this.onPressed});

  final bool selected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BkTappable(
      onPressed: onPressed,
      label: label,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        // A thumb-sized target on a phone.
        width: selected ? 38 : (isCompactWindow(context) ? 32 : 24),
        height: isCompactWindow(context) ? 44 : 28,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: selected ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              // Unselected at 70%: still 3:1 on the band, as a control must be.
              color: cs.foreground.withValues(alpha: selected ? 1 : 0.7),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}
