import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/pages/activity/activity_preview.dart';
import 'package:bike_control/pages/devices/devices_page.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/settings/settings_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/controller/trigger_assignment_popup.dart';
import 'package:bike_control/widgets/feedback_prompt/feedback_prompt_flow.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../main.dart';

export 'package:bike_control/pages/activity/activity_log.dart' show activityLogClock;

/// Whether the activity log is on screen: its own section, or Ride's
/// permanent column in a window of at least [Breakpoints.activityColumn].
bool activityLogVisible({required AppSection section, required double screenWidth}) =>
    section == AppSection.activity || (section == AppSection.ride && screenWidth >= Breakpoints.activityColumn);

/// Decides whether an incoming alert should raise a toast.
///
/// The base rule shows a toast unless the overview is frontmost AND the
/// activity log, where the alert is logged, is already on screen. On top of
/// that, a connection-type alert is suppressed whenever Ride's connection
/// card is visible — the card already reflects connect/disconnect state, and
/// a toast there just covers its buttons. The activity-log entry is inserted
/// regardless of this decision.
@visibleForTesting
bool shouldShowConnectionAlertToast({
  required bool screenshotMode,
  required bool overviewFrontmost,
  required double screenWidth,
  required AppSection section,
  required bool isConnectionAlert,
}) {
  final logVisible = activityLogVisible(section: section, screenWidth: screenWidth);
  final baseShow = !screenshotMode && (!overviewFrontmost || !logVisible);
  final connectionCardVisible = overviewFrontmost && section == AppSection.ride;
  return baseShow && !(isConnectionAlert && connectionCardVisible);
}

/// The content area of the main screen: the selected section, with the
/// activity log beside Ride in wide windows. Also owns what runs for the
/// whole session on this screen: the activity log's feed, the keep-awake,
/// the feedback prompt and the alert toasts.
///
/// Every section stays mounted (offstage when not selected), so switching is
/// instant and each keeps its scroll position and state.
class OverviewPage extends StatefulWidget {
  final bool isMobile;

  /// Shared with the shell's navigation chrome. Created here when omitted.
  final ShellController? shell;

