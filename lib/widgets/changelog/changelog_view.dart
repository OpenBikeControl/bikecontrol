import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/models/changelog.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// The longest a line of the changelog's prose runs on a wide window — about
/// 70 characters of body text.
const double changelogMaxWidth = 640;

/// The changelog, read top to bottom: the newest release in full — its
/// version large, its date, "Your version" when it is the one running, its
/// notes and its entries grouped by kind — then every earlier release as a
/// compact row that opens in place.
class ChangelogView extends StatelessWidget {
  const ChangelogView({super.key, required this.releases, this.currentVersion});

  final List<ChangelogRelease> releases;

  /// The running app's version, to mark its release.
  final String? currentVersion;

  @override
  Widget build(BuildContext context) {
    if (releases.isEmpty) return const SizedBox.shrink();
    final latest = releases.first;
    final earlier = releases.skip(1).toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: changelogMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ChangelogReleaseFull(
            key: const ValueKey('changelog-latest'),
            release: latest,
            isCurrent: _isCurrent(latest),
          ),
          if (earlier.isNotEmpty) ...[
            const Gap(40),
            BkGroupedSection(
              key: const ValueKey('changelog-earlier'),
              header: context.i18n.changelogEarlierVersions,
              dividerIndent: BkGroupedSection.inset,
              children: [
                for (final r in earlier)
                  _EarlierRelease(key: ValueKey('changelog-${r.version}'), release: r, isCurrent: _isCurrent(r)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _isCurrent(ChangelogRelease release) => currentVersion != null && release.version == currentVersion;
}

/// One release in full: the version in the display face, the date and the
/// "Your version" badge, then its notes and groups.
class ChangelogReleaseFull extends StatelessWidget {
  const ChangelogReleaseFull({super.key, required this.release, this.isCurrent = false});

  final ChangelogRelease release;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = changelogDate(context, release.date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            release.version,
            style: BkNumerals.display(
              (context.typography.x3Large.fontSize ?? 30) * 1.5,
              color: cs.foreground,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        const Gap(6),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (date != null) Text(date, style: context.typography.small.copyWith(color: cs.mutedForeground)),
            if (isCurrent) _CurrentBadge(label: context.i18n.changelogYourVersion),
          ],
        ),
        const Gap(20),
        ChangelogReleaseBody(release: release),
      ],
    );
  }
}

/// A release's notes and its groups of entries, without the version line.
class ChangelogReleaseBody extends StatelessWidget {
  const ChangelogReleaseBody({super.key, required this.release});

  final ChangelogRelease release;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final body = context.typography.base.copyWith(height: 1.5, color: cs.foreground);
    // An untitled group of "other" changes is the whole release in the old
    // entries; a header naming it "Changes" would only repeat the obvious.
    final soleUntitled =
        release.sections.length == 1 &&
        release.sections.single.kind == ChangeKind.other &&
        release.sections.single.title == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, note) in release.notes.indexed) ...[
          if (i > 0) const Gap(12),
          ChangelogInlineText(note, style: body),
        ],
        for (final (i, section) in release.sections.indexed) ...[
          if (i > 0 || release.notes.isNotEmpty) const Gap(24),
          _Section(section: section, showHeader: !soleUntitled),
        ],
      ],
    );
  }
}

/// The release date in the app's language, e.g. "18. September 2026".
String? changelogDate(BuildContext context, DateTime? date) {
  if (date == null) return null;
  return DateFormat.yMMMMd(Localizations.localeOf(context).toLanguageTag()).format(date);
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.showHeader});

  final ChangelogSection section;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.i18n;
    final body = context.typography.base.copyWith(height: 1.5, color: cs.foreground);
    final added = section.kind == ChangeKind.added;
    final tint = added ? bkAccentText(context) : cs.mutedForeground;
    final label =
        section.title ??
        switch (section.kind) {
          ChangeKind.added => l.changelogKindAdded,
          ChangeKind.improved => l.changelogKindImproved,
          ChangeKind.fixed => l.changelogKindFixed,
          ChangeKind.other => l.changelogKindOther,
        };
    return Column(
      key: ValueKey('changelog-section-${section.kind.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader) ...[
          Semantics(
            header: true,
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: added ? cs.primary.withValues(alpha: 0.14) : cs.muted,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(_kindIcon(section.kind), size: 15, color: tint),
                ),
                const Gap(10),
                Expanded(
                  child: Text(
                    label,
                    style: context.typography.small.copyWith(fontWeight: FontWeight.w700, color: cs.foreground),
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
        ],
        for (final (i, entry) in section.entries.indexed) ...[
          if (i > 0) const Gap(10),
          _Entry(entry: entry, style: body),
        ],
      ],
    );
  }

  static IconData _kindIcon(ChangeKind kind) => switch (kind) {
    ChangeKind.added => LucideIcons.sparkles,
    ChangeKind.improved => LucideIcons.trendingUp,
    ChangeKind.fixed => LucideIcons.wrench,
    ChangeKind.other => LucideIcons.listChecks,
  };
}

