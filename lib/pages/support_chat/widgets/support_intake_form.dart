import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SupportIntakeForm extends StatefulWidget {
  final SupportChatService service;
  final IntakeAnswers? initial;
  final ValueChanged<IntakeAnswers> onContinue;

  const SupportIntakeForm({
    super.key,
    required this.service,
    required this.onContinue,
    this.initial,
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
      _subcategoryValue = null;
      _symptom = null;
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Gap(4),
          Text(
            context.i18n.supportIntakeSubtitle,
            style: TextStyle(color: cs.mutedForeground, fontSize: 13),
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
          Align(
            alignment: Alignment.centerRight,
            child: Button.primary(
              onPressed: canContinue
                  ? () => widget.onContinue(_buildAnswers())
                  : null,
              child: Text(context.i18n.supportIntakeContinue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
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
    };
  }

  List<Widget> _buildFollowUp() {
    final category = _category!;
    switch (category) {
      case IntakeCategory.trainerApp:
        return [
          _label(context.i18n.supportIntakeWhichApp),
          const Gap(4),
          _stringSelect(
            value: _subcategoryValue,
            placeholder: context.i18n.supportIntakeWhichAppPlaceholder,
            options: trainerAppOptions().map((o) => (id: o.id, label: o.label)).toList(),
            onChanged: _setSubcategory,
          ),
          const Gap(12),
          _label(context.i18n.supportIntakeWhatHappens),
          const Gap(4),
          _symptomSelect(trainerAppSymptoms),
        ];
      case IntakeCategory.controller:
        return [
          _label(context.i18n.supportIntakeWhichController),
          const Gap(4),
          _stringSelect(
            value: _subcategoryValue,
            placeholder: context.i18n.supportIntakeWhichControllerPlaceholder,
            options: controllerOptions
                .map((o) => (id: o.id, label: o.label))
                .toList(growable: false),
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
            options: smartTrainerSymptoms
                .map((o) => (id: o.id, label: o.label))
                .toList(growable: false),
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
            options: accountSymptoms
                .map((o) => (id: o.id, label: o.label))
                .toList(growable: false),
            onChanged: _setSubcategory,
          ),
        ];
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
        options.firstWhere(
          (o) => o.id == v,
          orElse: () => (id: v, label: v),
        ).label,
      ),
      popup: SelectPopup(
        items: SelectItemList(
          children: options
              .map((o) => SelectItemButton(value: o.id, child: Text(o.label)))
              .toList(growable: false),
        ),
      ).call,
      onChanged: onChanged,
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.mutedForeground,
                ),
              ),
            ],
          ),
          const Gap(8),
          for (final issue in issues) ...[
            Text(issue.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            if ((issue.description ?? '').isNotEmpty) ...[
              const Gap(2),
              Text(
                issue.description!,
                style: TextStyle(fontSize: 12, color: cs.mutedForeground),
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
    };
  }

  static String _prettify(String id) {
    final pretty = id.replaceAll('_', ' ');
    if (pretty.isEmpty) return id;
    return pretty[0].toUpperCase() + pretty.substring(1);
  }
}
