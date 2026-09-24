import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/home/home_sheets.dart';
import 'package:bike_control/pages/subscription.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/services/blog_service.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/blog_posts_widget.dart';
import 'package:bike_control/widgets/controller/trigger_assignment_popup.dart';
import 'package:bike_control/widgets/feedback_prompt/feedback_prompt_flow.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show ConnectionMethodTypeActivityIcon;
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:prop/prop.dart' show LogLevel, Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../main.dart';

// ── Activity log entry ───────────────────────────────────────────────

class _ActivityEntry {
  final ControllerButton? button;
  final DateTime time;
  final ActionResult? result;
  final String? alertMessage;
  final LogLevel? alertLevel;
  final String? buttonTitle;
  final VoidCallback? onTap;
  final ConnectionMethodType? connectionType;

  _ActivityEntry({
    this.button,
    required this.time,
    this.result,
    this.alertMessage,
    this.alertLevel,
    this.buttonTitle,
    this.onTap,
    this.connectionType,
  });

  bool get isAlert => alertMessage != null;
  bool get isError => result is Error || result is NotHandled || alertLevel == LogLevel.LOGLEVEL_ERROR;
  bool get isSuccess => result is Success;
  bool get isWarning => alertLevel == LogLevel.LOGLEVEL_WARNING;

  String get message => alertMessage ?? result?.message ?? '';
}

// ── OverviewPage ─────────────────────────────────────────────────────

/// The clock the activity log stamps its entries with and ages them by ("just
/// now", "5s ago"). Tests on a fake clock point it there, so the ages they
/// film don't depend on how fast the machine ran.
@visibleForTesting
DateTime Function() activityLogClock = DateTime.now;

/// Decides whether an incoming alert should raise a toast.
///
/// The base (historical) rule shows a toast unless the overview is frontmost
/// AND the relevant surface is already on screen (wide layout, or the mobile
/// cards page). On top of that, a connection-type alert is suppressed whenever
/// the connection card is visible — the card already reflects connect/
/// disconnect state, and a toast there just covers its buttons. Non-connection
/// alerts keep the base behaviour. The activity-log entry is inserted
/// regardless of this decision.
@visibleForTesting
bool shouldShowConnectionAlertToast({
  required bool screenshotMode,
  required bool overviewFrontmost,
  required double screenWidth,
  required double? pageViewPage,
  required bool isConnectionAlert,
}) {
  final page = (pageViewPage ?? 0).round();
  final baseShow = !screenshotMode && (!overviewFrontmost || (screenWidth < 800 && page != 1));
  final connectionCardVisible = overviewFrontmost && (screenWidth >= 800 || page == 0);
  return baseShow && !(isConnectionAlert && connectionCardVisible);
}

class OverviewPage extends StatefulWidget {
  final bool isMobile;
  const OverviewPage({super.key, required this.isMobile});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  late StreamSubscription<BaseNotification> _actionListener;
  late StreamSubscription<BaseDevice> _connectionListener;
  late Timer _timeRefreshTimer;

  late double _screenWidth;

  // Layout keys
  final GlobalKey _activityLogKey = GlobalKey();
  bool _isInForeground = true;

  // Activity log
  final List<_ActivityEntry> _activityLog = [];
  final GlobalKey<AnimatedListState> _activityListKey = GlobalKey<AnimatedListState>();
  static const _maxLogEntries = 30;

  // Blog
  bool _hasNewBlogPosts = false;

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

