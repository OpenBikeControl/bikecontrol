import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/main.dart';

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
          decoration: InputDecoration(labelText: 'Profile Name', hintText: 'e.g., Workout, Race, Event'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('Create')),
        ],
      ),
    );
  }

  PopupMenuButton<String> getManageProfileDialog(BuildContext context, String? currentProfile) {
    return PopupMenuButton(
      itemBuilder: (context) => [
        if (currentProfile != null && actionHandler.supportedApp is CustomApp)
          PopupMenuItem(
            child: Text('Rename'),
            onTap: () async {
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
                await settings.setSupportedApp(customApp);
              }
            },
          ),
        if (currentProfile != null)
          PopupMenuItem(
            child: Text('Duplicate'),
            onTap: () async {
              final newName = await duplicate(
                context,
                currentProfile,
              );
            },
          ),
        PopupMenuItem(
          child: Text('Import'),
          onTap: () async {
            final jsonData = await _showImportDialog(context);
            if (jsonData != null && jsonData.isNotEmpty) {
              final success = await settings.importCustomAppProfile(jsonData);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Profile imported successfully'),
                    duration: Duration(seconds: 5),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to import profile. Invalid format.'),
                    duration: Duration(seconds: 5),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
        if (currentProfile != null)
          PopupMenuItem(
            child: Text('Export'),
            onTap: () {
              final currentProfile = (actionHandler.supportedApp as CustomApp).profileName;
              final jsonData = settings.exportCustomAppProfile(currentProfile);
              if (jsonData != null) {
                Clipboard.setData(ClipboardData(text: jsonData));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Profile "$currentProfile" exported to clipboard',
                    ),
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            },
          ),
        if (currentProfile != null)
          PopupMenuItem(
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              final confirmed = await _showDeleteConfirmDialog(
                context,
                currentProfile,
              );
              if (confirmed == true) {
                await settings.deleteCustomAppProfile(currentProfile);
              }
            },
          ),
      ],
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
          decoration: InputDecoration(labelText: 'Profile Name'),
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
          decoration: InputDecoration(labelText: 'New Profile Name'),
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
              decoration: InputDecoration(labelText: 'JSON Data', border: OutlineInputBorder()),
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

  Future<String?> duplicate(BuildContext context, String currentProfile) async {
    final newName = await _showDuplicateProfileDialog(context, currentProfile);
    if (newName != null && newName.isNotEmpty) {
      if (actionHandler.supportedApp is CustomApp) {
        await settings.duplicateCustomAppProfile(currentProfile, newName);
        final customApp = CustomApp(profileName: newName);
        final savedKeymap = settings.getCustomAppKeymap(newName);
        if (savedKeymap != null) {
          customApp.decodeKeymap(savedKeymap);
        }
        actionHandler.supportedApp = customApp;
        await settings.setSupportedApp(customApp);
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
              touchPosition: pair.touchPosition != Offset.zero
                  ? pair.touchPosition
                  : Offset(((indexB + 1)) * 10, 20 + (index * 10)),
            );
          });
        });

        actionHandler.supportedApp = customApp;
        await settings.setSupportedApp(customApp);
        return newName;
      }
    }
    return null;
  }
}
