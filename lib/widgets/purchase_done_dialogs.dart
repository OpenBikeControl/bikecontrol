import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/models/device_limit_reached_error.dart';
import 'package:bike_control/pages/plan/plan_account_page.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:bike_control/widgets/menu.dart' show debugText;
import 'package:bike_control/widgets/register_this_device.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// After a Base purchase: what Base covers and, above all, what it doesn't.
/// Riders who bought Base for BikeControl-driven virtual shifting found out
/// about the daily limit the hard way — say it at the moment of purchase.
Future<void> showPurchaseBaseDoneDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (c) {
      final l10n = AppLocalizations.of(c);
      return Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AlertDialog(
          title: Row(
            children: [
              Icon(LucideIcons.badgeCheck, color: BkStatusColors.of(context).success),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.purchaseBaseDoneTitle)),
            ],
          ),
          content: Text(l10n.purchaseBaseDoneBody),
          actions: [
            PrimaryButton(
              onPressed: () => Navigator.of(c).pop(),
              child: Text(l10n.gotIt),
            ),
          ],
        ),
      );
    },
  );
}

/// After a Pro purchase or restore while signed out: Pro works here, and
/// signing in brings it to the rider's other devices. "Sign in" opens Plan &
/// account, where sign-in lives; [openSignIn] is a test seam for that.
Future<void> showPurchaseProSignInDialog(
  BuildContext context, {
  Future<void> Function(BuildContext context)? openSignIn,
}) {
  return showDialog<void>(
    context: context,
    builder: (c) {
      final l10n = AppLocalizations.of(c);
      return Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AlertDialog(
          title: Row(
            children: [
              Icon(LucideIcons.crown, color: BkTheme.proOrange),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.purchaseProSignInTitle)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.purchaseProSignInBody),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Button.ghost(
                    onPressed: () => Navigator.of(c).pop(),
                    child: Text(l10n.onboardingNotNow),
                  ),
                  PrimaryButton(
                    key: const ValueKey('purchase-pro-sign-in'),
                    onPressed: () {
                      Navigator.of(c).pop();
                      if (!context.mounted) return;
                      unawaited((openSignIn ?? openPlanAccount)(context));
                    },
                    child: Text(l10n.signIn),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// After a Pro purchase or restore that leaves Pro on the account but not on
/// this device: say so, and offer the registration right there instead of
/// leaving "Pro (unregistered device)" in the title bar as the only clue.
///
/// Registering at the device limit closes this dialog and shows
/// [showProDeviceLimitDialog] in its place. The trailing parameters are test
/// seams for the registration and that dialog's actions.
Future<void> showPurchaseProUnregisteredDialog(
  BuildContext context, {
  Future<void> Function()? registerCall,
  Future<void> Function(BuildContext context)? manageDevices,
  Future<bool> Function()? retryRegistration,
  void Function(BuildContext context, DeviceLimitReachedError error)? contactSupport,
}) {
  return showDialog<void>(
    context: context,
    builder: (c) {
      final l10n = AppLocalizations.of(c);
      return Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AlertDialog(
          title: Row(
            children: [
              Icon(LucideIcons.crown, color: BkTheme.proOrange),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.purchaseProDoneTitle)),
            ],
          ),
          // Two buttons, one of them long in most languages: AlertDialog's
          // `actions` is a plain Row, so they live in the content instead,
          // where a Wrap gets a bounded width and can fall onto two lines.
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.purchaseProUnregisteredBody),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Button.secondary(
                    onPressed: () => Navigator.of(c).pop(),
                    child: Text(l10n.close),
                  ),
                  RegisterThisDeviceButton(
                    register: (buttonContext) => registerThisDevice(
                      buttonContext,
                      registerCall: registerCall,
                      onDeviceLimit: (error) {
                        if (c.mounted) Navigator.of(c).pop();
                        if (!context.mounted) return;
                        unawaited(
                          showProDeviceLimitDialog(
                            context,
                            error,
                            manageDevices: manageDevices,
                            retryRegistration: retryRegistration,
                            contactSupport: contactSupport,
                          ),
                        );
                      },
                    ),
                    onDone: (registered) {
                      if (registered && c.mounted) Navigator.of(c).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// After a Pro purchase or restore that the account's device limit kept from
/// reaching this device: Pro is on the account, but this device can't be
/// activated until another one is removed.
///
/// "Manage devices" closes this dialog, opens the Registered Devices view and,
/// once that is closed, registers this device again. "Get support" closes it
/// and opens the support chat with the limit details attached; "Not now"
/// just closes it. The trailing
/// parameters are test seams; production uses [openRegisteredDevices],
/// [IAPManager.registerCurrentDevice] and the support chat.
Future<void> showProDeviceLimitDialog(
  BuildContext context,
  DeviceLimitReachedError error, {
  Future<void> Function(BuildContext context)? manageDevices,
  Future<bool> Function()? retryRegistration,
  void Function(BuildContext context, DeviceLimitReachedError error)? contactSupport,
}) {
  return showDialog<void>(
    context: context,
    builder: (c) {
      final l10n = AppLocalizations.of(c);
      return Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AlertDialog(
          title: Row(
            children: [
              Icon(LucideIcons.crown, color: BkTheme.proOrange),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.purchaseProDeviceLimitTitle)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.purchaseProDeviceLimitBody('${error.maxDevices}', devicePlatformLabel(error.platform))),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Button.ghost(
                    onPressed: () => Navigator.of(c).pop(),
                    child: Text(l10n.onboardingNotNow),
                  ),
                  Button.secondary(
                    onPressed: () {
                      Navigator.of(c).pop();
                      if (!context.mounted) return;
                      (contactSupport ?? _contactSupportAboutLimit)(context, error);
                    },
                    child: Text(l10n.getSupport),
                  ),
                  PrimaryButton(
                    onPressed: () {
                      Navigator.of(c).pop();
                      if (!context.mounted) return;
                      unawaited(
                        _manageThenRetry(
                          context,
                          manageDevices: manageDevices ?? openRegisteredDevices,
                          retryRegistration: retryRegistration ?? _retryRegistration,
                        ),
                      );
                    },
                    child: Text(l10n.purchaseManageDevices),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _manageThenRetry(
  BuildContext context, {
  required Future<void> Function(BuildContext context) manageDevices,
  required Future<bool> Function() retryRegistration,
}) async {
  try {
    await manageDevices(context);
    final registered = await retryRegistration();
    if (registered) {
      buildToast(level: LogLevel.LOGLEVEL_INFO, title: AppLocalizations.current.purchaseProActiveOnDevice);
    }
  } catch (e, s) {
    recordError(e, s, context: 'Device limit: manage devices and retry');
  }
}

/// Registers this device again after the rider has managed their devices.
/// Still at the limit is an expected answer, said with a toast.
Future<bool> _retryRegistration() async {
  final iap = IAPManager.instance;
  try {
    await iap.registerCurrentDevice();
    return iap.isProEnabledForCurrentDevice;
  } on DeviceLimitReachedError catch (e) {
    buildToast(
      level: LogLevel.LOGLEVEL_WARNING,
      title: AppLocalizations.current.deviceLimitReached(devicePlatformLabel(e.platform)),
    );
    return false;
  } catch (e, s) {
    recordError(e, s, context: 'Device limit: retry registration');
    buildToast(level: LogLevel.LOGLEVEL_ERROR, title: AppLocalizations.current.registerDeviceFailedRetry);
    return false;
  }
}

void _contactSupportAboutLimit(BuildContext context, DeviceLimitReachedError error) {
  final devices = error.devices.map((d) => d.deviceName ?? d.deviceId).join(', ');
  unawaited(
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SupportChatPage(
          diagnosticPreviewFuture: debugText(),
          initialIntake: const IntakeAnswers(
            category: IntakeCategory.account,
            subcategory: 'issue',
            subcategoryValue: 'wrong_plan_shown',
          ),
          pinnedContext:
              'Device limit reached after Pro purchase: platform=${error.platform}, max=${error.maxDevices}'
              '${devices.isEmpty ? '' : ', devices=$devices'}',
          pinnedContextLabel: AppLocalizations.of(context).supportPinnedDeviceLimit,
          telemetryBuilder: () async => TelemetrySnapshot.general(freetext: await debugText()),
        ),
      ),
    ),
  );
}
