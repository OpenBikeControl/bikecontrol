import 'package:bike_control/pages/settings/overlay_settings_page.dart' show overlaySettingsDestination;
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/help_center/help_checks.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:bike_control/utils/support/intake_self_help.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SupportIntakeForm extends StatefulWidget {
  final SupportChatService service;
  final IntakeAnswers? initial;
  final ValueChanged<IntakeAnswers> onContinue;

  /// "Did this solve it?" → Yes, for an answer shown inline. Null hides the
  /// question (the rider can still continue to the composer).
  final VoidCallback? onSolved;

  /// Test seam: resolves the trainer the inline answers act on, instead of
  /// `core.connection.proxyDevices`.
  @visibleForTesting
  final ProxyDevice? Function()? debugTrainer;

  const SupportIntakeForm({
    super.key,
    required this.service,
    required this.onContinue,
    this.initial,
    this.onSolved,
    this.debugTrainer,
  });

  @override
  State<SupportIntakeForm> createState() => _SupportIntakeFormState();
}

class _SupportIntakeFormState extends State<SupportIntakeForm> {
  IntakeCategory? _category;
  String? _subcategoryValue;
  String? _symptom;
  List<SupportIssue> _matchingIssues = const [];
  int _fetchSeq = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _category = initial.category;
      _subcategoryValue = initial.subcategoryValue;
      _symptom = initial.symptom;
      _refreshIssues();
    }
  }

  Future<void> _refreshIssues() async {
    final category = _category;
    if (category == null) {
      if (mounted) setState(() => _matchingIssues = const []);
      return;
    }
    final seq = ++_fetchSeq;
    final subs = <String>[
      if (_subcategoryValue != null && _subcategoryValue!.isNotEmpty) _subcategoryValue!,
      if (_symptom != null && _symptom!.isNotEmpty) _symptom!,
    ];
    try {
      final issues = await widget.service.fetchOpenIssues(
        problemCategory: category.id,
        problemSubcategories: subs,
      );
      if (!mounted || seq != _fetchSeq) return;
      setState(() => _matchingIssues = issues.take(3).toList(growable: false));
    } on SupportChatException {
      if (!mounted || seq != _fetchSeq) return;
      setState(() => _matchingIssues = const []);
    }
  }

  void _setCategory(IntakeCategory? next) {
    setState(() {
      _category = next;
      _symptom = null;
      // Pre-fill the trainer-app branch from settings when available — the UI
      // hides the "Which app?" dropdown in that case.
      if (next == IntakeCategory.trainerApp) {
        final preselected = core.settings.getTrainerApp();
        _subcategoryValue = preselected?.name;
      } else {
        _subcategoryValue = null;
      }
    });
    _refreshIssues();
  }

  void _setSubcategory(String? value) {
    setState(() => _subcategoryValue = value);
    _refreshIssues();
  }

  void _setSymptom(String? value) {
    setState(() => _symptom = value);
    _refreshIssues();
  }

  IntakeAnswers _buildAnswers() {
    final category = _category!;
    final String? subcategoryKind = switch (category) {
      IntakeCategory.trainerApp => _subcategoryValue != null ? 'app' : null,
      IntakeCategory.controller => _subcategoryValue != null ? 'device' : null,
      IntakeCategory.smartTrainer => _subcategoryValue != null ? 'issue' : null,
      IntakeCategory.account => _subcategoryValue != null ? 'issue' : null,
      IntakeCategory.somethingElse => null,
    };
    return IntakeAnswers(
      category: category,
      subcategory: subcategoryKind,
      subcategoryValue: _subcategoryValue,
      symptom: _symptom,
      // Kept only while the answer is still about the same controller.
      firmware: _subcategoryValue == widget.initial?.subcategoryValue ? widget.initial?.firmware : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canContinue = _category != null;
    final selfHelp = canContinue ? intakeSelfHelpFor(_buildAnswers()) : null;
    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.i18n.supportIntakeTitle,
            style: context.typography.base.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(4),
          Text(
            context.i18n.supportIntakeSubtitle,
            style: context.typography.small.copyWith(color: cs.mutedForeground),
          ),
          const Gap(16),
          _label(context.i18n.supportIntakeCategoryLabel),
          const Gap(4),
          _categorySelect(),
          if (_category != null) ...[
            const Gap(12),
            ..._buildFollowUp(),
          ],
          if (_matchingIssues.isNotEmpty) ...[
            const Gap(16),
            _RecommendedHelp(issues: _matchingIssues),
          ],
          const Gap(16),
          if (selfHelp != null)
            _InlineSelfHelp(
              key: ValueKey('intake-self-help-${selfHelp.name}'),
              help: selfHelp,
              controllerId: _category == IntakeCategory.controller ? _subcategoryValue : null,
              trainer: widget.debugTrainer,
              onSolved: widget.onSolved,
              onNotSolved: () => widget.onContinue(_buildAnswers()),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: Button.primary(
                onPressed: canContinue ? () => widget.onContinue(_buildAnswers()) : null,
                child: Text(context.i18n.supportIntakeContinue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: context.typography.xSmall.copyWith(
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.mutedForeground,
    ),
  );

  Widget _categorySelect() {
    return Select<IntakeCategory>(
      value: _category,
      placeholder: Text(context.i18n.supportIntakeCategoryPlaceholder),
      itemBuilder: (c, value) => Text(_categoryLabel(value)),
      popup: SelectPopup(
        items: SelectItemList(
          children: IntakeCategory.values
              .map((c) => SelectItemButton(value: c, child: Text(_categoryLabel(c))))
              .toList(growable: false),
        ),
      ).call,
      onChanged: _setCategory,
    );
  }

  String _categoryLabel(IntakeCategory category) {
    final i18n = context.i18n;
    return switch (category) {
      IntakeCategory.trainerApp => i18n.supportIntakeCategoryTrainerApp,
      IntakeCategory.controller => i18n.supportIntakeCategoryController,
      IntakeCategory.smartTrainer => i18n.supportIntakeCategorySmartTrainer,
      IntakeCategory.account => i18n.supportIntakeCategoryAccount,
      IntakeCategory.somethingElse => i18n.supportIntakeCategorySomethingElse,
    };
  }

  List<Widget> _buildFollowUp() {
    final category = _category!;
    switch (category) {
      case IntakeCategory.trainerApp:
        // Skip the "Which app?" dropdown when the user has already chosen a
        // trainer app in settings — _setCategory() pre-fills _subcategoryValue.
        final preselectedApp = core.settings.getTrainerApp();
        return [
          if (preselectedApp == null) ...[
            _label(context.i18n.supportIntakeWhichApp),
            const Gap(4),
            _stringSelect(
              value: _subcategoryValue,
              placeholder: context.i18n.supportIntakeWhichAppPlaceholder,
              options: trainerAppOptions().map((o) => (id: o.id, label: o.label)).toList(),
              onChanged: _setSubcategory,
            ),
            const Gap(12),
          ],
          _label(context.i18n.supportIntakeWhatHappens),
          const Gap(4),
          _symptomSelect(IntakeCategory.trainerApp, trainerAppSymptoms),
        ];
      case IntakeCategory.controller:
        // Restrict to controllers the user actually has paired so the list
        // is short and obvious. Fall back to the full catalogue when no
        // controller is connected — the user may be reporting "controller
        // won't pair at all" and still needs to pick one.
        final connectedIds = core.connection.controllerDevices
            .where((d) => d.isConnected)
            .map(controllerOptionIdFor)
            .whereType<String>()
            .toSet();
        final options =
            (connectedIds.isEmpty
                    ? controllerOptions
                    : controllerOptions.where((o) => connectedIds.contains(o.id) || o.id == 'other'))
                .map((o) => (id: o.id, label: controllerOptionLabel(context.i18n, o.id)))
                .toList(growable: false);
        return [
          _label(context.i18n.supportIntakeWhichController),
          const Gap(4),
          _stringSelect(
            value: _subcategoryValue,
            placeholder: context.i18n.supportIntakeWhichControllerPlaceholder,
            options: options,
            onChanged: _setSubcategory,
          ),
          const Gap(12),
          _label(context.i18n.supportIntakeWhatHappens),
          const Gap(4),
          _symptomSelect(IntakeCategory.controller, controllerSymptomsFor(_subcategoryValue)),
        ];
      case IntakeCategory.smartTrainer:
        return [
          _label(context.i18n.supportIntakeWhatHappens),
          const Gap(4),
          _stringSelect(
            value: _subcategoryValue,
            placeholder: context.i18n.supportIntakeWhatHappensPlaceholder,
            options: _symptomOptions(IntakeCategory.smartTrainer, smartTrainerSymptoms),
            onChanged: _setSubcategory,
          ),
        ];
      case IntakeCategory.account:
        return [
          _label(context.i18n.supportIntakeAccountQuestion),
          const Gap(4),
          _stringSelect(
            value: _subcategoryValue,
            placeholder: context.i18n.supportIntakeWhatHappensPlaceholder,
            options: _symptomOptions(IntakeCategory.account, accountSymptoms),
            onChanged: _setSubcategory,
          ),
        ];
      case IntakeCategory.somethingElse:
        return const [];
    }
  }

  List<({String id, String label})> _symptomOptions(IntakeCategory category, List<SymptomOption> options) =>
      options.map((o) => (id: o.id, label: symptomLabel(context.i18n, category, o.id))).toList(growable: false);

  Widget _symptomSelect(IntakeCategory category, List<SymptomOption> options) {
    return _stringSelect(
      value: _symptom,
      placeholder: context.i18n.supportIntakeWhatHappensPlaceholder,
      options: _symptomOptions(category, options),
      onChanged: _setSymptom,
    );
  }

  Widget _stringSelect({
    required String? value,
    required String placeholder,
    required List<({String id, String label})> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Select<String>(
      value: value,
      placeholder: Text(placeholder),
      itemBuilder: (c, v) => Text(
        options
            .firstWhere(
              (o) => o.id == v,
              orElse: () => (id: v, label: v),
            )
            .label,
      ),
      popup: SelectPopup(
        items: SelectItemList(
          children: options.map((o) => SelectItemButton(value: o.id, child: Text(o.label))).toList(growable: false),
        ),
      ).call,
      onChanged: onChanged,
    );
  }
}

/// The help-center answer matching the intake choice, inline, with "Did this
/// solve it?" — Yes closes, No continues to the composer.
class _InlineSelfHelp extends StatelessWidget {
  const _InlineSelfHelp({
    super.key,
    required this.help,
    required this.controllerId,
    required this.onNotSolved,
    this.onSolved,
    this.trainer,
  });

  final IntakeSelfHelp help;

  /// The controller chosen in the form, if any — the "isn't found" checks
  /// depend on it.
  final String? controllerId;
  final VoidCallback onNotSolved;
  final VoidCallback? onSolved;

  /// Resolves the trainer the self-test and overlay actions open.
  final ProxyDevice? Function()? trainer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.i18n;
    final proxy = (trainer ?? _knownTrainer)();
    final connectedTrainer = proxy != null && proxy.isConnected ? proxy : null;
    void openNetworkTest() => context.push(const NetworkTroubleshootingPage());
    void openOverlay() => context.push(overlaySettingsDestination(proxy!));
    final (
      IconData icon,
      String title,
      String body,
      List<HelpCheck> checks,
      List<(Key?, IconData, String, VoidCallback)> actions,
      String? note,
    ) = switch (help) {
      IntakeSelfHelp.controllerNotFound => (
        LucideIcons.bluetoothSearching,
        l10n.helpCenterControllerNotFoundEntry,
        l10n.helpAnswerChecksIntro,
        controllerNotFoundChecks(l10n, controllerId: controllerId),
        const <(Key?, IconData, String, VoidCallback)>[],
        null,
      ),
      IntakeSelfHelp.controllerDisconnecting => (
        LucideIcons.bluetoothOff,
        l10n.helpCenterControllerDisconnectingEntry,
        l10n.helpAnswerControllerDisconnectingBody,
        const <HelpCheck>[],
        [
          (
            null,
            LucideIcons.refreshCw,
            l10n.helpAnswerControllerDisconnectingAction,
            () => launchUrlString(
              'https://bikecontrol.app/blog/zwift-click-v2-with-other-trainer-apps',
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
        null,
      ),
      IntakeSelfHelp.appNotReacting => (
        LucideIcons.radioTower,
        l10n.helpAnswerAppNotReactingTitle,
        l10n.helpAnswerChecksIntro,
        appNotReactingChecksWithActions(
          l10n,
          onNetworkTest: openNetworkTest,
          onOverlay: proxy != null ? openOverlay : null,
        ),
        const <(Key?, IconData, String, VoidCallback)>[],
        null,
      ),
      IntakeSelfHelp.trainerAppGear => (
        LucideIcons.eye,
        l10n.helpCenterGearOverlayEntry,
        l10n.helpAnswerGearBody,
        const <HelpCheck>[],
        [
          if (proxy != null) (null, LucideIcons.layers, l10n.helpAnswerGearOverlayAction, openOverlay),
          (null, LucideIcons.radioTower, l10n.intakeSelfHelpNetworkAction, openNetworkTest),
        ],
        null,
      ),
      IntakeSelfHelp.networkTest => (
        LucideIcons.radioTower,
        l10n.helpCenterNetworkEntry,
        l10n.intakeSelfHelpNetworkBody,
        const <HelpCheck>[],
        [(null, LucideIcons.radioTower, l10n.intakeSelfHelpNetworkAction, openNetworkTest)],
        null,
      ),
      // The self-test needs a live trainer: run it directly when there is
      // one, otherwise say to connect it first.
      IntakeSelfHelp.trainerSelfTest => (
        LucideIcons.activity,
        l10n.intakeSelfHelpSelfTestTitle,
        l10n.intakeSelfHelpSelfTestBody,
        const <HelpCheck>[],
        [
          if (connectedTrainer != null)
            (
              const ValueKey('intake-run-self-test'),
              LucideIcons.activity,
              l10n.intakeSelfHelpSelfTestAction,
              () => context.push(ProxyDeviceDetailsPage(device: connectedTrainer, revealSelfTest: true)),
            ),
        ],
        connectedTrainer == null ? l10n.helpSelfTestNeedsTrainer : null,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.supportIntakeTryThisFirst,
            // Foreground on the muted fill: muted text there is below 4.5:1.
            style: context.typography.xSmall.copyWith(fontWeight: FontWeight.w600, color: cs.foreground),
          ),
          const Gap(8),
          Row(
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const Gap(8),
              Expanded(child: Text(title, style: context.typography.small.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
          const Gap(6),
          Text(body, style: context.typography.xSmall.copyWith(color: cs.foreground, height: 1.35)),
          if (checks.isNotEmpty) ...[const Gap(10), HelpCheckList(checks: checks, tileColor: cs.card)],
          if (note != null) ...[
            const Gap(8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, size: 14, color: cs.mutedForeground),
                const Gap(6),
                Expanded(child: Text(note, style: context.typography.xSmall.copyWith(height: 1.35))),
              ],
            ),
          ],
          for (final (actionKey, actionIcon, label, onPressed) in actions) ...[
            const Gap(8),
            Align(
              alignment: Alignment.centerLeft,
              child: Button.outline(
                key: actionKey,
                style: ButtonStyle.outline(size: ButtonSize.small),
                onPressed: onPressed,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(actionIcon, size: 14), const Gap(6), Flexible(child: Text(label))],
                ),
              ),
            ),
          ],
          const Gap(14),
          Text(l10n.supportIntakeDidThisSolveIt, style: context.typography.small.copyWith(fontWeight: FontWeight.w600)),
          const Gap(8),
          // Equal weight: both outline, same size; side by side when both fit
          // on one line, else stacked full width.
          _SolvedAnswers(
            yes: onSolved == null
                ? null
                : BkTouchTarget(
                    child: Button.outline(
                      alignment: Alignment.center,
                      onPressed: onSolved,
                      child: Text(l10n.supportIntakeSolvedYes, maxLines: 1, softWrap: false),
                    ),
                  ),
            no: BkTouchTarget(
              child: Button.outline(
                alignment: Alignment.center,
                onPressed: onNotSolved,
                child: Text(l10n.supportIntakeSolvedNo, maxLines: 1, softWrap: false),
              ),
            ),
            labels: [if (onSolved != null) l10n.supportIntakeSolvedYes, l10n.supportIntakeSolvedNo],
          ),
        ],
      ),
    );
  }

  /// The trainer the self-test and overlay actions open: a connected one if
  /// any, else any known one.
  static ProxyDevice? _knownTrainer() {
    final trainers = core.connection.proxyDevices;
    return trainers.where((t) => t.isConnected).firstOrNull ?? trainers.firstOrNull;
  }
}

/// The "Did this solve it?" answers: a row of equal halves when the longer
/// label fits in half the width, otherwise a full-width stack.
class _SolvedAnswers extends StatelessWidget {
  const _SolvedAnswers({required this.yes, required this.no, required this.labels});

  final Widget? yes;
  final Widget no;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final yes = this.yes;
    if (yes == null) return Align(alignment: Alignment.centerRight, child: no);
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = DefaultTextStyle.of(context).style.merge(context.typography.small);
        final scaler = MediaQuery.textScalerOf(context);
        var widest = 0.0;
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout();
          if (painter.width > widest) widest = painter.width;
          painter.dispose();
        }
        // Button padding and the gap between the two, with some slack.
        final half = (constraints.maxWidth - 8) / 2;
        final sideBySide = widest + 48 * Theme.of(context).scaling <= half;
        if (sideBySide) {
          return Row(
            children: [
              Expanded(child: yes),
              const Gap(8),
              Expanded(child: no),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [yes, const Gap(8), no],
        );
      },
    );
  }
}

class _RecommendedHelp extends StatelessWidget {
  final List<SupportIssue> issues;

  const _RecommendedHelp({required this.issues});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.accent.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.lightbulb, size: 14, color: cs.mutedForeground),
              const Gap(6),
              Text(
                context.i18n.supportIntakeRecommendedHelp,
                style: context.typography.xSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.mutedForeground,
                ),
              ),
            ],
          ),
          const Gap(8),
          for (final issue in issues) ...[
            Text(issue.title, style: context.typography.small.copyWith(fontWeight: FontWeight.w500)),
            if ((issue.description ?? '').isNotEmpty) ...[
              const Gap(2),
              Text(
                issue.description!,
                style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Gap(6),
            Row(
              children: [
                if ((issue.helpBlogSlug ?? '').isNotEmpty)
                  Button(
                    style: ButtonStyle.outline(size: ButtonSize.small),
                    onPressed: () => launchUrlString(
                      'https://bikecontrol.app/blog/${issue.helpBlogSlug}',
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.bookOpen, size: 12),
                        const Gap(4),
                        Text(context.i18n.supportIntakeReadTutorial),
                      ],
                    ),
                  ),
                if ((issue.helpVideoUrl ?? '').isNotEmpty) ...[
                  const Gap(6),
                  Button(
                    style: ButtonStyle.outline(size: ButtonSize.small),
                    onPressed: () => launchUrlString(
                      issue.helpVideoUrl!,
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.play, size: 12),
                        const Gap(4),
                        Text(context.i18n.supportIntakeWatchVideo),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (issue != issues.last) const Gap(12),
          ],
        ],
      ),
    );
  }
}

