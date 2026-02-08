import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
        title: Text(context.i18n.newCustomProfile),
        content: TextField(
          controller: controller,
          hintText: context.i18n.profileName,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.i18n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(context.i18n.create)),
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
        return Button.outline(
          child: Icon(Icons.settings),
          onPressed: () => showDropdown(
            context: context,
            builder: (c) => DropdownMenu(
              children: [
                if (currentProfile != null && core.actionHandler.supportedApp is CustomApp)
                  MenuButton(
                    child: Text(context.i18n.rename),
                    onPressed: (c) async {
                      final newName = await _showRenameProfileDialog(
                        context,
                        currentProfile,
                      );
                      if (newName != null && newName.isNotEmpty && newName != currentProfile) {
                        await core.settings.duplicateCustomAppProfile(currentProfile, newName);
                        await core.settings.deleteCustomAppProfile(currentProfile);
                        final customApp = CustomApp(profileName: newName);
                        final savedKeymap = core.settings.getCustomAppKeymap(newName);
                        if (savedKeymap != null) {
                          customApp.decodeKeymap(savedKeymap);
                        }
                        core.actionHandler.supportedApp = customApp;
                        await core.settings.setKeyMap(customApp);
                      }
                      onDone();
                    },
                  ),
                if (currentProfile != null)
                  MenuButton(
                    child: Text(context.i18n.duplicate),
                    onPressed: (c) async {
                      final newName = await duplicate(
                        context,
                        currentProfile,
                      );
                      onDone();
                    },
                  ),
                MenuButton(
                  child: Text(context.i18n.importAction),
                  onPressed: (c) async {
                    final jsonData = await _showImportDialog(context);
                    if (jsonData != null && jsonData.isNotEmpty) {
                      final success = await core.settings.importCustomAppProfile(jsonData);
                      if (success) {
                        buildToast(title: context.i18n.profileImportedSuccessfully);
                      } else {
                        buildToast(title: context.i18n.failedToImportProfile);
                      }
                    }
                  },
                ),
                if (currentProfile != null)
                  MenuButton(
                    child: Text(context.i18n.exportAction),
                    onPressed: (c) {
                      final currentProfile = (core.actionHandler.supportedApp as CustomApp).profileName;
                      final jsonData = core.settings.exportCustomAppProfile(currentProfile);
                      if (jsonData != null) {
                        Clipboard.setData(ClipboardData(text: jsonData));

                        buildToast(title: context.i18n.profileExportedToClipboard(currentProfile));
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
                        await core.settings.deleteCustomAppProfile(currentProfile);
                      }
                      onDone();
                    },
                    child: Text(
                      context.i18n.delete,
                      style: TextStyle(color: Theme.of(context).colorScheme.destructive),
                    ),
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
        title: Text(context.i18n.renameProfile),
        content: TextField(
          controller: controller,
          hintText: context.i18n.profileName,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.i18n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(context.i18n.rename)),
        ],
      ),
    );
  }

  Future<String?> _showDuplicateProfileDialog(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: '$currentName (Copy)');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.i18n.createNewProfileByDuplicating(currentName)),
        content: TextField(
          controller: controller,
          placeholder: Text(context.i18n.newProfileName),
          hintText: context.i18n.newProfileName,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.i18n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(context.i18n.duplicate)),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog(BuildContext context, String profileName) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.i18n.deleteProfile),
        content: Text(context.i18n.deleteProfileConfirmation(profileName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.i18n.cancel)),
          DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.i18n.delete),
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
        title: Text(context.i18n.importProfile),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.i18n.pasteExportedJsonData),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              hintText: context.i18n.jsonData,
              border: Border(),
              maxLines: 5,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.i18n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(context.i18n.importAction)),
        ],
      ),
    );
  }

  Future<String?> duplicate(BuildContext? context, String currentProfile, {String? skipName}) async {
    final newName = skipName ?? await _showDuplicateProfileDialog(context!, currentProfile);
    if (newName != null && newName.isNotEmpty) {
      if (core.actionHandler.supportedApp is CustomApp) {
        await core.settings.duplicateCustomAppProfile(currentProfile, newName);
        final customApp = CustomApp(profileName: newName);
        final savedKeymap = core.settings.getCustomAppKeymap(newName);
        if (savedKeymap != null) {
          customApp.decodeKeymap(savedKeymap);
        }
        core.actionHandler.supportedApp = customApp;
        await core.settings.setKeyMap(customApp);
        return newName;
      } else {
        final customApp = CustomApp(profileName: newName);

        final connectedDeviceButtons = IterableFlatMap(
          core.connection.controllerDevices,
        ).flatMap((e) => e.availableButtons).toSet();
        core.actionHandler.supportedApp!.keymap.keyPairs.forEachIndexed((pair, index) {
          pair.buttons.filter((button) => connectedDeviceButtons.contains(button) == true).forEachIndexed((
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
              modifiers: pair.modifiers,
            );
          });
        });

        core.actionHandler.supportedApp = customApp;
        await core.settings.setKeyMap(customApp);
        return newName;
      }
    }
    return null;
  }

  String duplicateSync(String currentProfile, String newName) {
    if (core.actionHandler.supportedApp is CustomApp) {
      core.settings.duplicateCustomAppProfile(currentProfile, newName);
      final customApp = CustomApp(profileName: newName);
      final savedKeymap = core.settings.getCustomAppKeymap(newName);
      if (savedKeymap != null) {
        customApp.decodeKeymap(savedKeymap);
      }
      core.actionHandler.supportedApp = customApp;
      core.settings.setKeyMap(customApp);
      return newName;
    } else {
      final customApp = CustomApp(profileName: newName);

      final connectedDeviceButtons = IterableFlatMap(
        core.connection.controllerDevices,
      ).flatMap((e) => e.availableButtons).toSet();
      core.actionHandler.supportedApp!.keymap.keyPairs.forEachIndexed((pair, index) {
        pair.buttons.filter((button) => connectedDeviceButtons.contains(button) == true).forEachIndexed((
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
            modifiers: pair.modifiers,
          );
        });
      });

      core.actionHandler.supportedApp = customApp;
      core.settings.setKeyMap(customApp);
      return newName;
    }
  }
}
