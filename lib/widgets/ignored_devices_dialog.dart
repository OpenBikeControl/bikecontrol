import 'package:flutter/material.dart';
import 'package:swift_control/utils/core.dart';

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
    _loadIgnoredDevices();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ignored Devices'),
      content: SizedBox(
        width: double.maxFinite,
        child: _ignoredDevices.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No ignored devices.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _ignoredDevices.length,
                itemBuilder: (context, index) {
                  final device = _ignoredDevices[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text(
                      device.id,
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline),
                      tooltip: 'Remove from ignored list',
                      onPressed: () => _removeDevice(device.id),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}
