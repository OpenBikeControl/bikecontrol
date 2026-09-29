import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/services/local_network_access.dart';
import 'package:bike_control/utils/demo_mode.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:flutter/foundation.dart';
import 'package:local_network_permission/local_network_permission.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Gates the LAN bridging methods (MyWhoosh Link, Zwift/OpenBikeControl mDNS)
/// on Apple's Local Network permission.
///
/// Unlike every other requirement here there is no "request" step to speak
/// of: the probe behind [getStatus] *is* the request, because the system
/// prompt fires on the first Bonjour operation. Once the user has answered,
/// [call] is the only way back — the prompt never returns.
class LocalNetworkRequirement extends PlatformRequirement {
  LocalNetworkRequirement()
    : super(
        AppLocalizations.current.localNetworkAccess,
        description: !kIsWeb && Platform.isIOS
            ? AppLocalizations.current.localNetworkAccessDeniedIos
            : AppLocalizations.current.localNetworkAccessDeniedMacos,
        icon: LucideIcons.radioTower,
      );

  /// Only a positive denial blocks the user.
  ///
  /// [LocalNetworkStatus.unknown] means the probe could not tell — no usable
  /// network, or a build without the plugin — and failing closed on that would
  /// break setups that work today.
  @override
  Future<bool> getStatus() async {
    status = await LocalNetworkAccess.isUsable();
    return status;
  }

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    await LocalNetworkPermission.openSettings();
    // Whatever we cached stopped being true the moment the user left for
    // System Settings; the resume path re-reads the status from scratch.
    LocalNetworkAccess.invalidate();
    onUpdate();
  }
}

/// The Local Network requirement on the platforms that have one, else nothing.
///
/// Suppressed for screenshots and demos alongside every other permission, so
/// a machine that happens to have the toggle off can't silently switch the
/// bridging methods back off mid-capture.
List<PlatformRequirement> localNetworkRequirements() {
  if (screenshotMode || demoHidePermissions) return const [];
  if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) return const [];
  return [LocalNetworkRequirement()];
}
