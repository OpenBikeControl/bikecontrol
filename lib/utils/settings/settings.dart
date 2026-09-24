import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/settings_sync_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/android.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/windows_store_environment.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale, Offset;
import 'package:path/path.dart' as path;
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:prop/prop.dart' hide Set;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../../main.dart';
import '../keymap/apps/custom_app.dart';
import '../keymap/buttons.dart';

class Settings {
  late SharedPreferences _prefs;
  bool _initialized = false;

  /// Assigning [prefs] (from [init] in production or directly in tests) flips
  /// [_initialized] so guards like [getUseNewUnlockMethod] know prefs are ready
  /// and don't throw on the uninitialised `late` field.
  SharedPreferences get prefs => _prefs;
  set prefs(SharedPreferences value) {
    _prefs = value;
    _initialized = true;
  }

  /// Whether [prefs] has been assigned. Callers that may run before [init]
  /// (device detection, connect-queue gating) check this instead of touching
  /// the uninitialised `late` field.
  bool get isInitialized => _initialized;

  SettingsSyncService? _syncService;
  Timer? _syncDebounceTimer;

  Future<String?> init({bool retried = false}) async {
    try {
      // SharedPreferences is the one step the whole app depends on, so it can't
      // be skipped — but bound it so a stuck platform channel surfaces as a
      // recoverable error instead of an infinite freeze.
      prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 10));
      propPrefs.initialize(prefs);
      trainerAppListenable.value = getTrainerApp();
      final localeOverride = getLocaleOverride();
      localeListenable.value = localeOverride == null ? null : Locale(localeOverride);

      // Everything below is a native or network call that has, on some users'
      // machines, hung forever and bricked startup (the app reaches here, logs
      // "NOTIFICATION SETUP", and never paints). Each runs under a timeout that
      // logs which step stalled and then lets startup continue degraded rather
      // than freeze — see [_guardedInitStep]. The offending step's name reaches
      // the support bundle via lastLogEntries, so a report names the culprit we
      // cannot reproduce.
      if (!screenshotMode) {
        // Fire-and-forget: notification setup has hung on some macOS machines,
        // and it's not needed for the app to function — so never let startup
        // wait on it at all. The guard still logs if it stalls.
        unawaited(_guardedInitStep('notifications', () => NotificationRequirement.setup()));
      }
      initializeActions(getLastTarget()?.connectionType ?? ConnectionType.unknown);

