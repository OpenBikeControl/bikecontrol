import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:prop/devices/click_logic.dart';
import 'package:prop/prop.dart' show LogLevel;

/// Policy for the one-time Zwift Click V2 unlock-mode onboarding.
///
/// Zwift locks the Click V2 to their own app. BikeControl implements two
/// workarounds, and which one suits a rider is a real trade-off — so a newly
/// discovered Click V2 is held out of the connect queue until the rider has
/// seen the explainer and picked one.
///
/// Every consumer (the device classes' connect gate, the placeholder card and
/// the onboarding page) reads this class rather than assembling its own
/// settings checks, so the rule lives in exactly one place.
abstract final class ClickV2Onboarding {
  /// Whether a discovered Click V2 should be held back for onboarding.
  static bool get isPending {
    // Screenshot frames connect fake controllers directly and must never be
    // interrupted by an onboarding card — unless the video capture, which
    // films this explainer, has asked for it.
    if (screenshotSuppressesClickV2Onboarding) return false;
    if (!core.settings.isInitialized) return false;
    if (core.settings.getClickV2OnboardingDone()) return false;
    // `unlock_mode` defaults to false, so a true value can only come from a
    // deliberate past choice. Those riders are already settled — don't
    // re-onboard them.
    if (core.settings.getUnlockWithZwift()) return false;
    return true;
  }

  /// Every discovered Click V2 side that is currently disconnected — both
  /// split sides and the legacy unified representation.
  ///
  /// NOT gated on [isPending]. That would seem right for a getter named
  /// "pendingDevices", but [chooseRightSideOnly]/[chooseUnlockWithZwift] write
  /// the setting that flips [isPending] to false *before* they call
  /// [_connectPending] — by the time [_connectPending] needs this list,
  /// `isPending` is already false. So this getter stays ungated and instead
  /// means "every disconnected Click V2 side, pending or not"; callers that
  /// need "still awaiting onboarding" must additionally check [isPending]
  /// themselves (see `_hasPendingClickV2` in DevicePage). [_connectPending]
  /// compensates for the over-broad result by skipping devices the battery
  /// saver deliberately suppressed (see [Connection.isAutoReconnectSuppressed]).
  static List<BaseDevice> get pendingDevices => core.connection.devices
      .where((d) => d is ZwiftClickV2 || d is ZwiftClickV2RightSide)
      .where((d) => !d.isConnected)
      .toList();

  /// Right-side-only: the puck Zwift never locked, on its own. It needs no
  /// unlock, ever, and no restarts — the price is that the left puck's D-pad
  /// (steering, action bar) is not available.
  ///
  /// The left side is put on the ignored list rather than merely disconnected.
  /// A plain disconnect leaves it in the device list and lets the active scan
  /// rediscover it seconds later, so it reappears everywhere the rider's
  /// controllers are listed — the home chain included — as an entry stuck on
  /// "connecting" that never can. Ignoring is the one mechanism the scan
  /// filter, the remembered-device loader and the device list all already
  /// honour. [chooseUnlockWithZwift] undoes it.
  static Future<void> chooseRightSideOnly() async {
    await core.settings.setUnlockWithZwift(false);
    await core.settings.setClickV2RightSideOnly(true);
    // With one puck doing the work, the default keymap would leave the rider
    // able to shift in one direction only: Zwift's built-in map binds the
    // right paddle to shiftUp and the *left* paddle to shiftDown. This is the
    // same remap the right card's "Use the right side only" action applies.
    //
    // Isolated: the remap is a convenience on top of the mode, and needs a
    // trainer app to have been picked. If it can't run — no app selected yet,
    // a keymap that won't persist — the rider's actual choice must still be
    // recorded and applied below, not abandoned half-written.
    try {
      ZwiftClickV2RightSide.configureRightSideShiftingKeymap();
    } catch (e, stack) {
      recordError(e, stack, context: 'ClickV2Onboarding.configureRightSideShiftingKeymap');
    }
    // The right side only exists as its own device in the split
    // representation. If the rider had that switched off, turn it back on and
    // drop the stale device objects so the active scan rebuilds them as split
    // left/right instances. They are not connected yet, so this costs nothing.
    if (!core.settings.getUseNewUnlockMethod()) {
      await core.settings.setUseNewUnlockMethod(true);
      for (final device in pendingDevices) {
        // forget: false is what drops the cached scan result, so the active
        // scan rediscovers the controller and rebuilds it with the class the
        // new setting selects.
        // persistForget: false keeps it out of the ignored-devices list.
        await core.connection.disconnect(device, forget: false, persistForget: false);
      }
      await _complete();
      await core.connection.performScanning();
      return;
    }
    // "Set up again" can reach this method while a left side is ALREADY
    // connected. Its restart loop has to stop now, not whenever the firmware
    // next drops the link: the left side is no longer part of this setup, and
    // ClickLogic's timer is shared with the right side's handshake.
    ClickLogic.resetTimer();
    await _ignoreLeftSides();
    await _complete();
    await _connectPending();
  }

