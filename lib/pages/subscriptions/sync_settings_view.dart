import 'package:shadcn_flutter/shadcn_flutter.dart';

class SyncSettingsView extends StatefulWidget {
  const SyncSettingsView({super.key});

  @override
  State<SyncSettingsView> createState() => _SyncSettingsViewState();
}

class _SyncSettingsViewState extends State<SyncSettingsView> {
  bool _isSyncingSettings = false;

  Future<void> _syncSettings() async {
    setState(() {
      _isSyncingSettings = true;
    });

    await Future.delayed(Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isSyncingSettings = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 24,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sync Status Card
          Card(
            child: Column(
              spacing: 16,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_sync,
                        size: 28,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sync Status').small.muted,
                          Text('Settings Synchronization').large.bold,
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(),
                Text(
                  'Synchronize your app settings across all your devices. This includes your keymaps, button configurations, and preferences.',
                ).small.muted,
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.muted.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                          const SizedBox(width: 8),
                          Text('Last synced: Never').small,
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.devices, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                          const SizedBox(width: 8),
                          Text('Synced devices: 0').small,
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sync Now Button
          if (_isSyncingSettings)
            Card(
              filled: true,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  spacing: 16,
                  children: [
                    CircularProgressIndicator(),
                    Text('Syncing your settings...').small.muted,
                  ],
                ),
              ),
            )
          else
            Button.primary(
              onPressed: _syncSettings,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_sync, size: 20),
                  const SizedBox(width: 12),
                  Text('Sync Now'),
                ],
              ),
            ),

          // Info Card
          Card(
            filled: true,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                spacing: 12,
                children: [
                  Icon(Icons.info, size: 20, color: Theme.of(context).colorScheme.primary),
                  Expanded(
                    child: Text(
                      'Your settings will be securely stored and synchronized across all devices logged into your account.',
                    ).small.muted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
