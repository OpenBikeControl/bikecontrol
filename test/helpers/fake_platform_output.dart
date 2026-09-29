// Everything BikeControl does to the machine it runs on — a simulated key, a
// media key, a Shortcut launch, an Android global action, a wake lock, an
// overlay window — recorded in memory instead of performed. For captures that
// film an action firing without it touching the host.
import 'package:accessibility/accessibility.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:keypress_simulator_platform_interface/keypress_simulator_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// What the app asked the platform to do, in order: `key down ArrowUp`,
/// `media Media Play Pause`, `launch shortcuts://…`, `global home`.
class PlatformOutput {
  final performed = <String>[];

  /// Installs every fake. Channel mocks live on the test binding, so call from
  /// setUpAll (or later), not from main().
  void install() {
    KeyPressSimulatorPlatform.instance = _FakeKeyPresses(this);
    UrlLauncherPlatform.instance = _FakeUrlLauncher(this);
    WakelockPlusPlatformInterface.instance = _FakeWakelock();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // The accessibility plugin (Android's global actions, media control):
    // pigeon message channels answering [result].
    ByteData? reply(Object? result) => const StandardMessageCodec().encodeMessage(<Object?>[result]);
    const prefix = 'dev.flutter.pigeon.accessibility.Accessibility.';
    for (final method in [
      'hasPermission',
      'openPermissions',
      'performTouch',
      'performGlobalAction',
      'controlMedia',
      'isRunning',
      'ignoreHidDevices',
      'setHandledKeys',
    ]) {
      messenger.setMockMessageHandler('$prefix$method', (message) async {
        final args = Accessibility.pigeonChannelCodec.decodeMessage(message) as List<Object?>?;
        switch (method) {
          case 'performGlobalAction':
            performed.add('global ${(args!.single as GlobalAction).name}');
          case 'controlMedia':
            performed.add('media ${(args!.single as MediaAction).name}');
          case 'performTouch':
            performed.add('touch ${args![0]},${args[1]}');
        }
        return reply(method == 'hasPermission' || method == 'isRunning' ? true : null);
      });
    }
    // Its event channels (window changes, HID keys): listened to, never fire.
    for (final stream in ['streamEvents', 'hidKeyPressed']) {
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.accessibility.EventChannelMethods.$stream',
        (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
      );
    }
    // The desktop gear overlay's window (multi_window_native).
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.coditas.multi_window_native/pluginChannel'),
      (call) async {
        performed.add('window ${call.method}');
        return null;
      },
    );
  }
}

class _FakeKeyPresses extends KeyPressSimulatorPlatform {
  _FakeKeyPresses(this.output);

  final PlatformOutput output;

  @override
  Future<bool> isAccessAllowed() async => true;

  @override
  Future<void> requestAccess({bool onlyOpenPrefPane = false}) async {}

  @override
  Future<void> simulateKeyPress({
    KeyboardKey? key,
    // ignore: deprecated_member_use
    List<ModifierKey> modifiers = const [],
    bool keyDown = true,
    String? targetApp,
  }) async {
    final name = key is PhysicalKeyboardKey ? key.debugName : '$key';
    output.performed.add('key ${keyDown ? 'down' : 'up'} $name');
  }

  @override
  Future<void> simulateMouseClick(Offset position, {required bool keyDown}) async {
    output.performed.add('mouse ${keyDown ? 'down' : 'up'} ${position.dx.round()},${position.dy.round()}');
  }

  @override
  Future<void> simulateMediaKey(PhysicalKeyboardKey mediaKey) async {
    output.performed.add('media ${mediaKey.debugName}');
  }
}

class _FakeUrlLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  _FakeUrlLauncher(this.output);

  final PlatformOutput output;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    output.performed.add('launch $url');
    return true;
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    output.performed.add('launch $url');
    return true;
  }
}

class _FakeWakelock extends WakelockPlusPlatformInterface with MockPlatformInterfaceMixin {
  bool _enabled = false;

  @override
  Future<void> toggle({required bool enable}) async => _enabled = enable;

  @override
  Future<bool> get enabled async => _enabled;
}
