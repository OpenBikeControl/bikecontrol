import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/widgets/ui/toast.dart';

import 'apps/custom_app.dart';

class KeymapManager {
  // Singleton instance
  static final KeymapManager _instance = KeymapManager._internal();

  // Private constructor
  KeymapManager._internal();

  // Factory constructor to return the singleton instance
  factory KeymapManager() {
    return _instance;
  }

  Future<String?> showNewProfileDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Custom Profile'),
        content: TextField(
          controller: controller,
          hintText: 'Profile name',
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('Create')),
        ],
      ),
    );
  }

  Widget getManageProfileDialog(
    BuildContext context,
    String? currentProfile, {
    required VoidCallback onDone,
  }) {
    return Builder(
      builder: (context) {
        return OutlineButton(
          child: Icon(Icons.more_vert),
          onPressed: () => showDropdown(
            context: context,
            builder: (c) => DropdownMenu(
              children: [
                if (currentProfile != null && actionHandler.supportedApp is CustomApp)
                  MenuButton(
                    child: Text('Rename'),
                    onPressed: (c) async {
                      final newName = await _showRenameProfileDialog(
                        context,
                        currentProfile,
                      );
                      if (newName != null && newName.isNotEmpty && newName != currentProfile) {
                        await settings.duplicateCustomAppProfile(currentProfile, newName);
                        await settings.deleteCustomAppProfile(currentProfile);
                        final customApp = CustomApp(profileName: newName);
                        final savedKeymap = settings.getCustomAppKeymap(newName);
                        if (savedKeymap != null) {
                          customApp.decodeKeymap(savedKeymap);
                        }
                        actionHandler.supportedApp = customApp;
                        await settings.setKeyMap(customApp);
                      }
                      onDone();
                    },
                  ),
                if (currentProfile != null)
                  MenuButton(
                    child: Text('Duplicate'),
                    onPressed: (c) async {
                      final newName = await duplicate(
                        context,
                        currentProfile,
                      );
                      onDone();
                    },
                  ),
                MenuButton(
                  child: Text('Import'),
                  onPressed: (c) async {
                    final jsonData = await _showImportDialog(context);
                    if (jsonData != null && jsonData.isNotEmpty) {
                      final success = await settings.importCustomAppProfile(jsonData);
                      if (success) {
                        showToast(
                          context: context,
                          builder: (c, overlay) => buildToast(context, overlay, title: 'Profile imported successfully'),
                        );
                      } else {
                        showToast(
                          context: context,
                          builder: (c, overlay) =>
                              buildToast(context, overlay, title: 'Failed to import profile. Invalid format.'),
                        );
                      }
                    }
                  },
                ),
                if (currentProfile != null)
                  MenuButton(
                    child: Text('Export'),
                    onPressed: (c) {
                      final currentProfile = (actionHandler.supportedApp as CustomApp).profileName;
                      final jsonData = settings.exportCustomAppProfile(currentProfile);
                      if (jsonData != null) {
                        Clipboard.setData(ClipboardData(text: jsonData));

                        showToast(
                          context: context,
                          builder: (c, overlay) =>
                              buildToast(context, overlay, title: 'Profile "$currentProfile" exported to clipboard'),
                        );
                      }
                    },
                  ),
                if (currentProfile != null)
                  MenuButton(
                    onPressed: (c) async {
                      final confirmed = await _showDeleteConfirmDialog(
                        context,
                        currentProfile,
                      );
                      if (confirmed == true) {
                        await settings.deleteCustomAppProfile(currentProfile);
                      }
                      onDone();
                    },
                    child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.destructive)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showRenameProfileDialog(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename Profile'),
        content: TextField(
          controller: controller,
          hintText: 'Profile Name',
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('Rename')),
        ],
      ),
    );
  }

  Future<String?> _showDuplicateProfileDialog(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: '$currentName (Copy)');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create new custom profile by duplicating "$currentName"'),
        content: TextField(
          controller: controller,
          placeholder: Text('New Profile name'),
          hintText: 'New Profile Name',
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('Duplicate')),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog(BuildContext context, String profileName) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Profile'),
        content: Text('Are you sure you want to delete "$profileName"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showImportDialog(BuildContext context) async {
    final controller = TextEditingController();

    // Try to get data from clipboard
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text != null) {
        controller.text = clipboardData!.text!;
      }
    } catch (e) {
      // Ignore clipboard errors
    }

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Import Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paste the exported JSON data below:'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              hintText: 'JSON Data',
              border: Border(),
              maxLines: 5,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('Import')),
        ],
      ),
    );
  }

  Future<String?> duplicate(BuildContext context, String currentProfile, {String? skipName}) async {
    final newName = skipName ?? await _showDuplicateProfileDialog(context, currentProfile);
    if (newName != null && newName.isNotEmpty) {
      if (actionHandler.supportedApp is CustomApp) {
        await settings.duplicateCustomAppProfile(currentProfile, newName);
        final customApp = CustomApp(profileName: newName);
        final savedKeymap = settings.getCustomAppKeymap(newName);
        if (savedKeymap != null) {
          customApp.decodeKeymap(savedKeymap);
        }
        actionHandler.supportedApp = customApp;
        await settings.setKeyMap(customApp);
        return newName;
      } else {
        final customApp = CustomApp(profileName: newName);

        final connectedDevice = connection.devices.firstOrNull;
        actionHandler.supportedApp!.keymap.keyPairs.forEachIndexed((pair, index) {
          pair.buttons.filter((button) => connectedDevice?.availableButtons.contains(button) == true).forEachIndexed((
            button,
            indexB,
          ) {
            customApp.setKey(
              button,
              physicalKey: pair.physicalKey,
              logicalKey: pair.logicalKey,
              isLongPress: pair.isLongPress,
              touchPosition: pair.touchPosition,
              inGameAction: pair.inGameAction,
              inGameActionValue: pair.inGameActionValue,
            );
          });
        });

        actionHandler.supportedApp = customApp;
        await settings.setKeyMap(customApp);
        return newName;
      }
    }
    return null;
  }
}