  const OverviewPage({super.key, required this.isMobile, this.shell});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> with WidgetsBindingObserver {
  late StreamSubscription<BaseNotification> _actionListener;
  late StreamSubscription<BaseDevice> _connectionListener;

  late double _screenWidth;
  bool _isInForeground = true;

  ShellController? _ownShell;
  ShellController get _shell => widget.shell ?? (_ownShell ??= ShellController());
  ActivityLogController get _log => _shell.activity;

  /// Ride's "Show" → the setup cards on Devices.
  final ChainRevealController _reveal = ChainRevealController();

  void _onProxyStateChanged() {
    if (mounted) setState(() {});
  }

  late final FeedbackPromptTrigger _feedbackPromptTrigger;

  @override
  void initState() {
    super.initState();

    _feedbackPromptTrigger = FeedbackPromptTrigger(
      service: core.feedbackPromptService,
      onShow: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showFeedbackPromptFlow(context, service: core.feedbackPromptService);
        });
      },
    )..checkInitial();

    // keep screen on - this is required for iOS to keep the bluetooth connection alive
    if (!screenshotMode) {
      WakelockPlus.enable();
    }

    _actionListener = core.connection.actionStream.listen((notification) {
      if (notification is ActionNotification && notification.result.button != null) {
        _onActionResult(notification.result, notification.result.button!);
      } else if (notification is AlertNotification) {
        _onAlert(notification);
      }
    });
    _connectionListener = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });

    for (final proxy in core.connection.proxyDevices) {
      proxy.isStarting.addListener(_onProxyStateChanged);
      proxy.isConnectedListenable.addListener(_onProxyStateChanged);
    }

    WidgetsBinding.instance.addObserver(this);

    if (!kIsWeb) {
      if (core.logic.showForegroundMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // show snackbar to inform user that the app needs to stay in foreground
          buildToast(title: AppLocalizations.current.touchSimulationForegroundMessage);
        });
      }

      core.whooshLink.isStarted.addListener(_onProxyStateChanged);
      core.zwiftEmulator.isConnected.addListener(_onProxyStateChanged);
    }
  }

  @override
  void didChangeDependencies() {
    _screenWidth = MediaQuery.sizeOf(context).width;
    super.didChangeDependencies();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _isInForeground;
    _isInForeground = state == AppLifecycleState.resumed;
    if (_isInForeground != wasForeground && mounted) setState(() {});

    if (state == AppLifecycleState.resumed) {
      if (core.logic.showForegroundMessage) {
        UniversalBle.getBluetoothAvailabilityState().then((state) {
          if (state == AvailabilityState.poweredOn && mounted) {
            core.remotePairing.reconnect();
            buildToast(title: AppLocalizations.current.touchSimulationForegroundMessage);
          }
        });
      }
    }
  }

  bool get _logOnScreen => activityLogVisible(section: _shell.section.value, screenWidth: _screenWidth);

  void _onActionResult(ActionResult result, ControllerButton button) {
    // A saved screen recording gets a "reveal" action on its activity entry:
    // open the containing folder on desktop, or the gallery on mobile.
    final savedPath = result is Success ? result.filePath : null;
    final hasRecording = savedPath != null && savedPath.isNotEmpty && !kIsWeb;
    final isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows);
    final entry = ActivityEntry(
      button: button,
      time: activityNow(),
      result: result,
      deviceName: _deviceNameFor(button),
      buttonTitle: hasRecording
          ? (isDesktop ? AppLocalizations.of(context).openFolder : AppLocalizations.of(context).openGallery)
          : null,
      onTap: hasRecording ? () => _openRecordingLocation(savedPath) : null,
    );
    _log.insert(entry);

    if (entry.isError) {
      // Not during onboarding: the wizard asks the rider to press a button
      // precisely while the trainer app or the keymap is not set up yet, so
      // every one of those presses fails by design. Toasting "X could not be
      // performed" over the step that told them to press it reads as the
      // wizard being broken. The entry is still logged to the activity list.
      if (!onboardingActive && !_logOnScreen) {
        final fix = _errorFixAction(entry);
        buildToast(
          level: LogLevel.LOGLEVEL_WARNING,
          title: result.message,
          closeTitle: fix?.$1 ?? AppLocalizations.of(context).close,
          onClose: fix?.$2 != null
              ? () {
                  fix?.$2(context);
                }
              : null,
        );
      }
    }
  }

  /// The controller a press came from, by the id the button carries, else the
  /// first controller that has a button of that name.
  String? _deviceNameFor(ControllerButton button) {
    final controllers = core.connection.controllerDevices;
    final device =
        controllers.where((d) => d.uniqueId == button.sourceDeviceId).firstOrNull ??
        controllers.where((d) => d.availableButtons.any((b) => b.name == button.name)).firstOrNull;
    return device?.displayName(context);
  }

  /// Reveals a saved recording: the containing folder in Finder / Explorer on
  /// desktop, or the system gallery on mobile (where it was saved via `gal`).
  Future<void> _openRecordingLocation(String filePath) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [File(filePath).parent.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [File(filePath).parent.path]);
      } else {
        await Gal.open();
      }
    } catch (e, s) {
      recordError(e, s, context: 'open recording location');
    }
  }

  void _onAlert(AlertNotification notification) {
    final isInForeground = navigatorKey.currentState?.canPop() == false;

    if (shouldShowConnectionAlertToast(
      screenshotMode: screenshotMode,
      overviewFrontmost: isInForeground,
      screenWidth: _screenWidth,
      section: _shell.section.value,
      isConnectionAlert: notification.connectionType != null,
    )) {
      buildToast(
        level: notification.level,
        title: notification.alertMessage,
        closeTitle: notification.buttonTitle ?? AppLocalizations.current.close,
        onClose: notification.onTap,
      );
    }

    _log.insert(
      ActivityEntry(
        time: activityNow(),
        alertMessage: notification.alertMessage,
        alertLevel: notification.level,
        buttonTitle: notification.buttonTitle,
        onTap: notification.onTap,
        connectionType: notification.connectionType,
      ),
    );
  }

  @override
  void dispose() {
    if (!screenshotMode) {
      WakelockPlus.disable();
    }
    WidgetsBinding.instance.removeObserver(this);
    _feedbackPromptTrigger.dispose();

    _actionListener.cancel();
    for (final proxy in core.connection.proxyDevices) {
      proxy.isStarting.removeListener(_onProxyStateChanged);
      proxy.isConnectedListenable.removeListener(_onProxyStateChanged);
    }
    if (!kIsWeb) {
      core.whooshLink.isStarted.removeListener(_onProxyStateChanged);
      core.zwiftEmulator.isConnected.removeListener(_onProxyStateChanged);
    }
    _connectionListener.cancel();
    _reveal.dispose();
    _ownShell?.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSection>(
      valueListenable: _shell.section,
      builder: (context, selected, _) => Stack(
        fit: StackFit.expand,
        children: [
          for (final section in AppSection.values)
            Offstage(
              offstage: section != selected,
              child: TickerMode(
                enabled: section == selected,
                // Ride and Devices both draw the controller's buttons, and a
                // hero tag may only fly from one of them.
                child: HeroMode(
                  enabled: section == selected,
                  child: KeyedSubtree(key: ValueKey(section), child: _section(section)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(AppSection section) {
    return switch (section) {
      AppSection.ride => _ride(),
      AppSection.devices => _scroll(
        'devices',
        DevicesPage(isMobile: widget.isMobile, onUpdate: _update, reveal: _reveal),
      ),
      AppSection.activity => _scroll(
        'activity',
        ActivityLogView(controller: _log, fixAction: _errorFixAction, showHeader: false),
      ),
      AppSection.settings => _scroll('settings', SettingsPage(onUpdate: _update)),
    };
  }

  /// A section's scroll view: the content in one column no wider than
  /// [maxWidth] (720; Ride, which splits in two, gets more).
  Widget _scroll(String id, Widget child, {bool tight = false, double maxWidth = 720}) {
    final compact = _screenWidth < Breakpoints.compact;
    final h = tight ? 0.0 : (compact ? 12.0 : 24.0);
    return SingleChildScrollView(
      key: PageStorageKey('section-$id'),
      padding: EdgeInsets.fromLTRB(h, compact ? 4 : 8, h, 24),
      // Centred under the medium window's tab bar; from 840 it starts under
      // the page title, beside the sidebar.
      child: Align(
        alignment: _screenWidth >= Breakpoints.medium ? Alignment.topLeft : Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }

  Widget _ride() {
    final showColumn = _screenWidth >= Breakpoints.activityColumn;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _scroll(
            'ride',
            HomePage(
              isMobile: widget.isMobile,
              // From 840 the sidebar carries Help & Support.
              showHelpRow: _screenWidth < Breakpoints.medium,
              onUpdate: _update,
              reveal: _reveal,
              onShowSetup: () => _shell.select(AppSection.devices),
              // Between the sidebar and the activity column, Ride's right
              // column carries the latest few events.
              activityPreview: _screenWidth >= Breakpoints.medium && !showColumn
                  ? RideActivityPreview(
                      controller: _log,
                      onSeeAll: () => _shell.select(AppSection.activity),
                    )
                  : null,
            ),
            maxWidth: 1080,
          ),
        ),
        if (showColumn)
          Container(
            key: const ValueKey('activity-column'),
            width: (_screenWidth * 0.28).clamp(320.0, 420.0),
            decoration: BoxDecoration(
              color: bkSunkenSurface(context),
              border: Border(left: BorderSide(color: cs.border, width: 0.5)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 12, top: 16, bottom: 16),
              child: ActivityLogView(controller: _log, fixAction: _errorFixAction),
            ),
          ),
      ],
    );
  }

  // ── Activity fixes ────────────────────────────────────────────────

  Future<void> _openTrainerConnectionSettings() async {
    await context.push(const TrainerConnectionSettingsPage());
    _update();
  }

  (String, void Function(BuildContext))? _errorFixAction(ActivityEntry entry) {
    final result = entry.result;
    if (result is! Error) return null;
    final button = entry.button;
    if (button == null) return null;

    final device = core.connection.controllerDevices
        .where((d) => d.availableButtons.any((b) => b.name == button.name))
        .firstOrNull;

    return switch (result.type) {
      ErrorType.noActionAssigned || ErrorType.noKeymapSet => (
        AppLocalizations.of(context).configureButtonMapping,
        (context) {
          if (device != null) {
            showTriggerAssignmentPopup(
              context: context,
              device: device,
              button: button,
              keymap: core.actionHandler.supportedApp!.keymap,
              onUpdate: _update,
            );
          } else {
            _openTrainerConnectionSettings();
          }
        },
      ),
      ErrorType.noConnectionMethod || ErrorType.trainerNotConnected => (
        context.i18n.openConnectionSettings,
        (context) => _openTrainerConnectionSettings(),
      ),
      ErrorType.proRequired => (AppLocalizations.of(context).goPro, (context) => showGoProDialog(context)),
      ErrorType.headwindNotConnected => (
        'Connect Headwind fan',
        (context) {}, // no dedicated page
      ),
      ErrorType.other => null,
      ErrorType.deviceRegistrationNeeded => ('Register device', (context) => openSubscription(context)),
    };
  }
}