      if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS) {
        await _guardedInitStep('windowManager', () => windowManager.ensureInitialized());
      }

      // Fall back to the selected trainer app when the keymap pref ('app') is
      // missing — they are independent prefs and a null keymap leaves every
      // button unregistered and every press erroring out.
      final app = getKeyMap() ?? getTrainerApp();
      core.actionHandler.init(app);

      await _guardedInitStep('supabase', () async {
        await Supabase.initialize(
          url: 'https://pikrcyynovdvogrldfnw.supabase.co',
          anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
        );
      });

      if (!kIsWeb && Platform.isWindows) {
        await _guardedInitStep('windowsStoreEnv', () => WindowsStoreEnvironment.initialize());
      }

      // Initialize IAP manager (StoreKit / RevenueCat — a network round trip).
      await _guardedInitStep('iap', () => IAPManager.instance.initialize(), timeout: const Duration(seconds: 8));

      // Start trial if this is the first launch. Guarded as a whole: reading the
      // IAP state can throw when the manager above timed out mid-init.
      try {
        if (!IAPManager.instance.hasTrialStarted && !IAPManager.instance.isPurchased.value) {
          await _guardedInitStep('trial', () => IAPManager.instance.startTrial());
        }
      } catch (e, s) {
        recordError(e, s, context: 'Init.trialCheck');
      }

      // Initialize settings sync service for Pro users
      _syncService = SettingsSyncService();
      await _guardedInitStep('settingsSync', () => _syncService!.initialize());

      return null;
    } catch (e, s) {
      recordError(e, s, context: 'Init');
      if (!retried) {
        if (Platform.isWindows) {
          // delete settings file
          final fs = SharedPreferencesWindows.instance.fs;

          final pathProvider = PathProviderWindows();
          final String? directory = await pathProvider.getApplicationSupportPath();
          if (directory == null) {
            return null;
          }
          final String fileLocation = path.join(directory, 'shared_preferences.json');
          final file = fs.file(fileLocation);
          if (await file.exists()) {
            await file.delete();
          }
        }
        return init(retried: true);
      } else {
        return '$e\n$s';
      }
    }
  }

  /// Runs a non-critical startup [step] under a [timeout] so a hung native or
  /// network call can't stop the app from ever starting. On timeout or error it
  /// records which step stalled — the message lands in `lastLogEntries` and so
  /// in the support bundle, naming a culprit we otherwise can't reproduce — and
  /// returns, letting startup continue in a degraded state.
  Future<void> _guardedInitStep(
    String name,
    Future<void> Function() step, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      await step().timeout(timeout);
    } on TimeoutException catch (_, s) {
      recordError('Startup step "$name" timed out after ${timeout.inSeconds}s', s, context: 'Init.$name');
    } catch (e, s) {
      recordError(e, s, context: 'Init.$name');
    }
  }

  Future<void> reset() async {
    await prefs.clear();
    IAPManager.instance.reset(true);
    init();
  }

  /// Fires whenever [setTrainerApp] is called. Consumers (the connection
  /// layer, ProxyDevice) listen so they can restart the emulator with the
  /// new advertised name — e.g. Rouvy needs "Zwift Hub" while other apps
  /// expect the device-derived name.
  final ValueNotifier<SupportedApp?> trainerAppListenable = ValueNotifier<SupportedApp?>(null);

  /// The user's in-app language override, or null to follow the OS language.
  /// The root [ShadcnApp] listens to this so switching languages rebuilds the
  /// whole app immediately. Defaults to null (=system) and is safe to read
  /// before [init] (the splash renders in the system language, which is
  /// correct).
  final ValueNotifier<Locale?> localeListenable = ValueNotifier<Locale?>(null);

  /// The persisted language override as a locale code (e.g. 'de'), or null when
  /// the app should follow the OS language.
  String? getLocaleOverride() {
    return prefs.getString('locale_override');
  }

  Future<void> setLocaleOverride(String? code) async {
    if (code == null) {
      await prefs.remove('locale_override');
    } else {
      await prefs.setString('locale_override', code);
    }
    localeListenable.value = code == null ? null : Locale(code);
  }

  void setTrainerApp(SupportedApp app) {
    prefs.setString('trainer_app', app.name);
    trainerAppListenable.value = app;
  }

  SupportedApp? getTrainerApp() {
    final appName = prefs.getString('trainer_app');
    if (appName == null) {
      return null;
    }
    return SupportedApp.supportedApps.firstOrNullWhere((e) => e.name == appName);
  }

  static String _retrofitModeKey(String trainerKey) => 'retrofit_mode_$trainerKey';

  RetrofitMode getRetrofitMode(String trainerKey, {RetrofitMode fallback = RetrofitMode.proxy}) {
    final raw = prefs.getString(_retrofitModeKey(trainerKey));
    if (raw == null) return fallback;
    return RetrofitMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => fallback,
    );
  }

  Future<void> setRetrofitMode(String trainerKey, RetrofitMode mode) async {
    await prefs.setString(_retrofitModeKey(trainerKey), mode.name);
  }

  /// Global, not per trainer: closing the "Need help?" card on one trainer's
  /// page means the rider knows where the Help Center lives — re-showing it
  /// on the next trainer would just be nagging.
  bool getNeedHelpCardDismissed() {
    return prefs.getBool('need_help_card_dismissed') ?? false;
  }

  Future<void> setNeedHelpCardDismissed(bool dismissed) async {
    await prefs.setBool('need_help_card_dismissed', dismissed);
  }

  static String _autoConnectKey(String trainerKey) => 'auto_connect_$trainerKey';

  /// Whether the user wants this trainer to auto-start on scan. Set to true
  /// when they explicitly connect (tap-to-connect or Connect button) and
  /// cleared when they tap Disconnect.
  bool getAutoConnect(String trainerKey) {
    return prefs.getBool(_autoConnectKey(trainerKey)) ?? false;
  }

  Future<void> setAutoConnect(String trainerKey, bool autoConnect) async {
    await prefs.setBool(_autoConnectKey(trainerKey), autoConnect);
  }

  static String _controlProtocolKey(String trainerKey) => 'control_protocol_$trainerKey';

  /// The rider's forced trainer control protocol for this trainer as a
  /// [TrainerControlProtocol] name, or null for auto-detection (the default).
  ///
  /// Stored as the raw name rather than the enum so an unknown value — an
  /// older/newer build, or a protocol this trainer no longer advertises —
  /// degrades to "auto" at the parse site instead of throwing on read.
  String? getControlProtocolOverride(String trainerKey) {
    return prefs.getString(_controlProtocolKey(trainerKey));
  }

  Future<void> setControlProtocolOverride(String trainerKey, String? name) async {
    if (name == null) {
      await prefs.remove(_controlProtocolKey(trainerKey));
      return;
    }
    await prefs.setString(_controlProtocolKey(trainerKey), name);
  }

  static String _sensorAutoConnectKey(String deviceId) => 'sensor_auto_connect_$deviceId';

  /// Whether the rider has explicitly asked to connect this BLE sensor (a
  /// heart rate strap, a cadence sensor, or a power meter). Mirrors
  /// [getAutoConnect]'s per-trainer consent flag, keyed by BLE device id
  /// instead of trainer key — a sensor must never auto-connect on its own
  /// (see `BleHeartRateDevice.shouldAutoConnect`'s doc comment, shared by its
  /// cadence/power equivalents: most only allow one simultaneous BLE link),
  /// so this stays false until the rider taps Connect on a discovered
  /// sensor, and from then on it reconnects automatically like every other
  /// remembered device.
  bool getSensorAutoConnect(String deviceId) {
    return prefs.getBool(_sensorAutoConnectKey(deviceId)) ?? false;
  }

  Future<void> setSensorAutoConnect(String deviceId, bool autoConnect) async {
    await prefs.setBool(_sensorAutoConnectKey(deviceId), autoConnect);
  }

  static String _sensorSelectionKey(String quantityName) => 'sensor_selection_$quantityName';

  /// The rider's chosen source id for a quantity, or null for the trainer
  /// (the default). Stored as the raw source id so an id that no longer
  /// resolves degrades to "trainer" at the read site instead of throwing.
  String? getSensorSelection(String quantityName) {
    return prefs.getString(_sensorSelectionKey(quantityName));
  }

  Future<void> setSensorSelection(String quantityName, String? sourceId) async {
    if (sourceId == null) {
      await prefs.remove(_sensorSelectionKey(quantityName));
      return;
    }
    await prefs.setString(_sensorSelectionKey(quantityName), sourceId);
  }

  static const _sensorsTransportKey = 'sensors_transport';
  static const _sensorsOnlyModeKey = 'sensors_only_mode';

  /// Standalone sensor broadcast transport — `bluetooth` or `wifi`. Never
  /// `proxy`; an unknown stored value degrades to the default rather than
  /// throwing at the read site.
  RetrofitMode getSensorsTransport() {
    final raw = prefs.getString(_sensorsTransportKey);
    return raw == RetrofitMode.wifi.name ? RetrofitMode.wifi : RetrofitMode.bluetooth;
  }

  Future<void> setSensorsTransport(RetrofitMode mode) => prefs.setString(_sensorsTransportKey, mode.name);

  bool getSensorsOnlyMode() => prefs.getBool(_sensorsOnlyModeKey) ?? false;

  Future<void> setSensorsOnlyMode(bool value) => prefs.setBool(_sensorsOnlyModeKey, value);

  static String _selfTestKey(String trainerKey) => 'self_test_$trainerKey';

  String? getSelfTestResultJson(String trainerKey) {
    return prefs.getString(_selfTestKey(trainerKey));
  }

  Future<void> setSelfTestResultJson(String trainerKey, String json) async {
    await prefs.setString(_selfTestKey(trainerKey), json);
  }

  String? getNetworkSelfTestResultJson() {
    return prefs.getString('network_self_test');
  }

  Future<void> setNetworkSelfTestResultJson(String json) async {
    await prefs.setString('network_self_test', json);
  }

  static const String _virtualShiftingIntroSeenKey = 'virtual_shifting_intro_seen';

  /// Whether the user has seen the one-time Virtual Shifting beta intro shown
  /// the first time the Smart Trainer page is opened. Global (not per-trainer).
  bool getVirtualShiftingIntroSeen() {
    return prefs.getBool(_virtualShiftingIntroSeenKey) ?? false;
  }

  Future<void> setVirtualShiftingIntroSeen(bool seen) async {
    await prefs.setBool(_virtualShiftingIntroSeenKey, seen);
  }

  static const String _onboardingStateKey = 'onboarding_state';
  static const String onboardingStatePending = 'pending';
  static const String onboardingStateCompleted = 'completed';

  /// First-run onboarding wizard state: null = never triggered,
  /// [onboardingStatePending] = started but not finished (re-shown on next
  /// launch), [onboardingStateCompleted] = finished or migrated existing
  /// install (only reachable via the "Setup guide" menu entry).
  String? getOnboardingState() {
    return prefs.getString(_onboardingStateKey);
  }

  Future<void> setOnboardingState(String state) async {
    await prefs.setString(_onboardingStateKey, state);
  }

  static String _obpSupportedButtonsKey(String appName) => 'obp_supported_buttons_$appName';

  /// Last-known OpenBikeControl supported buttons for [appName]. Set when a
  /// trainer app sends an AppInfo over BLE/mDNS; used by the ButtonEditor so
  /// the user can configure mappings even before connecting.
  List<ControllerButton>? getObpSupportedButtons(String appName) {
    final stored = prefs.getStringList(_obpSupportedButtonsKey(appName));
    if (stored == null) return null;
    return stored
        .mapNotNull((s) => int.tryParse(s))
        .mapNotNull((id) => OpenBikeProtocolParser.BUTTON_NAMES[id])
        .toList();
  }

  Future<void> setObpSupportedButtons(String appName, List<ControllerButton> buttons) async {
    await prefs.setStringList(
      _obpSupportedButtonsKey(appName),
      buttons.where((b) => b.identifier != null).map((b) => b.identifier!.toString()).toList(),
    );
    _triggerAutoSync();
  }

  Future<void> setKeyMap(SupportedApp app) async {
    if (app is CustomApp) {
      await prefs.setStringList('customapp_${app.profileName}', app.encodeKeymap());
    }
    await prefs.setString('app', app.name);
    for (final device in core.connection.devices.whereType<ProxyDevice>()) {
      device.applyTrainerSettings();
    }
    _triggerAutoSync();
  }

  SupportedApp? getKeyMap() {
    final appName = prefs.getString('app');
    if (appName == null) {
      return null;
    }

    // Check if it's a custom app with a profile name
    if (appName.startsWith('Custom') || prefs.containsKey('customapp_$appName')) {
      final customApp = CustomApp(profileName: appName);
      final appSetting = prefs.getStringList('customapp_$appName');
      if (appSetting != null) {
        try {
          customApp.decodeKeymap(appSetting);
        } catch (e, s) {
          recordError(e, s, context: 'Decoding custom app keymap for $appName');
          // reset it
          prefs.remove('customapp_$appName');
        }
      }
      return customApp;
    } else {
      return SupportedApp.supportedApps.firstOrNullWhere((e) => e.name == appName);
    }
  }

  List<String> getCustomAppProfiles() {
    // Get all keys starting with 'customapp_'
    final keys = prefs.getKeys().where((key) => key.startsWith('customapp_')).toList();
    return keys.map((key) => key.replaceFirst('customapp_', '')).toList();
  }

  List<String>? getCustomAppKeymap(String profileName) {
    return prefs.getStringList('customapp_$profileName');
  }

  Future<void> deleteCustomAppProfile(String profileName) async {
    await prefs.remove('customapp_$profileName');
    // If the current app is the one being deleted, reset
    if (prefs.getString('app') == profileName) {
      core.actionHandler.init(getTrainerApp());
      await prefs.remove('app');
    }
    _triggerAutoSync();
  }

  Future<void> duplicateCustomAppProfile(String sourceProfileName, String newProfileName) async {
    final sourceData = prefs.getStringList('customapp_$sourceProfileName');
    if (sourceData != null) {
      await prefs.setStringList('customapp_$newProfileName', sourceData);
    }
    _triggerAutoSync();
  }

  String? exportCustomAppProfile(String profileName) {
    final data = prefs.getStringList('customapp_$profileName');
    if (data == null) return null;
    var encoder = JsonEncoder.withIndent("     ");
    return encoder.convert({
      'version': 1,
      'profileName': profileName,
      'keymap': data.map((e) => jsonDecode(e)).toList(),
    });
  }

  Future<bool> importCustomAppProfile(String jsonData, {String? newProfileName}) async {
    try {
      final decoded = jsonDecode(jsonData);

      // Validate the structure
      if (decoded['version'] == null || decoded['keymap'] == null) {
        return false;
      }

      final profileName = newProfileName ?? decoded['profileName'] ?? 'Imported';
      final keymap = (decoded['keymap'] as List).map((e) => jsonEncode(e)).toList().cast<String>();

      await prefs.setStringList('customapp_$profileName', keymap);
      _triggerAutoSync();
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  String? getLastSeenVersion() {
    return prefs.getString('last_seen_version');
  }

  Target? getLastTarget() {
    final targetString = prefs.getString('last_target');
    if (targetString == null) return null;
    return Target.values.firstOrNullWhere((e) => e.name == targetString);
  }

  Future<void> setLastTarget(Target target) async {
    await prefs.setString('last_target', target.name);
    initializeActions(target.connectionType);
    IAPManager.instance.setAttributes();
  }

  Future<void> setLastSeenVersion(String version) async {
    await prefs.setString('last_seen_version', version);
  }

  bool getVibrationEnabled() {
    return prefs.getBool('vibration_enabled') ?? true;
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    await prefs.setBool('vibration_enabled', enabled);
  }

  /// Phone-side shift feedback (haptics / sounds). Distinct from
  /// [getVibrationEnabled], which buzzes the Zwift controller hardware.
  bool getShiftHapticsEnabled() {
    return prefs.getBool('shift_haptics_enabled') ?? false;
  }

  Future<void> setShiftHapticsEnabled(bool enabled) async {
    await prefs.setBool('shift_haptics_enabled', enabled);
  }

  bool getShiftSoundEnabled() {
    return prefs.getBool('shift_sound_enabled') ?? false;
  }

  Future<void> setShiftSoundEnabled(bool enabled) async {
    await prefs.setBool('shift_sound_enabled', enabled);
  }

  bool getMyWhooshLinkEnabled() {
    return prefs.getBool('mywhoosh_link_enabled') ?? false;
  }

  Future<void> setMyWhooshLinkEnabled(bool enabled) async {
    await prefs.setBool('mywhoosh_link_enabled', enabled);
  }

  bool getObpMdnsEnabled() {
    return prefs.getBool('openbikeprotocol_mdns_enabled') ?? false;
  }

  Future<void> setObpMdnsEnabled(bool enabled) async {
    await prefs.setBool('openbikeprotocol_mdns_enabled', enabled);
  }

  ObpMdnsBackend getObpMdnsBackend() {
    final raw = prefs.getString('openbikeprotocol_mdns_backend');
    if (raw == null) return ObpMdnsBackend.platformDefault;
    return ObpMdnsBackend.values.firstWhere(
      (b) => b.name == raw,
      orElse: () => ObpMdnsBackend.platformDefault,
    );
  }

  Future<void> setObpMdnsBackend(ObpMdnsBackend backend) async {
    await prefs.setString('openbikeprotocol_mdns_backend', backend.name);
  }

  bool getObpBleEnabled() {
    return prefs.getBool('openbikeprotocol_ble_enabled') ?? false;
  }

  Future<void> setObpBleEnabled(bool enabled) async {
    await prefs.setBool('openbikeprotocol_ble_enabled', enabled);
  }

  bool getZwiftBleEmulatorEnabled() {
    return prefs.getBool('zwift_emulator_enabled') ?? false;
  }

  Future<void> setZwiftBleEmulatorEnabled(bool enabled) async {
    await prefs.setBool('zwift_emulator_enabled', enabled);
  }

  bool getZwiftMdnsEmulatorEnabled() {
    return prefs.getBool('zwift_mdns_emulator_enabled') ?? false;
  }

  Future<void> setZwiftMdnsEmulatorEnabled(bool enabled) async {
    await prefs.setBool('zwift_mdns_emulator_enabled', enabled);
  }

  bool getMiuiWarningDismissed() {
    return prefs.getBool('miui_warning_dismissed') ?? false;
  }

  Future<void> setMiuiWarningDismissed(bool dismissed) async {
    await prefs.setBool('miui_warning_dismissed', dismissed);
  }

  bool getMyWhooshGearHintDismissed() {
    return prefs.getBool('mywhoosh_gear_hint_dismissed') ?? false;
  }

  Future<void> setMyWhooshGearHintDismissed(bool dismissed) async {
    await prefs.setBool('mywhoosh_gear_hint_dismissed', dismissed);
  }

  bool getRideFirmwareLockDialogShown() {
    return prefs.getBool('ride_firmware_lock_dialog_shown') ?? false;
  }

  Future<void> setRideFirmwareLockDialogShown(bool shown) async {
    await prefs.setBool('ride_firmware_lock_dialog_shown', shown);
  }

  /// Sticky flag: true once the user has opened a support chat at least once
  /// on this device. HelpButton uses it to decide whether to do a background
  /// poll for unread admin replies on app start.
  bool getSupportChatActive() {
    return prefs.getBool('support_chat_active') ?? false;
  }

  Future<void> setSupportChatActive(bool active) async {
    await prefs.setBool('support_chat_active', active);
  }

  // Review prompt — legacy connection-counting scheme. `review_completed` is
  // still read by FeedbackPromptService (a hard stop: someone who already
  // rated must never be asked again). The other two below pre-date that
  // service (the old star-rating banner used them) and are deliberately no
  // longer read/written by it — see FeedbackPromptService's doc comment for
  // why reusing them for the session-based rewrite wouldn't be safe.
  int getReviewSessionCount() {
    return prefs.getInt('review_session_count') ?? 0;
  }

  Future<void> setReviewSessionCount(int count) async {
    await prefs.setInt('review_session_count', count);
  }

  bool getReviewCompleted() {
    return prefs.getBool('review_completed') ?? false;
  }

  Future<void> setReviewCompleted(bool completed) async {
    await prefs.setBool('review_completed', completed);
  }

  int? getReviewDismissedAtSessionCount() {
    return prefs.getInt('review_dismissed_at_session_count');
  }

  Future<void> setReviewDismissedAtSessionCount(int? count) async {
    if (count == null) {
      await prefs.remove('review_dismissed_at_session_count');
    } else {
      await prefs.setInt('review_dismissed_at_session_count', count);
    }
  }

  // Feedback prompt — session-based rewrite (see FeedbackPromptService).
  // New keys, rebased at 0 for every install, existing users included.
  int getFeedbackSuccessfulSessionCount() {
    return prefs.getInt('feedback_successful_session_count') ?? 0;
  }

  Future<void> setFeedbackSuccessfulSessionCount(int count) async {
    await prefs.setInt('feedback_successful_session_count', count);
  }

  /// First time the new session-based prompt logic ran on this device.
  /// Recorded once, on the first `FeedbackPromptService.start()` call, and
  /// never overwritten after — see `minAgeSinceFirstSeen`.
  DateTime? getFeedbackPromptFirstSeenAt() {
    final ms = prefs.getInt('feedback_prompt_first_seen_at_ms');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setFeedbackPromptFirstSeenAt(DateTime value) async {
    await prefs.setInt('feedback_prompt_first_seen_at_ms', value.millisecondsSinceEpoch);
  }

  DateTime? getFeedbackPromptDismissedAt() {
    final ms = prefs.getInt('feedback_prompt_dismissed_at_ms');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setFeedbackPromptDismissedAt(DateTime? value) async {
    if (value == null) {
      await prefs.remove('feedback_prompt_dismissed_at_ms');
    } else {
      await prefs.setInt('feedback_prompt_dismissed_at_ms', value.millisecondsSinceEpoch);
    }
  }

  int? getFeedbackPromptDismissedAtSessionCount() {
    return prefs.getInt('feedback_prompt_dismissed_at_session_count');
  }

  Future<void> setFeedbackPromptDismissedAtSessionCount(int? count) async {
    if (count == null) {
      await prefs.remove('feedback_prompt_dismissed_at_session_count');
    } else {
      await prefs.setInt('feedback_prompt_dismissed_at_session_count', count);
    }
  }

  List<String> _getIgnoredDeviceIds() {
    return prefs.getStringList('ignored_device_ids') ?? [];
  }

  List<String> _getIgnoredDeviceNames() {
    return prefs.getStringList('ignored_device_names') ?? [];
  }

  Future<void> addIgnoredDevice(String deviceId, String deviceName) async {
    final ids = _getIgnoredDeviceIds();
    final names = _getIgnoredDeviceNames();

    if (!ids.contains(deviceId)) {
      ids.add(deviceId);
      names.add(deviceName);
      await prefs.setStringList('ignored_device_ids', ids);
      await prefs.setStringList('ignored_device_names', names);
      _triggerAutoSync();
    }
  }

  Future<void> removeIgnoredDevice(String deviceId) async {
    final ids = _getIgnoredDeviceIds();
    final names = _getIgnoredDeviceNames();

    final index = ids.indexOf(deviceId);
    if (index != -1) {
      ids.removeAt(index);
      names.removeAt(index);
      await prefs.setStringList('ignored_device_ids', ids);
      await prefs.setStringList('ignored_device_names', names);
      _triggerAutoSync();
    }
  }

  List<({String id, String name})> getIgnoredDevices() {
    final ids = _getIgnoredDeviceIds();
    final names = _getIgnoredDeviceNames();

    final result = <({String id, String name})>[];
    for (int i = 0; i < ids.length && i < names.length; i++) {
      result.add((id: ids[i], name: names[i]));
    }
    return result;
  }

  bool getShowZwiftClickV2ReconnectWarning() {
    return prefs.getBool('zwift_click_v2_reconnect_warning') ?? true;
  }

  Future<void> setShowZwiftClickV2ReconnectWarning(bool show) async {
    await prefs.setBool('zwift_click_v2_reconnect_warning', show);
  }

  /// Whether the rider has completed the one-time Zwift Click V2 unlock-mode
  /// onboarding. Reports done when prefs are not ready yet so an
  /// uninitialised [Settings] never holds a device out of the connect queue.
  bool getClickV2OnboardingDone() {
    if (!_initialized) return true;
    return prefs.getBool('click_v2_onboarding_done') ?? false;
  }

  Future<void> setClickV2OnboardingDone(bool value) async {
    await prefs.setBool('click_v2_onboarding_done', value);
  }

  void setRemoteControlEnabled(bool value) {
    prefs.setBool('remote_control_enabled', value);
  }

  bool getRemoteControlEnabled() {
    return prefs.getBool('remote_control_enabled') ?? false;
  }

  void setRemoteKeyboardControlEnabled(bool value) {
    prefs.setBool('remote_keyboard_control_enabled', value);
  }

  bool getRemoteKeyboardControlEnabled() {
    return prefs.getBool('remote_keyboard_control_enabled') ?? false;
  }

  bool getLocalEnabled() {
    return prefs.getBool('local_control_enabled') ?? false;
  }

  void setLocalEnabled(bool value) {
    prefs.setBool('local_control_enabled', value);
  }

  // Button Simulator Hotkey Settings
  Map<InGameAction, String> getButtonSimulatorHotkeys() {
    final json = prefs.getString('button_simulator_hotkeys');
    if (json == null) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      // Actions that no longer exist (e.g. the removed D-Fly channels) are
      // skipped, so one stale entry doesn't throw away every other hotkey.
      return {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (InGameAction.values.firstOrNullWhere((e) => e.name == key) case final action?) action: value.toString(),
      };
    } catch (e, s) {
      recordError(e, s, context: 'Decoding button simulator hotkeys');
      return {};
    }
  }

  Future<void> setButtonSimulatorHotkeys(Map<InGameAction, String> hotkeys) async {
    await prefs.setString(
      'button_simulator_hotkeys',
      jsonEncode(hotkeys.map((key, value) => MapEntry(key.name, value))),
    );
  }

  Future<void> setButtonSimulatorHotkey(InGameAction action, String hotkey) async {
    final hotkeys = getButtonSimulatorHotkeys();
    hotkeys[action] = hotkey;
    await setButtonSimulatorHotkeys(hotkeys);
  }

  Future<void> removeButtonSimulatorHotkey(InGameAction action) async {
    final hotkeys = getButtonSimulatorHotkeys();
    hotkeys.remove(action);
    await setButtonSimulatorHotkeys(hotkeys);
  }

  /// WHEELTOP keepalive experiment (see WheeltopProbe): tries reply
  /// candidates to the TX pod's status frame, one per reconnect. On by
  /// default — TX shifters are unusable without it, and the pod drops too
  /// fast for the user to reach a toggle mid-connection; disabling it instead
  /// lets the quick-drop backoff quiet the reconnect loop.
  void setWheeltopProbeEnabled(bool value) {
    prefs.setBool('wheeltop_probe_enabled', value);
  }

  bool getWheeltopProbeEnabled() {
    return prefs.getBool('wheeltop_probe_enabled') ?? true;
  }

  void setPhoneSteeringEnabled(bool value) {
    prefs.setBool('phone_steering_enabled', value);
  }

  bool getPhoneSteeringEnabled() {
    return prefs.getBool('phone_steering_enabled') ?? false;
  }

  void setPhoneSteeringThreshold(int value) {
    prefs.setInt('phone_steering_threshold', value);
  }

  double getPhoneSteeringThreshold() {
    return prefs.getInt('phone_steering_threshold')?.toDouble() ?? GyroscopeSteering.STEERING_THRESHOLD;
  }

  // L-TWOO eRX/eR9 Settings

  /// 3-digit ASCII PIN sent in every request frame; "000" is the factory default.
  String getLtwooPin(String deviceId) => prefs.getString('ltwoo_pin_$deviceId') ?? '000';

  Future<void> setLtwooPin(String deviceId, String pin) async => prefs.setString('ltwoo_pin_$deviceId', pin);

  /// Anchor-gear mode: after each rider shift, the derailleur is shifted back
  /// so the chain stays on one cog while the levers drive virtual shifting.
  bool getLtwooAnchorGearEnabled(String deviceId) => prefs.getBool('ltwoo_anchor_gear_$deviceId') ?? false;

  Future<void> setLtwooAnchorGearEnabled(String deviceId, bool enabled) async =>
      prefs.setBool('ltwoo_anchor_gear_$deviceId', enabled);

  /// Learned orientation of the rear remote-shift opcodes: true when this
  /// derailleur moves opposite to the default mapping (LtwooErx verifies the
  /// mapping at runtime and persists the result here).
  bool getLtwooShiftOrientationInverted(String deviceId) =>
      prefs.getBool('ltwoo_shift_orientation_inverted_$deviceId') ?? false;

  Future<void> setLtwooShiftOrientationInverted(String deviceId, bool inverted) async =>
      prefs.setBool('ltwoo_shift_orientation_inverted_$deviceId', inverted);

  // SRAM AXS Settings

  String? getSramKey(String serial) => prefs.getString('sram_key_$serial');

  Future<void> setSramKey(String serial, String? hexKey) async {
    if (hexKey == null) {
      await prefs.remove('sram_key_$serial');
    } else {
      await prefs.setString('sram_key_$serial', hexKey);
    }
  }

  Map<String, SramReactionTrigger>? getSramBackup(String serial) {
    final raw = prefs.getString('sram_config_backup_$serial');
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, SramReactionTrigger.fromJson(v as Map<String, dynamic>)));
  }

  Future<void> setSramBackup(String serial, Map<String, SramReactionTrigger> backup) async {
    await prefs.setString(
      'sram_config_backup_$serial',
      jsonEncode(backup.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  Future<void> clearSramBackup(String serial) async => prefs.remove('sram_config_backup_$serial');

  bool getSramShiftingDisabled(String serial) => prefs.getBool('sram_disabled_$serial') ?? false;

  Future<void> setSramShiftingDisabled(String serial, bool disabled) async =>
      prefs.setBool('sram_disabled_$serial', disabled);

  List<({int serial, int mask, int? deviceType})> getSramButtons(String serial) {
    final raw = prefs.getStringList('sram_buttons_$serial') ?? const [];
    return raw.map((e) {
      final parts = e.split(':');
      // Records are "serial:mask" (legacy) or "serial:mask:deviceType". The
      // device_type distinguishes the left/right paddle when no serial was seen.
      return (
        serial: int.parse(parts[0]),
        mask: int.parse(parts[1]),
        deviceType: parts.length > 2 && parts[2].isNotEmpty ? int.tryParse(parts[2]) : null,
      );
    }).toList();
  }

  Future<void> addSramButton(String serial, int controllerSerial, int mask, [int? deviceType]) async {
    final entry = '$controllerSerial:$mask:${deviceType ?? ''}';
    final list = prefs.getStringList('sram_buttons_$serial') ?? <String>[];
    if (list.contains(entry)) return; // exact record already present

    // A button's identity is (serial, mask, deviceType) — the left and right
    // paddles share serial+mask and differ ONLY by device_type, so they must
    // stay separate records. A device_type-less record ("serial:mask" legacy,
    // or "serial:mask:") is the "side unknown" form.
    bool sameSerialMask(String e) => e == '$controllerSerial:$mask' || e.startsWith('$controllerSerial:$mask:');
    bool sideless(String e) => e == '$controllerSerial:$mask' || e == '$controllerSerial:$mask:';

    if (deviceType == null) {
      // Side unknown: don't duplicate a button we already have in any form.
      if (list.any(sameSerialMask)) return;
      list.add(entry);
    } else {
      // Side known: upgrade a side-less record in place, else add a new side.
      final idx = list.indexWhere(sideless);
      if (idx == -1) {
        list.add(entry);
      } else {
        list[idx] = entry;
      }
    }
    await prefs.setStringList('sram_buttons_$serial', list);
  }

  /// Persisted shifter adverts (serial → "deviceType:model") for stable button
  /// naming across sessions, scoped to the parent device.
  void setSramShifter(String serial, int shifterSerial, int? deviceType, int? model) {
    if (!_initialized) return; // no prefs (e.g. pure naming unit tests) → nothing to persist
    final list = prefs.getStringList('sram_shifters_$serial') ?? <String>[];
    final entry = '$shifterSerial:${deviceType ?? ''}:${model ?? ''}';
    list.removeWhere((e) => e.startsWith('$shifterSerial:'));
    list.add(entry);
    prefs.setStringList('sram_shifters_$serial', list);
  }

  ({int? deviceType, int? model})? getSramShifter(String serial, int shifterSerial) {
    if (!_initialized) return null;
    for (final e in prefs.getStringList('sram_shifters_$serial') ?? const <String>[]) {
      final p = e.split(':');
      if (p.isNotEmpty && int.tryParse(p[0]) == shifterSerial) {
        return (deviceType: p.length > 1 ? int.tryParse(p[1]) : null, model: p.length > 2 ? int.tryParse(p[2]) : null);
      }
    }
    return null;
  }

  bool hasAskedPermissions() {
    return prefs.getBool('asked_permissions') ?? false;
  }

  Future<void> setHasAskedPermissions(bool asked) async {
    await prefs.setBool('asked_permissions', asked);
  }

  bool getMediaKeyDetectionEnabled() {
    return prefs.getBool('media_key_detection_enabled') ?? false;
  }

  Future<void> setMediaKeyDetectionEnabled(bool enabled) async {
    await prefs.setBool('media_key_detection_enabled', enabled);
    _triggerAutoSync();
  }

  /// Triggers automatic sync to server for Pro users.
  /// Uses debouncing to avoid excessive sync calls.
  void _triggerAutoSync() {
    if (_syncService == null) return;
    if (!IAPManager.instance.hasActiveSubscription) return;
    if (!IAPManager.instance.isLoggedIn) return;

    // Cancel existing timer
    _syncDebounceTimer?.cancel();

    // Set new timer to sync after 2 seconds of inactivity
    _syncDebounceTimer = Timer(const Duration(seconds: 10), () {
      _syncService?.syncToServer();
    });
  }

  /// Disposes the sync service and cleans up resources.
  void dispose() {
    _syncDebounceTimer?.cancel();
    _syncService?.dispose();
    _syncService = null;
  }

  // ----- Trainer overlay -----

  bool getOverlayEnabled() => prefs.getBool('overlay_enabled') ?? false;

  Future<void> setOverlayEnabled(bool enabled) async {
    // Read before the write: an overlay that is on counts as answered even
    // without the flag (see [getOverlayAnswered]), and switching it off has to
    // carry that answer forward — or a rider who enabled the overlay before
    // the flag existed would be asked again the first time it goes off.
    final wasAnswered = getOverlayAnswered();
    await prefs.setBool('overlay_enabled', enabled);
    // Turning the overlay on — from the home screen's step or the trainer
    // page's switch — answers the step, and is the rider changing their mind
    // about "Not now", so both are recorded here rather than at every call
    // site. Turning it off is not an answer in itself, and the step must not
    // become required again over it — the Live Activity's "stop ride"
    // switches the overlay off on every ride end.
    if (enabled || wasAnswered) await setOverlayAnswered(true);
    if (enabled) await setOverlayDeclined(false);
  }

  /// Whether the rider has ever answered the home screen's gear-overlay step,
  /// either way. The step is required only until then; afterwards an overlay
  /// that is off is an offer, not outstanding work. Set by [setOverlayEnabled]
  /// and [setOverlayDeclined], never cleared.
  ///
  /// An overlay that is on is an answer whether or not it was recorded as
  /// one: riders who turned it on before this flag existed carry no flag, and
  /// have answered all the same.
  bool getOverlayAnswered() => (prefs.getBool('overlay_answered') ?? false) || getOverlayEnabled();

  Future<void> setOverlayAnswered(bool answered) async {
    await prefs.setBool('overlay_answered', answered);
  }

  /// Whether the rider answered the home screen's gear-overlay step with
  /// "Not now". Keeps the step off the trainer card until the overlay is
  /// turned on somewhere, which clears it again — see [setOverlayEnabled].
  bool getOverlayDeclined() => prefs.getBool('overlay_declined') ?? false;

  Future<void> setOverlayDeclined(bool declined) async {
    await prefs.setBool('overlay_declined', declined);
    // A "no" is an answer too; clearing the decline is not.
    if (declined) await setOverlayAnswered(true);
  }

  /// iOS only: whether to use the floating Picture-in-Picture overlay.
  /// `null` = automatic (device default — on for iPad and non-Dynamic-Island
  /// iPhones, off for Dynamic-Island iPhones, which use the Live Activity).
  /// `true`/`false` = explicit user override.
  bool? getOverlayUsePip() => prefs.getBool('overlay_use_pip');

  Future<void> setOverlayUsePip(bool? value) async {
    if (value == null) {
      await prefs.remove('overlay_use_pip');
    } else {
      await prefs.setBool('overlay_use_pip', value);
    }
  }

  /// Get overlay display fields (set of OverlayField enum values).
  /// Defaults to {power, cadence}.
  Set<OverlayField> getOverlayFields() {
    final raw = prefs.getStringList('overlay_fields');
    if (raw == null) {
      return <OverlayField>{OverlayField.power, OverlayField.cadence};
    }
    final parsed = raw.map(OverlayField.fromName).whereType<OverlayField>().toSet();
    return parsed;
  }

  /// Set overlay display fields.
  Future<void> setOverlayFields(Set<OverlayField> fields) async {
    await prefs.setStringList(
      'overlay_fields',
      fields.map((f) => f.name).toList(),
    );
  }

  Offset? getOverlayPosition() {
    final x = prefs.getDouble('overlay_position_x');
    final y = prefs.getDouble('overlay_position_y');
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  Future<void> setOverlayPosition(Offset p) async {
    await prefs.setDouble('overlay_position_x', p.dx);
    await prefs.setDouble('overlay_position_y', p.dy);
  }

  /// Desktop overlay window opacity, in `[0.2, 1.0]`. `1.0` (fully opaque) is
  /// the default so the overlay looks unchanged until the user dials it down.
  /// The floor keeps the card from fading to the point of being unclickable.
  static const double minOverlayOpacity = 0.2;

  double getOverlayOpacity() => (prefs.getDouble('overlay_opacity') ?? 1.0).clamp(minOverlayOpacity, 1.0);

  Future<void> setOverlayOpacity(double value) async {
    await prefs.setDouble(
      'overlay_opacity',
      value.clamp(minOverlayOpacity, 1.0),
    );
  }

  Future<void> setShowExperimental(bool value) async {
    await prefs.setBool('show_experimental', value);
  }

  bool getShowExperimental() {
    return prefs.getBool('show_experimental') ?? false;
  }

  bool getUnlockWithZwift() {
    return prefs.getBool('unlock_mode') ?? false;
  }

  Future<void> setUnlockWithZwift(bool value) async {
    await prefs.setBool('unlock_mode', value);
  }

  /// Whether the rider runs their Zwift Click V2 as the right puck alone.
  ///
  /// This is the third Click V2 state, alongside [getUnlockWithZwift]: the
  /// right side needs no unlock and never restarts, so it connects on its own
  /// and the left side — the only one Zwift locks — is held out of the connect
  /// queue. Keeping the two sides apart is what makes this mode work at all:
  /// `ClickLogic` drives the left side's restart loop from a single shared
  /// timer that the right side's handshake cancels, so the restart mode and the
  /// right side cannot be live at the same time.
  ///
  /// Guarded like [getUseNewUnlockMethod] because the connect gates that read
  /// it run during device detection, which can precede [init].
  bool getClickV2RightSideOnly() {
    if (!_initialized) return false;
    return prefs.getBool('click_v2_right_side_only') ?? false;
  }

  Future<void> setClickV2RightSideOnly(bool value) async {
    await prefs.setBool('click_v2_right_side_only', value);
  }

  /// Whether a Zwift Click V2 connects as separate left/right controllers with
  /// the new unlock handling (the right side needs no unlocking). When false,
  /// both sides fall back to the single legacy [ZwiftClickV2]. Defaults to true.
  ///
  /// Guarded against an uninitialised [prefs] because device detection
  /// ([BluetoothDevice.fromScanResult]) can run before [init] — e.g. in unit
  /// tests — and must never throw. Mirrors [IAPManager]'s initialisation guard.
  bool getUseNewUnlockMethod() {
    if (!_initialized) return true;
    return prefs.getBool('use_new_unlock_method') ?? true;
  }

  Future<void> setUseNewUnlockMethod(bool value) async {
    await prefs.setBool('use_new_unlock_method', value);
  }
}
