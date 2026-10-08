import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/device_limit_reached_error.dart';
import 'package:bike_control/models/user_device.dart';
import 'package:bike_control/pages/home/chain_state.dart' show LinkStatus;
import 'package:bike_control/utils/plan_format.dart';
import 'package:bike_control/widgets/home/ampel.dart' show AmpelStyle;
import 'package:bike_control/widgets/register_this_device.dart' show devicePlatformLabel;
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The account's registered devices, inline on Plan & account: this device
/// marked (or listed as not registered), the others removable, and at the
/// platform's limit the note that removing one frees the slot.
class RegisteredDevicesSection extends StatelessWidget {
  const RegisteredDevicesSection({
    super.key,
    required this.header,
    required this.devices,
    required this.failed,
    required this.onRetry,
    required this.currentDeviceId,
    required this.currentPlatform,
    required this.thisDeviceRegistered,
    required this.limit,
    required this.removing,
    required this.onRemove,
    this.leadingRows = const [],
  });

  final String header;

  /// Rows above the devices (the sync row, in a wide window).
  final List<Widget> leadingRows;

  /// Null while loading.
  final List<UserDevice>? devices;
  final bool failed;
  final VoidCallback onRetry;
  final String? currentDeviceId;
  final String? currentPlatform;
  final bool thisDeviceRegistered;
  final DeviceLimitReachedError? limit;

  /// Device ids being removed right now.
  final Set<String> removing;
  final void Function(UserDevice device, String name) onRemove;

  /// The device's own name, unless it is the generic one the app registers
  /// with ("BikeControl IOS"): then its platform.
  static String deviceTitle(UserDevice device) {
    final name = device.deviceName?.trim();
    if (name == null || name.isEmpty || RegExp(r'^BikeControl\b', caseSensitive: false).hasMatch(name)) {
      return devicePlatformLabel(device.platform);
    }
    return name;
  }

  static IconData platformIcon(String? platform) => switch (platform?.toLowerCase()) {
    'ios' || 'android' => LucideIcons.smartphone,
    'macos' => LucideIcons.laptop,
    'windows' => LucideIcons.monitor,
    _ => LucideIcons.monitorSmartphone,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final list = devices;
    final active = list?.where((d) => d.isActive).toList() ?? const <UserDevice>[];
    final revoked = list?.where((d) => d.isRevoked).toList() ?? const <UserDevice>[];
    final thisListed = active.any((d) => d.deviceId == currentDeviceId);
    final cs = Theme.of(context).colorScheme;

    final rows = <Widget>[
      ...leadingRows,
      if (limit case final limit?)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Icon(
                LucideIcons.triangleAlert,
                size: 16,
                color: AmpelStyle.of(context, LinkStatus.attention).text,
              ),
              Expanded(
                child: Text(
                  l10n.deviceLimitRemoveOne(devicePlatformLabel(limit.platform)),
                  style: context.typography.small,
                ),
              ),
            ],
          ),
        ),
      if (failed && list == null)
        BkGroupedRow(
          icon: LucideIcons.circleAlert,
          title: l10n.devicesLoadFailed,
          trailing: Button.ghost(onPressed: onRetry, child: Text(l10n.retry)),
        )
      else if (list == null)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: SmallProgressIndicator()),
        )
      else ...[
        if (!thisDeviceRegistered && !thisListed)
          BkGroupedRow(
            key: const ValueKey('plan-device-unregistered'),
            icon: platformIcon(currentPlatform),
            title: l10n.thisDevice,
            badge: _Tag(l10n.deviceNotRegistered, warning: true),
            subtitle: currentPlatform == null ? null : devicePlatformLabel(currentPlatform!),
          ),
        for (final device in [...active, ...revoked]) _row(context, device),
      ],
    ];

    return BkGroupedSection(
      header: header,
      headerTrailing: list == null || active.isEmpty
          ? null
          : Text(
              l10n.devicesRegisteredCount(active.length),
              style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
            ),
      children: rows,
    );
  }

  Widget _row(BuildContext context, UserDevice device) {
    final l10n = AppLocalizations.of(context);
    final isThis = device.deviceId == currentDeviceId && device.isActive;
    final title = deviceTitle(device);
    final seen = device.lastSeenAt;
    final subtitle = [
      devicePlatformLabel(device.platform),
      if (seen != null) isThis ? '${l10n.lastSeen} ${formatRelativeTime(l10n, seen)}' : formatPlanDate(seen),
    ].join(' · ');
    final Widget? trailing;
    if (device.isRevoked) {
      trailing = Text(l10n.deviceRemoved);
    } else if (isThis) {
      trailing = null;
    } else if (removing.contains(device.deviceId)) {
      trailing = const SmallProgressIndicator();
    } else {
      trailing = BkTouchTarget(
        child: Button.ghost(
          onPressed: () => onRemove(device, title),
          child: Text(
            l10n.removeDevice,
            style: context.typography.small.copyWith(color: bkAccentText(context), fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return Opacity(
      opacity: device.isRevoked ? 0.6 : 1,
      child: BkGroupedRow(
        key: ValueKey('plan-device-${device.deviceId}'),
        icon: platformIcon(device.platform),
        title: title,
        badge: isThis ? _Tag(l10n.thisDevice) : null,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final attention = AmpelStyle.of(context, LinkStatus.attention);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: warning ? attention.wash : cs.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: context.typography.xSmall.copyWith(
          color: warning ? attention.text : bkAccentText(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