/// Compact summary chip rendered above the composer once the form has been
/// submitted but the first message hasn't been sent yet.
class SupportIntakeSummaryChip extends StatelessWidget {
  final IntakeAnswers answers;
  final VoidCallback? onEdit;

  const SupportIntakeSummaryChip({super.key, required this.answers, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[
      _categoryLabel(context, answers.category),
      if (answers.subcategoryValue case final value?) _subcategoryLabel(context, answers.category, value),
      if (answers.symptom case final symptom?) symptomLabel(context.i18n, answers.category, symptom),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.clipboardList, size: 14, color: cs.mutedForeground),
          const Gap(8),
          Expanded(
            child: Text(
              parts.join('  ·  '),
              style: context.typography.small.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          if (onEdit != null)
            Button(
              style: ButtonStyle.ghost(size: ButtonSize.small),
              onPressed: onEdit,
              child: Text(context.i18n.supportIntakeEdit),
            ),
        ],
      ),
    );
  }

  static String _categoryLabel(BuildContext context, IntakeCategory category) {
    final i18n = context.i18n;
    return switch (category) {
      IntakeCategory.trainerApp => i18n.supportIntakeCategoryTrainerApp,
      IntakeCategory.controller => i18n.supportIntakeCategoryController,
      IntakeCategory.smartTrainer => i18n.supportIntakeCategorySmartTrainer,
      IntakeCategory.account => i18n.supportIntakeCategoryAccount,
      IntakeCategory.somethingElse => i18n.supportIntakeCategorySomethingElse,
    };
  }

  /// The controller branch stores a controller id, the trainer-app branch
  /// the app's name, and the other branches a symptom id.
  static String _subcategoryLabel(BuildContext context, IntakeCategory category, String value) => switch (category) {
    IntakeCategory.controller => controllerOptionLabel(context.i18n, value),
    IntakeCategory.trainerApp => value,
    _ => symptomLabel(context.i18n, category, value),
  };
}
