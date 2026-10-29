import 'package:bike_control/pages/onboarding/steps/step_app.dart' show TrainerAppGrid;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_bottom_sheet.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Popover width: wide enough for the grid's five columns
/// ([Breakpoints.onboardingAppGridWide]) plus the padding around it.
const double _popoverWidth = Breakpoints.onboardingAppGridWide + 2 * 16;

/// Lets the rider pick their trainer app from the same tile grid onboarding
/// shows: a bottom sheet on a phone-sized window, a popover under [context]
/// (the Change button) in a wider one. Resolves to the picked app, or null when
/// the rider closed it without picking.
Future<SupportedApp?> openTrainerAppPicker(BuildContext context) {
  if (isCompactWindow(context)) {
    return openBottomSheet<SupportedApp>(
      context: context,
      builder: (sheetContext) => _TrainerAppPickerBody(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        onSelect: (app) => closeDrawer(sheetContext, app),
      ),
    );
  }
  return showPopover<SupportedApp>(
    context: context,
    alignment: AlignmentDirectional.topEnd,
    anchorAlignment: AlignmentDirectional.bottomEnd,
    offset: const Offset(0, 8),
    // The page's ground colour, not a card's: the tiles are cards and would
    // vanish on one.
    builder: (popoverContext) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(popoverContext).colorScheme.background,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        border: Border.all(color: Theme.of(popoverContext).colorScheme.border),
        boxShadow: bkCardShadow(popoverContext),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _popoverWidth,
          minWidth: _popoverWidth,
          maxHeight: MediaQuery.sizeOf(popoverContext).height * 0.7,
        ),
        child: _TrainerAppPickerBody(
          padding: const EdgeInsets.all(16),
          onSelect: (app) => closeOverlay(popoverContext, app),
        ),
      ),
    ),
  ).future;
}

class _TrainerAppPickerBody extends StatelessWidget {
  const _TrainerAppPickerBody({required this.padding, required this.onSelect});

  final EdgeInsets padding;
  final ValueChanged<SupportedApp> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('trainer-app-picker'),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.i18n.onboardingAppTitle).large.semiBold,
          const Gap(14),
          TrainerAppGrid(selected: core.settings.getTrainerApp(), onSelect: onSelect),
        ],
      ),
    );
  }
}