    _timeRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_activityLog.isNotEmpty) setState(() {});
    });
    _actionListener = core.connection.actionStream.listen((notification) {
      Logger.warn('Notification received: ${notification.runtimeType} - $notification');
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

    // Eagerly fetch blog posts so the "new" indicator shows on the tab immediately.
    BlogService().fetchPosts().then((posts) {
      if (mounted && posts.any((p) => p.isNew)) {
        setState(() => _hasNewBlogPosts = true);
      }
    });

    if (!kIsWeb) {
      if (core.logic.showForegroundMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // show snackbar to inform user that the app needs to stay in foreground
          buildToast(title: AppLocalizations.current.touchSimulationForegroundMessage);
        });
      }

      core.whooshLink.isStarted.addListener(() {
        if (mounted) setState(() {});
      });

      core.zwiftEmulator.isConnected.addListener(() {
        if (mounted) setState(() {});
      });
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

  void _insertActivityEntry(_ActivityEntry entry) {
    _activityLog.insert(0, entry);
    _activityListKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    if (_activityLog.length > _maxLogEntries) {
      final removed = _activityLog.removeLast();
      final removeIndex = _activityLog.length;
      _activityListKey.currentState?.removeItem(
        removeIndex,
        (context, animation) => _buildAnimatedActivityItem(removed, removeIndex, animation),
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  void _onActionResult(ActionResult result, ControllerButton button) {
    // A saved screen recording gets a "reveal" action on its activity entry:
    // open the containing folder on desktop, or the gallery on mobile.
    final savedPath = result is Success ? result.filePath : null;
    final hasRecording = savedPath != null && savedPath.isNotEmpty && !kIsWeb;
    final isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows);
    final entry = _ActivityEntry(
      button: button,
      time: activityLogClock(),
      result: result,
      buttonTitle: hasRecording
          ? (isDesktop ? AppLocalizations.of(context).openFolder : AppLocalizations.of(context).openGallery)
          : null,
      onTap: hasRecording ? () => _openRecordingLocation(savedPath) : null,
    );
    _insertActivityEntry(entry);

    if (entry.isError) {
      // Not during onboarding: the wizard asks the rider to press a button
      // precisely while the trainer app or the keymap is not set up yet, so
      // every one of those presses fails by design. Toasting "X could not be
      // performed" over the step that told them to press it reads as the
      // wizard being broken. The entry is still logged to the activity list.
      if (!onboardingActive && _screenWidth < 800 && _horizontalScrollController.page != 1) {
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
      setState(() {});
    } else {
      setState(() {});
    }
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
      pageViewPage: _horizontalScrollController.hasClients ? _horizontalScrollController.page : null,
      isConnectionAlert: notification.connectionType != null,
    )) {
      buildToast(
        level: notification.level,
        title: notification.alertMessage,
        closeTitle: notification.buttonTitle ?? 'Close',
        onClose: notification.onTap,
      );
    }

    final entry = _ActivityEntry(
      time: activityLogClock(),
      alertMessage: notification.alertMessage,
      alertLevel: notification.level,
      buttonTitle: notification.buttonTitle,
      onTap: notification.onTap,
      connectionType: notification.connectionType,
    );
    _insertActivityEntry(entry);

    setState(() {});
  }

  @override
  void dispose() {
    if (!screenshotMode) {
      WakelockPlus.disable();
    }
    WidgetsBinding.instance.removeObserver(this);
    _horizontalScrollController.dispose();
    _feedbackPromptTrigger.dispose();

    _timeRefreshTimer.cancel();
    _actionListener.cancel();
    for (final proxy in core.connection.proxyDevices) {
      proxy.isStarting.removeListener(_onProxyStateChanged);
      proxy.isConnectedListenable.removeListener(_onProxyStateChanged);
    }
    _connectionListener.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Wide desktop promotes the activity log to a permanent rail, and that rail
    // carries its own Help button — a second one in the chain would be a
    // duplicate of something already on screen.
    final showsActivityRail = _screenWidth >= 800;

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(8),
        HomePage(
          isMobile: widget.isMobile,
          showHelpRow: !showsActivityRail,
          onUpdate: () {
            setState(() {});
          },
        ),
      ],
    );

    final activityColumn = KeyedSubtree(
      key: _activityLogKey,
      child: _buildActivityLog(),
    );

    if (_screenWidth < 800) {
      // Mobile: horizontally scrollable, left side 90% width, activity peeks from right
      final hPad = 12.0;

      return Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.muted,
            width: double.infinity,
            alignment: Alignment.center,
            child: _Tabs(
              controller: _horizontalScrollController,
              leftWidth: _screenWidth - 50,
              hasErrors: _activityLog.any((e) => e.isError),
              hasNewBlogPosts: _hasNewBlogPosts,
              pageCount: 3,
            ),
          ),
          Divider(),
          Expanded(
            child: PageView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              physics: const PageScrollPhysics(),
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: hPad,
                    right: hPad,
                    bottom: widget.isMobile ? MediaQuery.viewPaddingOf(context).bottom + 20 : 0,
                  ),
                  child: leftColumn,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.gray.shade900 : Color(0xFFF8FAFB),
                    border: Border(
                      left: BorderSide(color: Theme.of(context).colorScheme.border, width: 1),
                      bottom: BorderSide(color: Theme.of(context).colorScheme.border, width: 1),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      right: 20,
                      bottom: widget.isMobile ? MediaQuery.viewPaddingOf(context).bottom + 20 : 0,
                    ),
                    child: activityColumn,
                  ),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: 20,
                    bottom: widget.isMobile ? MediaQuery.viewPaddingOf(context).bottom + 20 : 0,
                  ),
                  child: BlogPostsWidget(
                    showHeader: false,
                    maxPosts: 10,
                    onHasNewPosts: (hasNew) {
                      if (hasNew != _hasNewBlogPosts) setState(() => _hasNewBlogPosts = hasNew);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Desktop: the chain in one centred column — it is a sequence, not a grid,
    // so widening it past a comfortable measure only makes it harder to read —
    // with the activity log promoted from a tab to a permanent rail.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(20),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: leftColumn,
              ),
            ),
          ),
        ),
        const Gap(20),
        Container(
          height: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.gray.shade900 : Color(0xFFF8FAFB),
            border: Border(
              left: BorderSide(color: Theme.of(context).colorScheme.border, width: 1),
              bottom: BorderSide(color: Theme.of(context).colorScheme.border, width: 1),
            ),
          ),
          constraints: BoxConstraints(maxWidth: min(500, MediaQuery.sizeOf(context).width * 0.4)),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 20, top: 20, bottom: 20),
                  child: activityColumn,
                ),
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.only(right: 20, top: 8, bottom: 8),
                child: BlogPostsWidget(maxPosts: 4),
              ),
              Divider(),
              // The rail's foot is where a stuck rider is already looking, so
              // Help lives here on desktop instead of at the end of the chain.
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 20, top: 8, bottom: 16),
                child: Button.outline(
                  onPressed: () => openControllerHelpSheet(context),
                  child: Row(
                    children: [
                      Icon(LucideIcons.lifeBuoy, size: 16, color: Theme.of(context).colorScheme.primary),
                      const Gap(9),
                      Expanded(child: Text(context.i18n.chainSomethingNotWorking).small.semiBold),
                      Icon(LucideIcons.chevronRight, size: 14, color: Theme.of(context).colorScheme.mutedForeground),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  late final PageController _horizontalScrollController = PageController();

  // ── Controller card ───────────────────────────────────────────────

  Future<void> _openTrainerConnectionSettings() async {
    await context.push(const TrainerConnectionSettingsPage());
    setState(() {});
  }

  // ── Activity log ────────────────────────────────────────────────────

  Widget _buildActivityLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          children: [
            Gap(16),
            Expanded(
              child: ColoredTitle(text: AppLocalizations.of(context).activity),
            ),
            GhostButton(
              onPressed: _clearActivityLog,
              child: Text(AppLocalizations.of(context).clear).xSmall.muted,
            ),
          ],
        ),
        AnimatedList(
          key: _activityListKey,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          initialItemCount: _activityLog.length,
          itemBuilder: (context, index, animation) {
            return _buildAnimatedActivityItem(_activityLog[index], index, animation);
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedActivityItem(_ActivityEntry entry, int index, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0)
              Divider(
                color: Theme.of(context).colorScheme.border.withAlpha(160),
                endIndent: 16,
                indent: 16,
                thickness: 0.5,
              ),
            _buildActivityRow(entry, isLatest: index == 0),
          ],
        ),
      ),
    );
  }

  void _clearActivityLog() {
    for (int i = _activityLog.length - 1; i >= 0; i--) {
      final entry = _activityLog[i];
      _activityListKey.currentState?.removeItem(
        i,
        (context, animation) => _buildAnimatedActivityItem(entry, i, animation),
        duration: const Duration(milliseconds: 200),
      );
    }
    _activityLog.clear();
    setState(() {});
  }

  Widget _buildActivityRow(_ActivityEntry entry, {required bool isLatest}) {
    final button = entry.button;
    final isError = entry.isError;
    final isSuccess = entry.isSuccess;

    final actionText = entry.message;

    // Time
    final ago = activityLogClock().difference(entry.time);
    final String timeText;
    if (ago.inSeconds < 2) {
      timeText = AppLocalizations.of(context).justNow;
    } else if (ago.inSeconds < 60) {
      timeText = '${ago.inSeconds}s ago';
    } else {
      timeText = '${ago.inMinutes}m ago';
    }

    // Row bg
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color rowBg;
    if (isError) {
      rowBg = isDark ? const Color(0x1AEF4444) : const Color(0xFFFEF2F2);
    } else if (entry.isWarning) {
      rowBg = isDark ? const Color(0x1AF59E0B) : const Color(0xFFFFFBEB);
    } else if (isSuccess) {
      rowBg = isDark ? const Color(0x1A22C55E) : const Color(0xFFF0FDFA);
    } else if (entry.button == null) {
      rowBg = Color(0xFFDBEAFE);
    } else {
      rowBg = Colors.transparent;
    }

    // Error fix action
    final errorFix = _errorFixAction(entry);

    const size = 14.0;
    // Leading icon
    final Widget leadingIcon;
    if (button != null) {
      leadingIcon = isError
          ? const Icon(LucideIcons.circleX, size: 16, color: Color(0xFFEF4444))
          : isSuccess
          ? const Icon(LucideIcons.circleCheck, size: 16, color: Color(0xFF22C55E))
          : ButtonWidget(button: button, size: size - 4);
    } else if (entry.alertLevel == LogLevel.LOGLEVEL_ERROR) {
      leadingIcon = Icon(LucideIcons.circleX, size: 16, color: const Color(0xFFEF4444));
    } else if (entry.alertLevel == LogLevel.LOGLEVEL_WARNING) {
      leadingIcon = Icon(LucideIcons.triangleAlert, size: 16, color: const Color(0xFFF59E0B));
    } else if (entry.button == null) {
      leadingIcon = Icon(
        entry.connectionType?.activityIcon ?? LucideIcons.bluetooth,
        size: 16,
        color: Color(0xFF2563EB),
      );
    } else {
      leadingIcon = Icon(LucideIcons.info, size: 16, color: Theme.of(context).colorScheme.mutedForeground);
    }

    return SizedBox(
      width: double.infinity,
      child: Basic(
        padding: EdgeInsets.all(16),
        leading: Container(
          width: 22,
          height: 24,
          decoration: BoxDecoration(
            color: rowBg,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: leadingIcon,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isError ? Text(actionText, style: TextStyle(color: Color(0xFFEF4444))).small : Text(actionText).small,
            if (errorFix != null) ...[
              Gap(4),
              Builder(
                builder: (context) {
                  return OutlineButton(
                    onPressed: () {
                      errorFix.$2(context);
                    },
                    child: Text(errorFix.$1).xSmall,
                  );
                },
              ),
            ],
            if (entry.onTap != null && entry.buttonTitle != null) ...[
              Gap(4),
              OutlineButton(
                onPressed: entry.onTap!,
                child: Text(entry.buttonTitle!).xSmall,
              ),
            ],
          ],
        ),
        trailing: Text(timeText).xSmall.muted,
      ),
    );
  }

  (String, Function(BuildContext))? _errorFixAction(_ActivityEntry entry) {
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
              onUpdate: () {
                setState(() {});
              },
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
      ErrorType.deviceRegistrationNeeded => (
        'Register device',
        (context) {
          openDrawer(
            context: context,
            builder: (c) => SubscriptionPage(),
            position: OverlayPosition.end,
          );
        },
      ),
    };
  }
}

