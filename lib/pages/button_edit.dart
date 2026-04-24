import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/touch_area.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/custom_keymap_selector.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:dartx/dartx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../bluetooth/devices/base_device.dart';
import '../bluetooth/devices/proxy/proxy_device.dart';

class ButtonEditPage extends StatefulWidget {
  final Keymap keymap;
  final BaseDevice device;
  final KeyPair keyPair;
  final ButtonTrigger trigger;
  final VoidCallback onUpdate;
  const ButtonEditPage({
    super.key,
    required this.keyPair,
    required this.device,
    required this.onUpdate,
    required this.keymap,
    required this.trigger,
  });

  @override
  State<ButtonEditPage> createState() => _ButtonEditPageState();
}

class _ButtonEditPageState extends State<ButtonEditPage> {
  late KeyPair _keyPair;
  late final ScrollController _scrollController = ScrollController();
  final double baseHeight = 46;
  bool _bumped = false;

  void _triggerBump() async {
    setState(() {
      _bumped = true;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    if (mounted) {
      setState(() {
        _bumped = false;
      });
    }
  }

  late StreamSubscription<BaseNotification> _actionSubscription;

  bool get _usesFallbackLongPressMode {
    final button = _keyPair.buttons.firstOrNull;
    if (button == null || widget.trigger != ButtonTrigger.longPress) {
      return false;
    }
    return widget.device.supportsLongPress == false;
  }

  @override
  void initState() {
    super.initState();
    _keyPair = widget.keyPair;
    _keyPair.trigger = widget.trigger;
    _actionSubscription = core.connection.actionStream.listen((data) async {
      if (!mounted) {
        return;
      }
      if (data is ButtonNotification && data.buttonsClicked.length == 1) {
        final clickedButton = data.buttonsClicked.first;
        final keyPair = widget.keymap.getOrCreateKeyPair(clickedButton, trigger: widget.trigger);
        setState(() {
          _keyPair = keyPair;
        });
        _triggerBump();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _actionSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Container(
            constraints: BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.only(right: 26.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 8,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      width: _keyPair.buttons.first.color != null ? baseHeight : null,
                      height: _keyPair.buttons.first.color != null ? baseHeight : null,
                      padding: EdgeInsets.all(_bumped ? 0 : 6.0),
                      constraints: BoxConstraints(maxWidth: 120),
                      child: ButtonWidget(button: _keyPair.buttons.first),
                    ),
                    Expanded(child: SizedBox()),
                    IconButton(
                      icon: Icon(Icons.close),
                      variance: ButtonVariance.ghost,
                      onPressed: () {
                        closeDrawer(context);
                      },
                    ),
                  ],
                ),
                Text('Editing ${widget.trigger.title}').xSmall.muted,
                if (_usesFallbackLongPressMode)
                  Warning(
                    important: false,
                    children: [
                      Text(
                        'This device uses long press toggle mode: first click sends key down, second click sends key up.',
                      ).small,
                    ],
                  ),

                ..._trainerDirectControlSection(),

                if (core.logic.hasNoConnectionMethod)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 300),
                    child: Warning(
                      children: [
                        Text(AppLocalizations.of(context).pleaseSelectAConnectionMethodFirst),
                      ],
                    ),
                  ),
                if (widget.trigger == ButtonTrigger.longPress)
                  Builder(
                    builder: (context) {
                      final singleClickPair = widget.keymap.getKeyPair(
                        _keyPair.buttons.first,
                        trigger: ButtonTrigger.singleClick,
                      );
                      final singleClickLabel = singleClickPair != null && !singleClickPair.hasNoAction
                          ? singleClickPair.toString()
                          : null;
                      return SelectableCard(
                        icon: Icons.repeat,
                        title: Text('Repeat single click action'),
                        isProOnly: true,
                        isActive: _keyPair.hasNoAction,
                        value: _keyPair.hasNoAction ? singleClickLabel : null,
                        onPressed: () {
                          if (!_keyPair.hasNoAction) {
                            _keyPair.physicalKey = null;
                            _keyPair.logicalKey = null;
                            _keyPair.modifiers = [];
                            _keyPair.touchPosition = Offset.zero;
                            _keyPair.inGameAction = null;
                            _keyPair.inGameActionValue = null;
                            _keyPair.androidAction = null;
                            _keyPair.androidIntentAction = null;
                            _keyPair.command = null;
                            _keyPair.screenshotPath = null;
                            setState(() {});
                            widget.onUpdate();
                          }
                        },
                      );
                    },
                  ),
                if (core.logic.showObpActions) ...[
                  ColoredTitle(text: context.i18n.openBikeControlActions),
                  if (core.logic.obpConnectedApp == null)
                    Warning(
                      children: [
                        Text(
                          core.logic.obpConnectedApp == null
                              ? 'Please connect to ${core.settings.getTrainerApp()?.name}, first.'
                              : context.i18n.appIdActions(core.logic.obpConnectedApp!.appId),
                        ),
                      ],
                    )
                  else
                    ..._buildTrainerConnectionActions(core.logic.obpConnectedApp!.supportedActions),
                ],

                if (core.logic.showMyWhooshLink && (Platform.isIOS || core.settings.getMyWhooshLinkEnabled())) ...[
                  SizedBox(height: 8),
                  ColoredTitle(text: context.i18n.myWhooshDirectConnectAction),
                  if (!core.settings.getMyWhooshLinkEnabled())
                    Warning(
                      important: false,
                      children: [
                        Text(AppLocalizations.of(context).enableMywhooshLinkInTheConnectionSettingsFirst),
                      ],
                    )
                  else
                    ..._buildTrainerConnectionActions(core.whooshLink.supportedActions),
                ],
                if (core.logic.showZwiftBleEmulator || core.logic.showZwiftMsdnEmulator) ...[
                  SizedBox(height: 8),
                  ColoredTitle(text: '${core.settings.getTrainerApp()?.name ?? 'Zwift'} Action'),
                  if (!core.settings.getZwiftBleEmulatorEnabled() && !core.settings.getZwiftMdnsEmulatorEnabled())
                    Warning(
                      important: false,
                      children: [
                        Text(AppLocalizations.of(context).enableItInTheConnectionSettingsFirst),
                      ],
                    )
                  else
                    ..._buildTrainerConnectionActions(_mapActions(core.zwiftEmulator.supportedActions)),
                ],

                if (core.logic.showLocalRemoteOptions) ...[
                  SizedBox(height: 8),
                  ColoredTitle(text: 'Local / Remote Setting'),

                  if (core.actionHandler.supportedModes.contains(SupportedMode.keyboard) &&
                      (core.settings.getLocalEnabled() || core.settings.getRemoteKeyboardControlEnabled()))
                    Builder(
                      builder: (context) {
                        return SelectableCard(
                          icon: RadixIcons.keyboard,
                          title: Text(context.i18n.simulateKeyboardShortcut),
                          isActive:
                              _keyPair.physicalKey != null &&
                              !_keyPair.isSpecialKey &&
                              (core.settings.getLocalEnabled() || core.settings.getRemoteKeyboardControlEnabled()),
                          value: _keyPair.toString(),
                          onPressed: () async {
                            await _showModeDropdown(context, SupportedMode.keyboard);
                          },
                        );
                      },
                    ),
                  if (core.actionHandler.supportedModes.contains(SupportedMode.touch) &&
                      (core.settings.getLocalEnabled() || core.settings.getRemoteControlEnabled()))
                    Builder(
                      builder: (context) {
                        return SelectableCard(
                          title: Text(context.i18n.simulateTouch),
                          icon: core.actionHandler is AndroidActions ? Icons.touch_app_outlined : BootstrapIcons.mouse,
                          isActive:
                              ((core.actionHandler is AndroidActions || _keyPair.physicalKey == null) &&
                                  _keyPair.touchPosition != Offset.zero) &&
                              (core.settings.getLocalEnabled() || core.settings.getRemoteControlEnabled()),
                          value: _keyPair.toString(),
                          trailing: IconButton.secondary(
                            icon: Icon(Icons.ondemand_video),
                            onPressed: () {
                              launchUrlString('https://youtube.com/shorts/SvLOQqu2Dqg?feature=share');
                            },
                          ),
                          onPressed: () async {
                            await _showModeDropdown(context, SupportedMode.touch);
                          },
                        );
                      },
                    ),

                  if (core.actionHandler.supportedModes.contains(SupportedMode.media))
                    Builder(
                      builder: (context) => SelectableCard(
                        icon: Icons.music_note_outlined,
                        isActive: _keyPair.isSpecialKey && core.settings.getLocalEnabled(),
                        title: Text(context.i18n.simulateMediaKey),
                        value: _keyPair.toString(),
                        trailing: IconButton.secondary(
                          icon: Icon(Icons.ondemand_video),
                          onPressed: () {
                            launchUrlString('https://youtube.com/shorts/ClY1eTnmAv0?feature=share');
                          },
                        ),
                        onPressed: () {
                          if (!core.settings.getLocalEnabled()) {
                            buildToast(
                              title: AppLocalizations.of(context).enableLocalConnectionMethodFirst,
                            );
                          } else {
                            showDropdown(
                              context: context,
                              builder: (c) => DropdownMenu(
                                children: [
                                  MenuButton(
                                    leading: Icon(Icons.play_arrow_outlined),
                                    onPressed: (c) async {
                                      if (!await IAPManager.instance.ensureProForFeature(
                                        context,
                                        isAllowedForOldPurchases: true,
                                      )) {
                                        return;
                                      }
                                      _keyPair.physicalKey = PhysicalKeyboardKey.mediaPlayPause;
                                      _keyPair.touchPosition = Offset.zero;
                                      _keyPair.logicalKey = null;
                                      _keyPair.androidAction = null;
                                      _keyPair.androidIntentAction = null;
                                      _keyPair.command = null;
                                      _keyPair.screenshotPath = null;

                                      setState(() {});
                                      widget.onUpdate();
                                    },
                                    child: _buildProMenuItemLabel(
                                      context.i18n.playPause,
                                      isAllowedForOldPurchases: true,
                                    ),
                                  ),
                                  MenuButton(
                                    leading: Icon(Icons.stop_outlined),
                                    onPressed: (c) async {
                                      if (!await IAPManager.instance.ensureProForFeature(
                                        context,
                                        isAllowedForOldPurchases: true,
                                      )) {
                                        return;
                                      }
                                      _keyPair.physicalKey = PhysicalKeyboardKey.mediaStop;
                                      _keyPair.touchPosition = Offset.zero;
                                      _keyPair.logicalKey = null;
                                      _keyPair.androidAction = null;
                                      _keyPair.androidIntentAction = null;
                                      _keyPair.command = null;
                                      _keyPair.screenshotPath = null;

                                      setState(() {});
                                      widget.onUpdate();
                                    },
                                    child: _buildProMenuItemLabel(context.i18n.stop, isAllowedForOldPurchases: true),
                                  ),
                                  MenuButton(
                                    leading: Icon(Icons.skip_previous_outlined),
                                    onPressed: (c) async {
                                      if (!await IAPManager.instance.ensureProForFeature(
                                        context,
                                        isAllowedForOldPurchases: true,
                                      )) {
                                        return;
                                      }
                                      _keyPair.physicalKey = PhysicalKeyboardKey.mediaTrackPrevious;
                                      _keyPair.touchPosition = Offset.zero;
                                      _keyPair.logicalKey = null;
                                      _keyPair.androidAction = null;
                                      _keyPair.androidIntentAction = null;
                                      _keyPair.command = null;
                                      _keyPair.screenshotPath = null;

                                      setState(() {});
                                      widget.onUpdate();
                                    },
                                    child: _buildProMenuItemLabel(
                                      context.i18n.previous,
                                      isAllowedForOldPurchases: true,
                                    ),
                                  ),
                                  MenuButton(
                                    leading: Icon(Icons.skip_next_outlined),
                                    onPressed: (c) async {
                                      if (!await IAPManager.instance.ensureProForFeature(
                                        context,
                                        isAllowedForOldPurchases: true,
                                      )) {
                                        return;
                                      }
                                      _keyPair.physicalKey = PhysicalKeyboardKey.mediaTrackNext;
                                      _keyPair.touchPosition = Offset.zero;
                                      _keyPair.logicalKey = null;
                                      _keyPair.androidAction = null;
                                      _keyPair.androidIntentAction = null;
                                      _keyPair.command = null;
                                      _keyPair.screenshotPath = null;

                                      setState(() {});
                                      widget.onUpdate();
                                    },
                                    child: _buildProMenuItemLabel(context.i18n.next, isAllowedForOldPurchases: true),
                                  ),
                                  MenuButton(
                                    leading: Icon(Icons.volume_up_outlined),
                                    onPressed: (c) async {
                                      if (!await IAPManager.instance.ensureProForFeature(
                                        context,
                                        isAllowedForOldPurchases: true,
                                      )) {
                                        return;
                                      }
                                      _keyPair.physicalKey = PhysicalKeyboardKey.audioVolumeUp;
                                      _keyPair.touchPosition = Offset.zero;
                                      _keyPair.logicalKey = null;
                                      _keyPair.androidAction = null;
                                      _keyPair.androidIntentAction = null;
                                      _keyPair.command = null;
                                      _keyPair.screenshotPath = null;

                                      setState(() {});
                                      widget.onUpdate();
                                    },
                                    child: _buildProMenuItemLabel(
                                      context.i18n.volumeUp,
                                      isAllowedForOldPurchases: true,
                                    ),
                                  ),
                                  MenuButton(
                                    leading: Icon(Icons.volume_down_outlined),
                                    child: _buildProMenuItemLabel(
                                      context.i18n.volumeDown,
                                      isAllowedForOldPurchases: true,
                                    ),
                                    onPressed: (c) async {
                                      if (!await IAPManager.instance.ensureProForFeature(
                                        context,
                                        isAllowedForOldPurchases: true,
                                      )) {
                                        return;
                                      }
                                      _keyPair.physicalKey = PhysicalKeyboardKey.audioVolumeDown;
                                      _keyPair.touchPosition = Offset.zero;
                                      _keyPair.logicalKey = null;
                                      _keyPair.androidAction = null;
                                      _keyPair.androidIntentAction = null;
                                      _keyPair.command = null;
                                      _keyPair.screenshotPath = null;

                                      setState(() {});
                                      widget.onUpdate();
                                    },
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  if (core.logic.showLocalControl && core.actionHandler is AndroidActions)
                    Builder(
                      builder: (context) => SelectableCard(
                        icon: Icons.settings_remote_outlined,
                        isActive:
                            _keyPair.androidAction != null &&
                            _keyPair.androidAction != AndroidSystemAction.assistant &&
                            core.settings.getLocalEnabled(),
                        title: Text(AppLocalizations.of(context).androidSystemAction),
                        value: _keyPair.androidAction != AndroidSystemAction.assistant
                            ? _keyPair.androidAction?.title
                            : null,
                        trailing: IconButton.secondary(
                          icon: Icon(Icons.ondemand_video),
                          onPressed: () {
                            launchUrlString('https://youtube.com/shorts/zqD5ARGIVmE?feature=share');
                          },
                        ),
                        onPressed: () {
                          if (!core.settings.getLocalEnabled()) {
                            buildToast(title: context.i18n.enableLocalConnectionMethodFirst);
                          } else {
                            showDropdown(
                              context: context,
                              builder: (c) => DropdownMenu(
                                children: AndroidSystemAction.values
                                    .where((action) => action != AndroidSystemAction.assistant)
                                    .map(
                                      (action) => MenuButton(
                                        leading: Icon(action.icon),
                                        onPressed: (_) async {
                                          if (!await IAPManager.instance.ensureProForFeature(context)) {
                                            return;
                                          }
                                          _keyPair.androidAction = action;
                                          _keyPair.androidIntentAction = null;
                                          _keyPair.physicalKey = null;
                                          _keyPair.logicalKey = null;
                                          _keyPair.modifiers = [];
                                          _keyPair.touchPosition = Offset.zero;
                                          _keyPair.inGameAction = null;
                                          _keyPair.inGameActionValue = null;
                                          _keyPair.command = null;
                                          _keyPair.screenshotPath = null;
                                          setState(() {});
                                          widget.onUpdate();
                                        },
                                        child: _buildProMenuItemLabel(action.title),
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                ],

                if (defaultTargetPlatform == TargetPlatform.android) ...[
                  Builder(
                    builder: (context) => SelectableCard(
                      icon: Icons.assistant_outlined,
                      isActive:
                          _keyPair.androidAction == AndroidSystemAction.assistant && core.settings.getLocalEnabled(),
                      title: Text(AndroidSystemAction.assistant.title),
                      value: _keyPair.androidAction == AndroidSystemAction.assistant
                          ? _keyPair.androidAction?.title
                          : null,
                      isProOnly: true,
                      onPressed: () {
                        _keyPair.androidAction = AndroidSystemAction.assistant;
                        _keyPair.androidIntentAction = null;
                        _keyPair.physicalKey = null;
                        _keyPair.logicalKey = null;
                        _keyPair.modifiers = [];
                        _keyPair.touchPosition = Offset.zero;
                        _keyPair.inGameAction = null;
                        _keyPair.inGameActionValue = null;
                        _keyPair.command = null;
                        _keyPair.screenshotPath = null;
                        setState(() {});
                        widget.onUpdate();
                      },
                    ),
                  ),
                  Builder(
                    builder: (context) => SelectableCard(
                      icon: Icons.broadcast_on_home_outlined,
                      isProOnly: true,
                      isActive: _keyPair.androidIntentAction?.trim().isNotEmpty == true,
                      title: Text('Broadcast Custom Intent'),
                      subtitle: Text('For automation apps like MacroDroid or Tasker').xSmall.muted,
                      value: _keyPair.fullAndroidIntentAction,
                      onPressed: () async {
                        await _showCustomIntentDialog(context);
                      },
                    ),
                  ),
                ],

                if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isIOS)) ...[
                  SizedBox(height: 8),
                  ColoredTitle(text: 'Other Actions'),
                  SelectableCard(
                    isProOnly: true,
                    title: Text(Platform.isMacOS || Platform.isIOS ? 'Launch Shortcut' : 'Run Command'),
                    icon: Platform.isMacOS || Platform.isIOS ? Icons.rocket_launch_outlined : Icons.terminal,
                    isActive: _keyPair.command?.trim().isNotEmpty == true,
                    value: _keyPair.command,
                    onPressed: () async {
                      await _showCommandDialog(context);
                    },
                  ),
                  if (Platform.isMacOS || Platform.isWindows)
                    SelectableCard(
                      isProOnly: true,
                      title: Text('Take Screenshot'),
                      icon: Icons.image_outlined,
                      isActive: _keyPair.screenshotPath?.trim().isNotEmpty == true,
                      value: _keyPair.screenshotPath,
                      onPressed: () async {
                        await _showScreenshotDialog();
                      },
                    ),
                ],

                if (core.connection.accessories.isNotEmpty) ...[
                  SizedBox(height: 8),
                  ColoredTitle(text: 'Accessory Actions'),
                  Builder(
                    builder: (context) => SelectableCard(
                      icon: Icons.air,
                      title: Text('KICKR Headwind'),
                      isActive:
                          _keyPair.inGameAction != null &&
                          (_keyPair.inGameAction == InGameAction.headwindSpeed ||
                              _keyPair.inGameAction == InGameAction.headwindSpeedInc ||
                              _keyPair.inGameAction == InGameAction.headwindSpeedDec ||
                              _keyPair.inGameAction == InGameAction.headwindSpeedCyclicInc ||
                              _keyPair.inGameAction == InGameAction.headwindSpeedCyclicDec ||
                              _keyPair.inGameAction == InGameAction.headwindHeartRateMode),
                      value: _keyPair.inGameAction != null
                          ? '${_keyPair.inGameAction} ${_keyPair.inGameActionValue ?? ""}'.trim()
                          : null,
                      onPressed: () {
                        showDropdown(
                          context: context,
                          builder: (c) => DropdownMenu(
                            children: [
                              MenuButton(
                                subMenu: [0, 25, 50, 75, 100]
                                    .map(
                                      (value) => MenuButton(
                                        child: Text('Set Speed to $value%'),
                                        onPressed: (_) {
                                          _keyPair.inGameAction = InGameAction.headwindSpeed;
                                          _keyPair.inGameActionValue = value;
                                          _keyPair.androidAction = null;
                                          _keyPair.androidIntentAction = null;
                                          _keyPair.command = null;
                                          _keyPair.screenshotPath = null;
                                          widget.onUpdate();
                                          setState(() {});
                                        },
                                      ),
                                    )
                                    .toList(),
                                child: Text('Set Speed'),
                              ),
                              MenuButton(
                                child: Text('Increase Speed'),
                                onPressed: (_) {
                                  _keyPair.inGameAction = InGameAction.headwindSpeedInc;
                                  _keyPair.inGameActionValue = null;
                                  _keyPair.androidAction = null;
                                  _keyPair.androidIntentAction = null;
                                  _keyPair.command = null;
                                  _keyPair.screenshotPath = null;
                                  widget.onUpdate();
                                  setState(() {});
                                },
                              ),
                              MenuButton(
                                child: Text('Decrease Speed'),
                                onPressed: (_) {
                                  _keyPair.inGameAction = InGameAction.headwindSpeedDec;
                                  _keyPair.inGameActionValue = null;
                                  _keyPair.androidAction = null;
                                  _keyPair.androidIntentAction = null;
                                  _keyPair.command = null;
                                  _keyPair.screenshotPath = null;
                                  widget.onUpdate();
                                  setState(() {});
                                },
                              ),
                              MenuButton(
                                child: Text('Increase Speed Cyclically'),
                                onPressed: (_) {
                                  _keyPair.inGameAction = InGameAction.headwindSpeedCyclicInc;
                                  _keyPair.inGameActionValue = null;
                                  _keyPair.androidAction = null;
                                  _keyPair.androidIntentAction = null;
                                  _keyPair.command = null;
                                  _keyPair.screenshotPath = null;
                                  widget.onUpdate();
                                  setState(() {});
                                },
                              ),
                              MenuButton(
                                child: Text('Decrease Speed Cyclically'),
                                onPressed: (_) {
                                  _keyPair.inGameAction = InGameAction.headwindSpeedCyclicDec;
                                  _keyPair.inGameActionValue = null;
                                  _keyPair.androidAction = null;
                                  _keyPair.androidIntentAction = null;
                                  _keyPair.command = null;
                                  _keyPair.screenshotPath = null;
                                  widget.onUpdate();
                                  setState(() {});
                                },
                              ),
                              MenuButton(
                                child: Text('Set to Heart Rate Mode'),
                                onPressed: (_) {
                                  _keyPair.inGameAction = InGameAction.headwindHeartRateMode;
                                  _keyPair.inGameActionValue = null;
                                  _keyPair.androidAction = null;
                                  _keyPair.androidIntentAction = null;
                                  _keyPair.command = null;
                                  _keyPair.screenshotPath = null;
                                  widget.onUpdate();
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                SizedBox(height: 8),
                ColoredTitle(text: context.i18n.setting),
                SizedBox(height: 8),
                DestructiveButton(
                  onPressed: () {
                    _keyPair.physicalKey = null;
                    _keyPair.logicalKey = null;
                    _keyPair.modifiers = [];
                    _keyPair.touchPosition = Offset.zero;
                    _keyPair.inGameAction = null;
                    _keyPair.inGameActionValue = null;
                    _keyPair.androidAction = null;
                    _keyPair.androidIntentAction = null;
                    _keyPair.command = null;
                    _keyPair.screenshotPath = null;
                    widget.onUpdate();
                    setState(() {});
                  },
                  child: Text(context.i18n.unassignAction),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _trainerDirectControlSection() {
    final proxy = core.connection.proxyDevices.whereType<ProxyDevice>().where((d) => d.isConnected).firstOrNull;
    if (proxy == null) return const [];
    return [
      SizedBox(height: 8),
      ColoredTitle(text: '${proxy.name} Direct Control'),
      for (final action in trainerActions)
        SelectableCard(
          icon: action.icon,
          title: Text(action.title),
          isActive: _keyPair.inGameAction == action,
          onPressed: () {
            _keyPair.touchPosition = Offset.zero;
            _keyPair.physicalKey = null;
            _keyPair.logicalKey = null;
            _keyPair.androidAction = null;
            _keyPair.androidIntentAction = null;
            _keyPair.command = null;
            _keyPair.screenshotPath = null;
            _keyPair.inGameAction = action;
            _keyPair.inGameActionValue = null;
            widget.onUpdate();
            setState(() {});
          },
        ),
      SizedBox(height: 8),
    ];
  }

  List<InGameAction> _mapActions(List<InGameAction> actions) {
    final mapping = core.settings.getTrainerApp()?.inGameActionsMapping ?? const {};
    return actions.map((a) => mapping[a] ?? a).toList();
  }

  List<Widget> _buildTrainerConnectionActions(List<InGameAction> supportedActions) {
    return supportedActions.map((action) {
      return Builder(
        builder: (context) {
          return SelectableCard(
            icon: action.icon,
            title: Text(action.title),
            subtitle: (action.possibleValues != null && action == _keyPair.inGameAction)
                ? Text(_keyPair.inGameActionValue!.toString())
                : action.alternativeTitle != null
                ? Text(action.alternativeTitle!)
                : null,
            isActive: _keyPair.inGameAction == action && supportedActions.contains(_keyPair.inGameAction),
            onPressed: () {
              if (action.possibleValues?.isNotEmpty == true) {
                showDropdown(
                  context: context,
                  builder: (c) => DropdownMenu(
                    children: action.possibleValues!.map(
                      (ingame) {
                        return MenuButton(
                          child: Text(ingame.toString()),
                          onPressed: (_) {
                            _keyPair.touchPosition = Offset.zero;
                            _keyPair.physicalKey = null;
                            _keyPair.logicalKey = null;
                            _keyPair.androidAction = null;
                            _keyPair.androidIntentAction = null;
                            _keyPair.command = null;
                            _keyPair.screenshotPath = null;
                            _keyPair.inGameAction = action;
                            _keyPair.inGameActionValue = ingame;
                            widget.onUpdate();
                            setState(() {});
                          },
                        );
                      },
                    ).toList(),
                  ),
                );
              } else {
                _keyPair.touchPosition = Offset.zero;
                _keyPair.physicalKey = null;
                _keyPair.logicalKey = null;
                _keyPair.androidAction = null;
                _keyPair.androidIntentAction = null;
                _keyPair.command = null;
                _keyPair.screenshotPath = null;
                _keyPair.inGameAction = action;
                _keyPair.inGameActionValue = null;
                widget.onUpdate();
                setState(() {});
              }
            },
          );
        },
      );
    }).toList();
  }

  Future<void> _showCommandDialog(BuildContext context) async {
    if (Platform.isWindows) {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select command to run',
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null) {
        return;
      }
      final selectedPath = result.files.single.path?.trim();
      if (selectedPath == null || selectedPath.isEmpty) {
        buildToast(title: 'No executable file selected');
        return;
      }
      _setCommand(selectedPath);
      return;
    }

    final controller = TextEditingController(text: _keyPair.command ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SafeArea(
        child: AlertDialog(
          title: Text('Launch Shortcut'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              TextField(
                controller: controller,
                hintText: 'Shortcut name',
                autofocus: true,
                onTapOutside: (_) {
                  FocusScope.of(context).unfocus();
                },
              ),
              if (Platform.isMacOS)
                Text('Runs a macOS Shortcuts shortcut by its exact name when this button is pressed.').small
              else
                Text(
                  'Note that Shortcuts on iOS are very limited: BikeControl needs to be in the foreground when you want to run the command, and your shortcut should have "Open BikeControl" as its first action so BikeControl can continue to trigger shortcuts.',
                ).xSmall,
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.i18n.cancel),
            ),
            if (_keyPair.command?.trim().isNotEmpty == true)
              TextButton(
                onPressed: () => Navigator.pop(context, ''),
                child: Text('Clear'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) {
      return;
    }

    final shortcutName = result.trim();
    _setCommand(shortcutName.isEmpty ? null : shortcutName);
  }

  void _setCommand(String? value) {
    _keyPair.command = value;

    if (_keyPair.command != null) {
      _keyPair.screenshotPath = null;
      _keyPair.physicalKey = null;
      _keyPair.logicalKey = null;
      _keyPair.modifiers = [];
      _keyPair.touchPosition = Offset.zero;
      _keyPair.inGameAction = null;
      _keyPair.inGameActionValue = null;
      _keyPair.androidAction = null;
      _keyPair.androidIntentAction = null;
    }

    widget.onUpdate();
    setState(() {});
  }

  Future<void> _showScreenshotDialog() async {
    final selectedPath = Directory.current.path;

    final path = selectedPath.trim();
    if (path.isEmpty) {
      buildToast(title: 'No path selected');
      return;
    }

    final hasWriteAccess = await _ensureScreenshotDirectoryWritable(path);
    if (!hasWriteAccess) {
      buildToast(title: 'Cannot write to this folder. Please grant write permission and try again.');
      return;
    }

    _setScreenshotPath(path);
  }

  Future<bool> _ensureScreenshotDirectoryWritable(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final testFile = File(
        '${directory.path}${Platform.pathSeparator}.bikecontrol-write-test-${DateTime.now().microsecondsSinceEpoch}',
      );
      await testFile.writeAsString('ok', flush: true);
      if (await testFile.exists()) {
        await testFile.delete();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void _setScreenshotPath(String? value) {
    _keyPair.screenshotPath = value;

    if (_keyPair.screenshotPath != null) {
      _keyPair.command = null;
      _keyPair.physicalKey = null;
      _keyPair.logicalKey = null;
      _keyPair.modifiers = [];
      _keyPair.touchPosition = Offset.zero;
      _keyPair.inGameAction = null;
      _keyPair.inGameActionValue = null;
      _keyPair.androidAction = null;
      _keyPair.androidIntentAction = null;
    }

    widget.onUpdate();
    setState(() {});
  }

  Future<void> _showCustomIntentDialog(BuildContext context) async {
    final controller = TextEditingController(text: _keyPair.androidIntentAction ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SafeArea(
        child: AlertDialog(
          title: Text('Broadcast Custom Intent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 8,
                children: [
                  Text(KeyPair.intentActionPrefix).muted,
                  Expanded(
                    child: TextField(
                      controller: controller,
                      hintText: 'one',
                      autofocus: true,
                      onTapOutside: (_) {
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                ],
              ),
              Text(
                'Sends an Android broadcast with action "${KeyPair.intentActionPrefix}<your suffix>" when the button is pressed. '
                'Apps like MacroDroid or Tasker can listen for the intent and run your automations.',
              ).xSmall,
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.i18n.cancel),
            ),
            if (_keyPair.androidIntentAction?.trim().isNotEmpty == true)
              TextButton(
                onPressed: () => Navigator.pop(context, ''),
                child: Text('Clear'),
              ),
            TextButton(
              onPressed: () async {
                if (!await IAPManager.instance.ensureProForFeature(context)) {
                  return;
                }
                if (context.mounted) Navigator.pop(context, controller.text);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) {
      return;
    }

    var action = result.trim();
    if (action.startsWith(KeyPair.intentActionPrefix)) {
      action = action.substring(KeyPair.intentActionPrefix.length);
    }
    _setAndroidIntentAction(action.isEmpty ? null : action);
  }

  void _setAndroidIntentAction(String? value) {
    _keyPair.androidIntentAction = value;

    if (_keyPair.androidIntentAction != null) {
      _keyPair.command = null;
      _keyPair.screenshotPath = null;
      _keyPair.physicalKey = null;
      _keyPair.logicalKey = null;
      _keyPair.modifiers = [];
      _keyPair.touchPosition = Offset.zero;
      _keyPair.inGameAction = null;
      _keyPair.inGameActionValue = null;
      _keyPair.androidAction = null;
    }

    widget.onUpdate();
    setState(() {});
  }

  Widget _buildProMenuItemLabel(String text, {bool isAllowedForOldPurchases = false}) {
    final isPro =
        IAPManager.instance.hasActiveSubscription ||
        (isAllowedForOldPurchases && IAPManager.instance.hasPurchasedBefore50RVC);
    if (isPro) {
      return Text(text);
    }

    return Row(
      children: [
        Expanded(child: Text(text)),
        const ProBadge(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          fontSize: 9,
        ),
      ],
    );
  }

  Future<void> _showModeDropdown(BuildContext context, SupportedMode supportedMode) async {
    final trainerApp = core.settings.getTrainerApp();

    final triggerForPredefined = widget.trigger == ButtonTrigger.doubleClick
        ? ButtonTrigger.singleClick
        : widget.trigger;
    final actionsWithInGameAction =
        [
          ...?trainerApp?.keymap.keyPairs
              .where((kp) => kp.trigger == triggerForPredefined)
              .distinctBy((kp) => kp.inGameAction),
          ...?trainerApp?.additionalKeyPairs,
        ].where(
          (kp) =>
              kp.inGameAction != null &&
              switch (supportedMode) {
                SupportedMode.keyboard => kp.physicalKey != null,
                SupportedMode.touch => kp.touchPosition != Offset.zero,
                SupportedMode.media => kp.isSpecialKey,
              },
        );

    final isEnabled =
        supportedMode == SupportedMode.keyboard &&
            (core.settings.getLocalEnabled() || core.settings.getRemoteKeyboardControlEnabled()) ||
        supportedMode == SupportedMode.touch &&
            (core.settings.getLocalEnabled() || core.settings.getRemoteControlEnabled()) ||
        supportedMode == SupportedMode.media && core.settings.getLocalEnabled();

    if (!isEnabled) {
      return buildToast(
        title: AppLocalizations.of(context).enableLocalConnectionMethodFirst,
      );
    } else if (actionsWithInGameAction.isNotEmpty) {
      showDropdown(
        context: context,
        builder: (c) => DropdownMenu(
          children: [
            MenuLabel(child: Text(context.i18n.predefinedAction(trainerApp?.name ?? 'App'))),
            ...actionsWithInGameAction.map((keyPairAction) {
              return MenuButton(
                leading: keyPairAction.inGameAction?.icon != null ? Icon(keyPairAction.inGameAction!.icon) : null,
                onPressed: (_) {
                  // Copy all properties from the selected predefined action
                  if (core.actionHandler.supportedModes.contains(SupportedMode.keyboard)) {
                    _keyPair.physicalKey = keyPairAction.physicalKey;
                    _keyPair.logicalKey = keyPairAction.logicalKey;
                    _keyPair.modifiers = List.of(keyPairAction.modifiers);
                  } else {
                    _keyPair.physicalKey = null;
                    _keyPair.logicalKey = null;
                    _keyPair.modifiers = [];
                  }
                  if (core.actionHandler.supportedModes.contains(SupportedMode.touch)) {
                    _keyPair.touchPosition = keyPairAction.touchPosition;
                  } else {
                    _keyPair.touchPosition = Offset.zero;
                  }
                  _keyPair.inGameAction = keyPairAction.inGameAction;
                  _keyPair.inGameActionValue = keyPairAction.inGameActionValue;
                  _keyPair.androidAction = null;
                  _keyPair.androidIntentAction = null;
                  _keyPair.command = keyPairAction.command;
                  _keyPair.screenshotPath = keyPairAction.screenshotPath;
                  setState(() {});
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      keyPairAction.inGameActionValue != null
                          ? keyPairAction.buttons.first.name
                          : keyPairAction.inGameAction?.title ?? '',
                    ),
                    Text(switch (supportedMode) {
                      SupportedMode.keyboard => keyPairAction.logicalKey?.keyLabel ?? 'Not assigned',
                      SupportedMode.touch =>
                        'X:${keyPairAction.touchPosition.dx.toInt()}, Y:${keyPairAction.touchPosition.dy.toInt()}',
                      SupportedMode.media => throw UnimplementedError(),
                    }).muted.small,
                  ],
                ),
              );
            }),
            MenuDivider(),
            MenuLabel(child: Text('Custom ${supportedMode.name.capitalize()} action')),
            MenuButton(
              leading: Icon(Icons.edit_outlined),
              onPressed: (_) {
                _editAction(supportedMode);
              },
              child: Text('Custom'),
            ),
          ],
        ),
      );
    } else {
      _editAction(supportedMode);
    }
  }

  Future<void> _editAction(SupportedMode supportedMode) async {
    if (supportedMode == SupportedMode.keyboard) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false, // enable Escape key
        builder: (c) => HotKeyListenerDialog(
          customApp: core.actionHandler.supportedApp! as CustomApp,
          keyPair: _keyPair,
          trigger: widget.trigger,
        ),
      );
      _keyPair.androidAction = null;
      _keyPair.androidIntentAction = null;
      _keyPair.command = null;
      _keyPair.screenshotPath = null;
      setState(() {});
      widget.onUpdate();
    } else if (supportedMode == SupportedMode.touch) {
      if (_keyPair.touchPosition == Offset.zero) {
        _keyPair.touchPosition = Offset(50, 50);
      }
      _keyPair.physicalKey = null;
      _keyPair.logicalKey = null;
      _keyPair.androidAction = null;
      _keyPair.androidIntentAction = null;
      _keyPair.command = null;
      _keyPair.screenshotPath = null;
      await context.push(TouchAreaSetupPage(keyPair: _keyPair));
      setState(() {});
      widget.onUpdate();
    }
  }
}

class SelectableCard extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final bool isActive;
  final String? value;
  final VoidCallback? onPressed;
  final bool isProOnly;

  const SelectableCard({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
    required this.isActive,
    this.value,
    required this.onPressed,
    this.isProOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPro = IAPManager.instance.hasActiveSubscription;

    return Stack(
      children: [
        Button.outline(
          style:
              ButtonStyle(
                    variance: ButtonVariance.outline,
                  )
                  .withBorder(
                    border: isActive
                        ? Border.all(color: BKColor.main, width: 2)
                        : Border.all(color: Theme.of(context).colorScheme.border, width: 2),
                    hoverBorder: Border.all(color: BKColor.mainEnd, width: 2),
                    focusBorder: Border.all(color: BKColor.main, width: 2),
                  )
                  .withBackgroundColor(
                    color: isActive
                        ? Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.card
                              : Theme.of(context).colorScheme.card.withLuminance(0.97)
                        : Theme.of(context).colorScheme.background,
                    hoverColor: Theme.of(context).colorScheme.border.withLuminance(0.94),
                  ),
          onPressed: () async {
            if (isProOnly && !isPro) {
              await showGoProDialog(context);
            } else {
              onPressed?.call();
            }
          },
          alignment: Alignment.topLeft,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Basic(
              leadingAlignment: Alignment.centerLeft,
              leading: icon != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 3.0),
                      child: Icon(
                        icon,
                        color: icon == Icons.delete_outline ? Theme.of(context).colorScheme.destructive : null,
                      ),
                    )
                  : null,
              title: title,
              subtitle: value != null && isActive ? Text(value!) : subtitle,
              trailing: trailing,
            ),
          ),
        ),
        if (isProOnly && !isPro)
          Positioned(
            top: 0,
            right: 0,
            child: const ProBadge(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
          ),
      ],
    );
  }
}
