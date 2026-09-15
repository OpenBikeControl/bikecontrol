import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ignored_devices_dialog.dart';
import 'package:bike_control/widgets/trainer_features.dart';
import 'package:bike_control/services/screen_recording/screen_recording_service.dart';
import 'package:bike_control/services/shift_feedback/shift_haptics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The settings that used to hang off the controllers card: extra scanning
/// options, the media-key and phone-steering toggles, and the ignored-devices
/// list.
///
/// They are real features, but none of them answers "am I ready to ride", so
/// they sit below the chain in a collapsed section instead of competing with
/// it. Nothing is removed — it is only moved out of the way.
class HomeExtras extends StatefulWidget {
  const HomeExtras({super.key, required this.isMobile, required this.onUpdate});

  final bool isMobile;
  final VoidCallback onUpdate;

  @override
  State<HomeExtras> createState() => _HomeExtrasState();
}

class _HomeExtrasState extends State<HomeExtras> {
  // Open by default: what's in here is short, and a collapsed section on a
  // screen the rider is already scrolling only hides it.
  bool _expanded = true;

  bool get _showsMediaKeys => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isIOS);

  bool get _showsPhoneSteering => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Phone-side shift feedback. Sound has a backend on every desktop/mobile
  /// OS we ship; vibration needs a haptics engine, so phones/tablets only.
  bool get _showsShiftSound => !kIsWeb;

  bool get _showsShiftHaptics => PlatformShiftHaptics.isSupported;

  /// Quitting from a menu row is a mobile idiom; desktop windows close
  /// themselves, and SystemNavigator.pop() does nothing useful there anyway.
  bool get _showsQuit => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ignored = core.settings.getIgnoredDevices();

    return Container(
      decoration: ShapeDecoration(
        color: theme.colorScheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.border, width: 1.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Button.ghost(
            style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(LucideIcons.settings2, size: 16, color: theme.colorScheme.mutedForeground),
                  const Gap(9),
                  Expanded(
                    child: Text(
                      context.i18n.chainMoreOptions,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  // A recording in progress has to stay visible even while this
                  // section is collapsed, so it sits in the header row.
                  ValueListenableBuilder<ScreenRecordingState>(
                    valueListenable: core.screenRecording.state,
                    builder: (context, state, _) {
                      if (state != ScreenRecordingState.recording) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                            const Gap(4),
                            Text(context.i18n.screenRecordingStarted).xSmall.muted,
                          ],
                        ),
                      );
                    },
                  ),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 15,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(),
            if (ignored.isNotEmpty)
              _row(
                context,
                title: context.i18n.manageIgnoredDevices,
                trailing: Text('${ignored.length}').xSmall.muted,
                onPressed: () async {
                  await showDialog(context: context, builder: (_) => const IgnoredDevicesDialog());
                  widget.onUpdate();
                  if (mounted) setState(() {});
                },
              ),
            if (_showsMediaKeys)
              ValueListenableBuilder<bool>(
                valueListenable: core.mediaKeyHandler.isMediaKeyDetectionEnabled,
                builder: (context, value, _) => SwitchFeature(
                  isMobile: widget.isMobile,
                  value: value,
                  title: AppLocalizations.of(context).enableMediaKeyDetection,
                  onPressed: () {
                    final enabled = !value;
                    core.mediaKeyHandler.isMediaKeyDetectionEnabled.value = enabled;
                    core.settings.setMediaKeyDetectionEnabled(enabled);
                  },
                ),
              ),
            if (_showsPhoneSteering)
              SwitchFeature(
                isMobile: widget.isMobile,
                value: core.settings.getPhoneSteeringEnabled(),
                isProOnly: !IAPManager.instance.hasPurchasedBefore50RVC,
                title: AppLocalizations.of(context).enableSteeringWithPhone,
                onPressed: () {
                  final enable = !core.settings.getPhoneSteeringEnabled();
                  core.settings.setPhoneSteeringEnabled(enable);
                  core.connection.toggleGyroscopeSteering(enable);
                  widget.onUpdate();
                  if (mounted) setState(() {});
                },
              ),
            if (_showsShiftHaptics)
              SwitchFeature(
                isMobile: widget.isMobile,
                value: core.shiftFeedback.hapticsEnabled,
                title: context.i18n.shiftFeedbackHaptics,
                subtitle: context.i18n.shiftFeedbackHapticsSubtitle,
                onPressed: () async {
                  await core.shiftFeedback.setHapticsEnabled(!core.shiftFeedback.hapticsEnabled);
                  if (mounted) setState(() {});
                },
              ),
            if (_showsShiftSound)
              SwitchFeature(
                isMobile: widget.isMobile,
                value: core.shiftFeedback.soundEnabled,
                title: context.i18n.shiftFeedbackSound,
                subtitle: context.i18n.shiftFeedbackSoundSubtitle,
                onPressed: () async {
                  await core.shiftFeedback.setSoundEnabled(!core.shiftFeedback.soundEnabled);
                  if (mounted) setState(() {});
                },
              ),
            if (_showsQuit)
              _row(
                context,
                title: context.i18n.chainCloseAndQuit,
                onPressed: () async {
                  await core.connection.disconnectAll();
                  await core.connection.stop();
                  SystemNavigator.pop();
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, {required String title, Widget? trailing, required VoidCallback onPressed}) {
    return Button.ghost(
      style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(title).small),
            if (trailing != null) trailing,
            const Gap(6),
            Icon(LucideIcons.chevronRight, size: 14, color: Theme.of(context).colorScheme.mutedForeground),
          ],
        ),
      ),
    );
  }
}
