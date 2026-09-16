import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/models/device_limit_reached_error.dart';
import 'package:bike_control/pages/subscription.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Registers this device for the account's Pro subscription — the same call
/// the Registered Devices view makes — and reports the outcome. Resolves to
/// true once Pro is enabled for this device.
///
/// A platform at its device limit needs a decision (which device to revoke),
/// so that case opens the Registered Devices view instead of just failing.
Future<bool> registerThisDevice(BuildContext context) async {
  final iap = IAPManager.instance;
  try {
    await iap.registerCurrentDevice();
  } on DeviceLimitReachedError catch (e, s) {
    recordError(e, s, context: 'Register this device: limit reached');
    buildToast(
      level: LogLevel.LOGLEVEL_WARNING,
      title: AppLocalizations.current.deviceLimitReached(e.platform.capitalize().replaceAll('os', 'OS')),
    );
    // Not awaited: the view stays open until the rider is done with it, and
    // the button that started this should not sit on its spinner meanwhile.
    if (context.mounted) unawaited(openRegisteredDevices(context));
    return false;
  } catch (e, s) {
    recordError(e, s, context: 'Register this device');
    buildToast(level: LogLevel.LOGLEVEL_ERROR, title: 'Could not register device: $e');
    return false;
  }
  return iap.isProEnabledForCurrentDevice;
}

/// Opens the Subscription page on its Registered Devices view: as a drawer
/// where a Scaffold's DrawerOverlay is in scope, else as a dialog — a
/// post-purchase dialog on the root navigator has no overlay above it, and
/// openDrawer does `parentLayer!` without one.
Future<void> openRegisteredDevices(BuildContext context) {
  Widget page(BuildContext c) => const SubscriptionPage(initialView: SubscriptionPageView.devices);
  if (DrawerOverlay.maybeFind(context) == null) {
    return showDialog<void>(context: context, builder: page);
  }
  return openDrawer<void>(context: context, builder: page, position: OverlayPosition.end);
}

/// The "Register this device" button with its own busy state. [register] is
/// swappable for tests; production runs [registerThisDevice].
class RegisterThisDeviceButton extends StatelessWidget {
  final Future<bool> Function(BuildContext context)? register;

  /// Called after an attempt, with whether this device is now registered.
  final void Function(bool registered)? onDone;
  final ButtonSize size;

  const RegisterThisDeviceButton({
    super.key,
    this.register,
    this.onDone,
    this.size = ButtonSize.normal,
  });

  @override
  Widget build(BuildContext context) {
    return LoadingWidget(
      futureCallback: () async {
        final registered = await (register ?? registerThisDevice)(context);
        onDone?.call(registered);
      },
      // Icon + label as a shrink-wrapped Row, the way the Registered Devices
      // view builds its buttons: shadcn's `leading:` slot mirrors its width
      // on the trailing side, which leaves the button oddly wide.
      renderChild: (isLoading, tap) => PrimaryButton(
        size: size,
        onPressed: tap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) const SmallProgressIndicator() else const Icon(Icons.devices, size: 16),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).registerThisDevice),
          ],
        ),
      ),
    );
  }
}