class _Tabs extends StatefulWidget {
  final PageController controller;
  final double leftWidth;
  final bool hasErrors;
  final bool hasNewBlogPosts;
  final int pageCount;

  const _Tabs({
    super.key,
    required this.controller,
    required this.leftWidth,
    required this.hasErrors,
    this.hasNewBlogPosts = false,
    this.pageCount = 2,
  });

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  @override
  void initState() {
    widget.controller.addListener(_update);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _Tabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasErrors != widget.hasErrors || oldWidget.hasNewBlogPosts != widget.hasNewBlogPosts) {
      setState(() {});
    }
  }

  int get _currentIndex {
    if (!widget.controller.hasClients) return 0;
    final page = widget.controller.page ?? 0;
    return page.round().clamp(0, widget.pageCount - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Tabs(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      onChanged: (index) {
        widget.controller.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      index: _currentIndex,
      children: [
        TabItem(
          child: Text(AppLocalizations.of(context).main),
        ),
        TabItem(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(AppLocalizations.of(context).activity),
              if (widget.hasErrors) ...[
                Gap(6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.destructive.withAlpha(160),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.pageCount >= 3)
          TabItem(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Blog'),
                if (widget.hasNewBlogPosts) ...[
                  Gap(6),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E74B7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  void _update() {
    setState(() {});
  }
}
