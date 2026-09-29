import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/trainer.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TrainerConnectionSettingsPage extends StatefulWidget {
  const TrainerConnectionSettingsPage({super.key});

  @override
  State<TrainerConnectionSettingsPage> createState() => _TrainerConnectionSettingsPageState();
}

class _TrainerConnectionSettingsPageState extends State<TrainerConnectionSettingsPage> {
  bool get _missingTarget {
    final trainerApp = core.settings.getTrainerApp();
    return trainerApp != null && trainerApp is! BikeControl && core.settings.getLastTarget() == null;
  }

  Future<bool> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final trainerName = core.settings.getTrainerApp()?.name ?? l10n.yourTrainerApp;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.noTargetSelected),
        content: Text(l10n.needsTargetLeavePrompt(trainerName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.stay),
          ),
          DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_missingTarget,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _confirmLeave();
        if (!shouldLeave) return;
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        headers: [
          BkPageHeader(
            title: AppLocalizations.of(context).connectionSettings,
            actions: [
              if (core.settings.getTrainerApp()?.connections.any((e) => e.$2 == ConnectionSupport.experimental) ??
                  false)
                Builder(
                  builder: (context) {
                    return BkIconButton.ghost(
                      icon: Icon(
                        LucideIcons.ellipsisVertical,
                        size: 22,
                        color: Theme.of(context).colorScheme.mutedForeground,
                      ),
                      label: context.i18n.a11yMoreOptions,
                      tooltip: false,
                      onPressed: () {
                        showDropdown(
                          context: context,
                          builder: (c) => DropdownMenu(
                            children: [
                              MenuCheckbox(
                                value: core.settings.getShowExperimental(),
                                child: Text(AppLocalizations.of(context).showExperimental),
                                onChanged: (c, value) {
                                  core.settings.setShowExperimental(value);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TrainerPage(
                onUpdate: () {
                  setState(() {});
                },
                goToNextPage: () {},
                isMobile: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Target Device ────────────────────────────────────────────────────
}

/// The in-app language picker. A [Select] over "System default" (follow the OS
/// language) plus every supported locale, each labelled by its native name
/// (endonym), reading/writing [core.settings.setLocaleOverride]. Lives under
/// Settings → App.
class LanguageSelect extends StatefulWidget {
  /// Called after the language changes so the host can rebuild (the app itself
  /// rebuilds via [Settings.localeListenable]).
  final VoidCallback onChanged;

  /// Just the picker, for a settings row that brings its own icon and label.
  final bool bare;
  const LanguageSelect({super.key, required this.onChanged, this.bare = false});

  @override
  State<LanguageSelect> createState() => _LanguageSelectState();
}

class _LanguageSelectState extends State<LanguageSelect> {
  /// Sentinel value for the "System default" entry (Select needs a non-null
  /// value; null there would read as "no selection / show placeholder").
  static const String _systemValue = '';

  /// Endonyms — each language shown in its own script, intentionally NOT
  /// translated so a rider can always recognise their language in the list.
  static const Map<String, String> _nativeNames = {
    'en': 'English',
    'de': 'Deutsch',
    'es': 'Español',
    'it': 'Italiano',
    'fr': 'Français',
    'pl': 'Polski',
  };

  String _label(String code) =>
      code == _systemValue ? AppLocalizations.of(context).languageSystemDefault : (_nativeNames[code] ?? code);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final codes = <String>[
      _systemValue,
      ...AppLocalizations.delegate.supportedLocales.map((e) => e.languageCode),
    ];
    final current = core.settings.getLocaleOverride() ?? _systemValue;
    final select = Select<String>(
      constraints: const BoxConstraints(maxWidth: 240, minWidth: 200),
      popupConstraints: const BoxConstraints(maxWidth: 240, minWidth: 200),
      itemBuilder: (context, code) => Text(_label(code)),
      popup: SelectPopup(
        items: SelectItemList(
          children: [
            for (final code in codes)
              SelectItemButton(
                value: code,
                child: code == current ? Text(_label(code)).semiBold : Text(_label(code)),
              ),
          ],
        ),
      ).call,
      value: current,
      onChanged: (code) async {
        await core.settings.setLocaleOverride(
          (code == null || code == _systemValue) ? null : code,
        );
        if (mounted) setState(() {});
        widget.onChanged();
      },
    );
    if (widget.bare) return select;
    return Row(
      children: [
        Icon(LucideIcons.languages, size: 20, color: Theme.of(context).colorScheme.mutedForeground),
        const Gap(12),
        Expanded(child: Text(l10n.language).semiBold),
        select,
      ],
    );
  }
}