  /// Takes every left puck out of the setup — live, or a remembered stand-in
  /// for one that simply isn't switched on right now.
  ///
  /// Both matter: the home chain lists remembered controllers next to live
  /// ones, so ignoring only what is currently connected leaves the stand-in
  /// behind as an orphaned "not set up" card.
  ///
  /// Matched as [ZwiftClickV2] rather than [ZwiftClickV2LeftSide], which covers
  /// the legacy unified controller too: that is built from the LEFT puck's
  /// advert (the right one builds nothing at all), so it is the same physical
  /// device under a different class. [ZwiftClickV2RightSide] extends ZwiftRide,
  /// not this, so it is never caught here.
  static Future<void> _ignoreLeftSides() async {
    // Materialised, and unioned across both sources: disconnect() mutates
    // core.connection.devices, so a lazy view over it throws a
    // concurrent-modification error mid-loop.
    final leftSides = <ZwiftClickV2>{
      ...core.connection.devices.whereType<ZwiftClickV2>(),
      ...core.connection.offlineControllers.whereType<ZwiftClickV2>(),
    };
    for (final device in leftSides) {
      try {
        // persistForget adds it to the ignored list, which is what stops the
        // active scan handing it straight back.
        await core.connection.disconnect(device, forget: true, persistForget: true);
        // And drop the remembered entry, or loadRememberedDevices rebuilds it
        // as an offline stand-in on the next launch.
        await core.connection.forgetRemembered(device.device.deviceId);
      } catch (e, stack) {
        recordError(e, stack, context: 'ClickV2Onboarding.ignoreLeftSides');
      }
    }
  }

  /// Undoes [_ignoreLeftSides] so a rider coming from right-side-only actually
  /// gets both controllers back. Matched by the name stored alongside the id —
  /// which is exactly [ZwiftClickV2LeftSide.label], since that is what
  /// `Connection.disconnect` wrote there.
  ///
  /// Public because right-side-only is not the only way out of it: anything
  /// that switches off the split representation rebuilds the LEFT puck as the
  /// legacy unified controller, so leaving it ignored would leave the rider
  /// with no Click at all.
  static Future<void> restoreLeftSides() async {
    const labels = {ZwiftClickV2LeftSide.label, ZwiftClickV2.label};
    final ignored = core.settings.getIgnoredDevices().where((d) => labels.contains(d.name)).toList();
    for (final entry in ignored) {
      try {
        await core.settings.removeIgnoredDevice(entry.id);
      } catch (e, stack) {
        recordError(e, stack, context: 'ClickV2Onboarding.unignoreLeftSides');
      }
    }
    if (ignored.isNotEmpty) {
      // A full restart, not just performScanning(): that returns immediately
      // while a scan is already running, and the puck has to be re-advertised
      // to be picked up again. Restarting also clears the whole scan cache, so
      // the rider gets the controller back while still looking at the screen
      // that promised it, instead of on the next app launch.
      await core.connection.stop();
      await core.connection.performScanning();
    }
  }

  /// Unlock with Zwift: both controllers work, at the cost of re-unlocking
  /// through the Zwift app every 24 hours.
  ///
  /// Both controllers as ONE device: this mode also switches the split
  /// representation back off, so the rider ends up on the unified
  /// [ZwiftClickV2] rather than a separate left and right entry. The split
  /// exists for exactly one reason — letting the RIGHT puck work alone, unlock
  /// free — and that is [chooseRightSideOnly], the other mode. Keeping the two
  /// in step is what makes the representation follow the choice instead of
  /// being a setting of its own that nothing can turn back off.
  static Future<void> chooseUnlockWithZwift() async {
    await core.settings.setUnlockWithZwift(true);
    await core.settings.setClickV2RightSideOnly(false);
    // Recorded and applied BEFORE restoreLeftSides(), which can restart the
    // scan: a rescan while the split representation is still selected rebuilds
    // exactly the separate right-side entry this mode folds back in.
    final wasSplit = core.settings.getUseNewUnlockMethod();
    if (wasSplit) await core.settings.setUseNewUnlockMethod(false);
    // This mode is "both controllers", so a left side that right-side-only put
    // on the ignored list has to come back off it — otherwise the rider picks
    // the both-sides option and only ever gets one.
    await restoreLeftSides();
    // Switching to Zwift mode must cancel any live ClickLogic reset timer
    // immediately, or the rider gets one spurious restart right after choosing
    // the mode whose whole selling point is "no restarts during your ride".
    try {
      ClickLogic.resetTimer();
    } catch (e, stack) {
      recordError(e, stack, context: 'ClickV2Onboarding.chooseUnlockWithZwift');
    }
    await _complete();

    if (wasSplit) {
      // Connected or not: every split instance has to go, or there is nothing
      // for the scan to rebuild. In the unified representation the LEFT puck's
      // advert becomes the whole controller and the right puck's builds nothing
      // at all (see BluetoothDevice.fromScanResult) — which is what drops the
      // separate right-side entry the rider is looking at.
      // forget: false drops the cached scan result; persistForget: false keeps
      // the puck off the ignored list so it can come straight back.
      final clicks = core.connection.bluetoothDevices
          .where((d) => d is ZwiftClickV2 || d is ZwiftClickV2RightSide)
          .toList();
      for (final device in clicks) {
        await core.connection.disconnect(device, forget: false, persistForget: false);
      }
      // A full restart, not just performScanning(): that returns immediately
      // while a scan is already running, and the scanner dedupes against its
      // cached adverts, so without clearing them the pucks are never
      // rediscovered and the unified controller is never built.
      await core.connection.stop();
      await core.connection.performScanning();
      return;
    }
    await _connectPending();
  }

  static Future<void> _complete() async {
    await core.settings.setClickV2OnboardingDone(true);
  }

  static Future<void> _connectPending() async {
    for (final device in pendingDevices) {
      // pendingDevices is not gated on isPending (see its doc comment) and
      // returns every disconnected Click V2 side, including one the battery
      // saver deliberately put to sleep. Connecting it here would undo that
      // the moment the rider finishes an unrelated onboarding choice.
      if (core.connection.isAutoReconnectSuppressed(device)) continue;
      try {
        await core.connection.connectDevice(device);
      } catch (e, stack) {
        recordError(e, stack, context: 'ClickV2Onboarding.connectPending');
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_ERROR, AppLocalizations.current.clickV2Onboarding_connectFailed),
        );
      }
    }
  }
}
