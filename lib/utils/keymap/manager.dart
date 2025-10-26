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

  Future<String?> showManageProfileDialog(BuildContext context, String? currentProfile) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Profile: ${currentProfile ?? ''}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentProfile != null && actionHandler.supportedApp is CustomApp)
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Rename'),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
            if (currentProfile != null)
              ListTile(
                leading: Icon(Icons.copy),
                title: Text('Duplicate'),
                onTap: () => Navigator.pop(context, 'duplicate'),
              ),
            ListTile(
              leading: Icon(Icons.file_upload),
              title: Text('Import'),
              onTap: () => Navigator.pop(context, 'import'),
            ),
            if (currentProfile != null)
              ListTile(
                leading: Icon(Icons.share),
                title: Text('Export'),
                onTap: () => Navigator.pop(context, 'export'),
              ),
            if (currentProfile != null)
              ListTile(
                leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'))],
      ),
    );
  }

  Future<String?> showRenameProfileDialog(BuildContext context, String currentName) async {
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

  Future<String?> showDuplicateProfileDialog(BuildContext context, String currentName) async {
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

  Future<bool?> showDeleteConfirmDialog(BuildContext context, String profileName) async {
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

  Future<String?> showImportDialog(BuildContext context) async {
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
    final newName = await showDuplicateProfileDialog(context, currentProfile);
    if (newName != null && newName.isNotEmpty) {
      if (actionHandler.supportedApp is CustomApp) {
        await settings.duplicateCustomAppProfile(currentProfile, newName);
        final customApp = CustomApp(profileName: newName);
        final savedKeymap = settings.getCustomAppKeymap(newName);
        if (savedKeymap != null) {
          customApp.decodeKeymap(savedKeymap);
        }
        actionHandler.supportedApp = customApp;
        await settings.setApp(customApp);
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
        await settings.setApp(customApp);
        return newName;
      }
    }
    return null;
  }
}
