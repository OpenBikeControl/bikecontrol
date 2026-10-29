import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;

/// The devices kept from connecting: the ignore list, and the controllers
/// disconnected for this session — each with the way back.
class IgnoredDevicesDialog extends StatefulWidget {
  const IgnoredDevicesDialog({super.key});

  @override
  State<IgnoredDevicesDialog> createState() => _IgnoredDevicesDialogState();
}

class _IgnoredDevicesDialogState extends State<IgnoredDevicesDialog> {
  List<({String id, String name})> _ignoredDevices = [];

  @override
  void initState() {
    super.initState();
    _loadIgnoredDevices();
  }

  void _loadIgnoredDevices() {
    setState(() {
      _ignoredDevices = core.settings.getIgnoredDevices();
    });
  }

  Future<void> _removeDevice(String deviceId) async {
    await core.settings.removeIgnoredDevice(deviceId);
    await core.connection.stop();
    await core.connection.performScanning();
    _loadIgnoredDevices();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: core.connection.disconnectedForSession,
      builder: (context, session, _) {
        final empty = _ignoredDevices.isEmpty && session.isEmpty;
        return AlertDialog(
          title: Text(context.i18n.ignoredDevices),
          content: SizedBox(
            width: double.maxFinite,
            child: empty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      context.i18n.noIgnoredDevices,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final device in _ignoredDevices)
                        ListTile(
                          title: Text(device.name),
                          subtitle: Text(
                            device.id,
                            style: context.typography.xSmall,
                          ),
                          trailing: BkIconButton.ghost(
                            icon: Icon(LucideIcons.trash2),
                            label: context.i18n.removeFromIgnoredList,
                            onPressed: () => _removeDevice(device.id),
                          ),
                        ),
                      if (session.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, _ignoredDevices.isEmpty ? 0 : 16, 16, 4),
                          child: Text(
                            context.i18n.disconnectedForThisSession,
                            style: context.typography.xSmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        for (final MapEntry(key: id, value: name) in session.entries)
                          ListTile(
                            title: Text(name),
                            subtitle: Text(id, style: context.typography.xSmall),
                            trailing: BkIconButton.ghost(
                              key: ValueKey('session-reconnect-$id'),
                              icon: Icon(LucideIcons.bluetooth),
                              label: context.i18n.reconnect,
                              onPressed: () => core.connection.reconnectForSession(id),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.i18n.close),
            ),
          ],
        );
      },
    );
  }
}
