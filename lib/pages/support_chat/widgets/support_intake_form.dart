import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:bike_control/utils/support/intake_self_help.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SupportIntakeForm extends StatefulWidget {
  final SupportChatService service;
  final IntakeAnswers? initial;
  final ValueChanged<IntakeAnswers> onContinue;

  /// "Did this solve it?" → Yes, for an answer shown inline. Null hides the
  /// question (the rider can still continue to the composer).
  final VoidCallback? onSolved;

  const SupportIntakeForm({
    super.key,
    required this.service,
    required this.onContinue,
    this.initial,
    this.onSolved,
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
          _symptomSelect(trainerAppSymptoms),
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
                .map((o) => (id: o.id, label: o.label))
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
          _symptomSelect(controllerSymptoms),
        ];
      case IntakeCategory.smartTrainer:
        return [
          _label(context.i18n.supportIntakeWhatHappens),
          const Gap(4),
          _stringSelect(
            value: _subcategoryValue,
            placeholder: context.i18n.supportIntakeWhatHappensPlaceholder,
            options: smartTrainerSymptoms.map((o) => (id: o.id, label: o.label)).toList(growable: false),
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
            options: accountSymptoms.map((o) => (id: o.id, label: o.label)).toList(growable: false),
            onChanged: _setSubcategory,
          ),
        ];
      case IntakeCategory.somethingElse:
        return const [];
    }
  }

  Widget _symptomSelect(List<SymptomOption> options) {
    return _stringSelect(
      value: _symptom,
      placeholder: context.i18n.supportIntakeWhatHappensPlaceholder,
      options: options.map((o) => (id: o.id, label: o.label)).toList(growable: false),
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
  const _InlineSelfHelp({super.key, required this.help, required this.onNotSolved, this.onSolved});

  final IntakeSelfHelp help;
  final VoidCallback onNotSolved;
  final VoidCallback? onSolved;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.i18n;
    final proxy = _knownTrainer();
    void openNetworkTest() => context.push(const NetworkTroubleshootingPage());
    final (IconData icon, String title, String body, List<(IconData, String, VoidCallback)> actions) = switch (help) {
      IntakeSelfHelp.controllerNotFound => (
        LucideIcons.bluetoothSearching,
        l10n.helpCenterControllerNotFoundEntry,
        l10n.helpAnswerControllerNotFoundBody,
        const <(IconData, String, VoidCallback)>[],
      ),
      IntakeSelfHelp.controllerDisconnecting => (
        LucideIcons.bluetoothOff,
        l10n.helpCenterControllerDisconnectingEntry,
        l10n.helpAnswerControllerDisconnectingBody,
        [
          (
            LucideIcons.refreshCw,
            l10n.helpAnswerControllerDisconnectingAction,
            () => launchUrlString(
              'https://bikecontrol.app/blog/zwift-click-v2-with-other-trainer-apps',
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      IntakeSelfHelp.trainerAppGear => (
        LucideIcons.eye,
        l10n.helpCenterGearOverlayEntry,
        l10n.helpAnswerGearBody,
        [
          if (proxy != null)
            (
              LucideIcons.layers,
              l10n.helpAnswerGearOverlayAction,
              () => context.push(ProxyDeviceDetailsPage(device: proxy, revealOverlaySection: true)),
            ),
          (LucideIcons.radioTower, l10n.intakeSelfHelpNetworkAction, openNetworkTest),
        ],
      ),
      IntakeSelfHelp.networkTest => (
        LucideIcons.radioTower,
        l10n.helpCenterNetworkEntry,
        l10n.intakeSelfHelpNetworkBody,
        [(LucideIcons.radioTower, l10n.intakeSelfHelpNetworkAction, openNetworkTest)],
      ),
      IntakeSelfHelp.trainerSelfTest => (
        LucideIcons.activity,
        l10n.intakeSelfHelpSelfTestTitle,
        l10n.intakeSelfHelpSelfTestBody,
        [
          if (proxy != null)
            (
              LucideIcons.activity,
              l10n.intakeSelfHelpSelfTestAction,
              () => context.push(ProxyDeviceDetailsPage(device: proxy, revealSelfTest: true)),
            ),
        ],
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
            style: context.typography.xSmall.copyWith(fontWeight: FontWeight.w600, color: cs.mutedForeground),
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
          Text(body, style: context.typography.xSmall.copyWith(color: cs.mutedForeground, height: 1.35)),
          for (final (actionIcon, label, onPressed) in actions) ...[
            const Gap(8),
            Align(
              alignment: Alignment.centerLeft,
              child: Button.outline(
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
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onSolved != null) Button.outline(onPressed: onSolved, child: Text(l10n.supportIntakeSolvedYes)),
              Button.primary(onPressed: onNotSolved, child: Text(l10n.supportIntakeSolvedNo)),
            ],
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
      if (answers.subcategoryValue != null) _prettify(answers.subcategoryValue!),
      if (answers.symptom != null) _prettify(answers.symptom!),
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

  static String _prettify(String id) {
    final pretty = id.replaceAll('_', ' ');
    if (pretty.isEmpty) return id;
    return pretty[0].toUpperCase() + pretty.substring(1);
  }
}