class _Entry extends StatelessWidget {
  const _Entry({required this.entry, required this.style});

  final ChangelogEntry entry;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final small = context.typography.small.copyWith(height: 1.5, color: cs.foreground);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _bulleted(context, ChangelogInlineText(entry.text, style: style), style, indent: 0),
        for (final child in entry.children) ...[
          const Gap(6),
          _bulleted(context, ChangelogInlineText(child, style: small), small, indent: 22, hollow: true),
        ],
      ],
    );
  }

  /// A bullet centred on the first line of [text], whatever its size.
  Widget _bulleted(BuildContext context, Widget text, TextStyle style, {required double indent, bool hollow = false}) {
    final cs = Theme.of(context).colorScheme;
    final lineHeight = (style.fontSize ?? 16) * (style.height ?? 1.5);
    const dot = 6.0;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: (lineHeight - dot) / 2),
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hollow ? null : cs.mutedForeground,
                border: hollow ? Border.all(color: cs.mutedForeground, width: 1.2) : null,
              ),
            ),
          ),
          const Gap(12),
          Expanded(child: text),
        ],
      ),
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: context.typography.caption.copyWith(color: bkAccentText(context), fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// An earlier release as one row — version, date — that opens in place.
class _EarlierRelease extends StatefulWidget {
  const _EarlierRelease({super.key, required this.release, required this.isCurrent});

  final ChangelogRelease release;
  final bool isCurrent;

  @override
  State<_EarlierRelease> createState() => _EarlierReleaseState();
}

class _EarlierReleaseState extends State<_EarlierRelease> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final release = widget.release;
    final date = changelogDate(context, release.date);
    final motion = prefersReducedMotion(context) ? Duration.zero : const Duration(milliseconds: 220);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BkTappable(
          onPressed: () => setState(() => _open = !_open),
          label: [release.version, ?date, if (widget.isCurrent) context.i18n.changelogYourVersion].join(', '),
          expanded: _open,
          excludeChildSemantics: true,
          wash: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BkGroupedSection.inset, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    release.version,
                    style: BkNumerals.display(
                      (context.typography.x2Large.fontSize ?? 24) * 0.95,
                      color: cs.foreground,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (date != null)
                          Text(date, style: context.typography.small.copyWith(color: cs.mutedForeground)),
                        if (widget.isCurrent) _CurrentBadge(label: context.i18n.changelogYourVersion),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: motion,
                    curve: Curves.easeOutCubic,
                    child: Icon(LucideIcons.chevronRight, size: 16, color: cs.mutedForeground),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: motion,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 4, BkGroupedSection.inset, 20),
                  child: ChangelogReleaseBody(release: release),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// A line of the changelog with its inline markdown: `[links](url)` and bare
/// URLs open in the browser, `**bold**` and `*emphasis*` keep their weight.
class ChangelogInlineText extends StatefulWidget {
  const ChangelogInlineText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<ChangelogInlineText> createState() => _ChangelogInlineTextState();
}

class _ChangelogInlineTextState extends State<ChangelogInlineText> {
  static final _token = RegExp(
    r'\[([^\]]+)\]\((https?://[^)\s]+)\)|\*\*([^*]+)\*\*|\*([^*]+)\*|(https?://[^\s)]*[^\s).,;:!?])',
  );

  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e, s) {
      recordError(e, s, context: 'Changelog.openLink');
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final accent = bkAccentText(context);
    final link = widget.style.copyWith(
      color: accent,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: accent.withValues(alpha: 0.5),
    );
    final spans = <InlineSpan>[];
    var index = 0;
    final text = widget.text;
    for (final m in _token.allMatches(text)) {
      if (m.start > index) spans.add(TextSpan(text: text.substring(index, m.start)));
      if (m.group(1) != null || m.group(5) != null) {
        final url = m.group(2) ?? m.group(5)!;
        final label = m.group(1) ?? url.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
        final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
        _recognizers.add(recognizer);
        spans.add(TextSpan(text: label, style: link, recognizer: recognizer));
      } else if (m.group(3) != null) {
        spans.add(
          TextSpan(
            text: m.group(3),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: m.group(4),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      index = m.end;
    }
    if (index < text.length) spans.add(TextSpan(text: text.substring(index)));
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
