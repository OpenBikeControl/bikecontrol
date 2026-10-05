import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/blog_news.dart';
import 'package:bike_control/services/blog_service.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Activity's News segment: the blog's posts as cards, newest first. A card
/// opens its post in the app's language (a post without a translation opens
/// in English).
class NewsView extends StatefulWidget {
  const NewsView({super.key, required this.controller, this.maxPosts = 20, this.singleColumn = false});

  final BlogNewsController controller;
  final int maxPosts;

  /// One card per row at any width — for News's pane beside the log.
  final bool singleColumn;

  /// From this content width the cards sit two to a row.
  static const double twoColumnWidth = 560;

  @override
  State<NewsView> createState() => _NewsViewState();
}

class _NewsViewState extends State<NewsView> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NewsState>(
      valueListenable: widget.controller.state,
      builder: (context, state, _) => switch (state) {
        NewsLoading() => _grid(
          key: const ValueKey('news-loading'),
          [
            for (var i = 0; i < 3; i++)
              NewsCard(
                post: BlogPost(date: DateTime(2026), title: 'BikeControl news post title', slug: ''),
                isNew: false,
                excerptPlaceholder: true,
              ).asSkeleton(),
          ],
        ),
        NewsFailed() => _NewsMessage(
          key: const ValueKey('news-failed'),
          icon: LucideIcons.wifiOff,
          text: AppLocalizations.of(context).newsLoadFailed,
          action: AppLocalizations.of(context).retry,
          onAction: () => widget.controller.load(force: true),
        ),
        NewsLoaded(:final posts) when posts.isEmpty => _NewsMessage(
          key: const ValueKey('news-empty'),
          icon: LucideIcons.newspaper,
          text: AppLocalizations.of(context).newsEmpty,
        ),
        NewsLoaded(:final posts) => _grid([
          for (final post in posts.take(widget.maxPosts)) NewsCard(post: post, isNew: widget.controller.isNew(post)),
        ]),
      },
    );
  }

  Widget _grid(List<Widget> cards, {Key? key}) {
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = !widget.singleColumn && constraints.maxWidth >= NewsView.twoColumnWidth ? 2 : 1;
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: cards,
          );
        }
        final rows = <Widget>[];
        for (var i = 0; i < cards.length; i += 2) {
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: gap,
                children: [
                  Expanded(child: cards[i]),
                  Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
                ],
              ),
            ),
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: gap, children: rows);
      },
    );
  }
}

/// One post as a card: the cover image (or a tinted header with an icon when
/// the post has none), the date, the title and a two-line excerpt. The whole
/// card opens the post.
class NewsCard extends StatefulWidget {
  const NewsCard({super.key, required this.post, required this.isNew, this.excerptPlaceholder = false});

  final BlogPost post;
  final bool isNew;

  /// Loading placeholders reserve the excerpt's two lines.
  final bool excerptPlaceholder;

  /// Height of the image or tinted header.
  static const double headerHeight = 112;

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  bool _hovered = false;

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url));
    } catch (e, s) {
      recordError(e, s, context: 'NewsCard.open');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    // The app's active language — the OS's or the in-app override.
    final locale = Localizations.localeOf(context);
    final languageCode = locale.languageCode;
    final post = widget.post;
    final title = post.titleForLanguage(languageCode);
    final excerpt = widget.excerptPlaceholder
        ? 'A line or two about the post, as long as the excerpt a real one shows.'
        : post.excerptForLanguage(languageCode);
    final date = DateFormat.yMMMd(locale.toLanguageTag()).format(post.date);
    const radius = BorderRadius.all(Radius.circular(BkComponentThemes.cardRadius));

    return BkTappable(
      onPressed: () => _open(post.urlForLanguage(languageCode)),
      label: [title, date, if (widget.isNew) l10n.newsNewBadge].join(', '),
      excludeChildSemantics: true,
      borderRadius: radius,
      onHover: (hovered) => setState(() => _hovered = hovered),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: _hovered ? bkCardHover(context) : cs.card, borderRadius: radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: NewsCard.headerHeight, child: _header(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Text(date, style: context.typography.xSmall.copyWith(color: cs.mutedForeground)),
                      if (widget.isNew) _NewBadge(label: l10n.newsNewBadge),
                    ],
                  ),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.base.copyWith(fontWeight: FontWeight.w600, color: cs.foreground),
                  ),
                  if (excerpt != null && excerpt.isNotEmpty)
                    Text(
                      excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.small.copyWith(height: 1.35, color: cs.mutedForeground),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final image = widget.post.imageUrl;
    final tinted = _TintedHeader(icon: _iconFor(widget.post));
    if (image == null) return tinted;
    return Image.network(
      image,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => tinted,
      frameBuilder: (context, child, frame, synchronous) => frame == null && !synchronous ? tinted : child,
    );
  }

  /// A release post ("7.0 - One Connection for Everything") gets the
  /// sparkles; everything else reads as an article.
  static IconData _iconFor(BlogPost post) =>
      RegExp(r'^\d+\.\d+').hasMatch(post.title) ? LucideIcons.sparkles : LucideIcons.bookOpen;
}

/// The header of a post without a cover image: the card tinted toward the
/// accent, with one icon.
class _TintedHeader extends StatelessWidget {
  const _TintedHeader({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = bkAccentText(context);
    final top = Color.lerp(cs.card, cs.primary, dark ? 0.22 : 0.14)!;
    final bottom = Color.lerp(cs.card, cs.primary, dark ? 0.08 : 0.05)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom]),
      ),
      child: Center(child: Icon(icon, size: 30, color: accent)),
    );
  }
}

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

/// News with nothing to show: why, and (after a failure) a way to try again.
class _NewsMessage extends StatelessWidget {
  const _NewsMessage({super.key, required this.icon, required this.text, this.action, this.onAction});

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        boxShadow: bkCardShadow(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Icon(icon, size: 24, color: cs.mutedForeground),
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.typography.small.copyWith(color: cs.mutedForeground),
          ),
          if (action != null)
            BkTouchTarget(
              child: Button.secondary(
                alignment: Alignment.center,
                onPressed: onAction,
                child: Text(action!),
              ),
            ),
        ],
      ),
    );
  }
}
