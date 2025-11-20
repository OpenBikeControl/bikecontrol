import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/keymap/keymap.dart';

/// Dialog for selecting a predefined action from existing trainer app keymaps
class PredefinedActionSelectorDialog extends StatefulWidget {
  const PredefinedActionSelectorDialog({super.key});

  @override
  State<PredefinedActionSelectorDialog> createState() => _PredefinedActionSelectorDialogState();
}

class _PredefinedActionSelectorDialogState extends State<PredefinedActionSelectorDialog> {
  SupportedApp? _selectedApp;
  KeyPair? _selectedKeyPair;

  @override
  Widget build(BuildContext context) {
    // Get all supported apps except CustomApp
    final availableApps = SupportedApp.supportedApps
        .where((app) => app.runtimeType.toString() != 'CustomApp')
        .toList();

    return AlertDialog(
      title: Text('Select Predefined Action'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a trainer app and then select an action to copy its configuration:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 16),
            // App selector dropdown
            DropdownButtonFormField<SupportedApp>(
              decoration: InputDecoration(
                labelText: 'Trainer App',
                border: OutlineInputBorder(),
              ),
              value: _selectedApp,
              items: availableApps.map((app) {
                return DropdownMenuItem(
                  value: app,
                  child: Text(app.name),
                );
              }).toList(),
              onChanged: (app) {
                setState(() {
                  _selectedApp = app;
                  _selectedKeyPair = null; // Reset selected action when app changes
                });
              },
            ),
            if (_selectedApp != null) ...[
              SizedBox(height: 16),
              Text(
                'Select an action:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: 8),
              // Action list
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _selectedApp!.keymap.keyPairs.length,
                    itemBuilder: (context, index) {
                      final keyPair = _selectedApp!.keymap.keyPairs[index];
                      // Only show keypairs that have some action configured
                      if (keyPair.physicalKey == null &&
                          keyPair.logicalKey == null &&
                          keyPair.touchPosition == Offset.zero &&
                          keyPair.inGameAction == null) {
                        return SizedBox.shrink();
                      }

                      final actionDescription = _getActionDescription(keyPair);
                      
                      return RadioListTile<KeyPair>(
                        value: keyPair,
                        groupValue: _selectedKeyPair,
                        onChanged: (value) {
                          setState(() {
                            _selectedKeyPair = value;
                          });
                        },
                        title: Text(actionDescription),
                        subtitle: keyPair.buttons.isNotEmpty
                            ? Text(
                                'Buttons: ${keyPair.buttons.map((b) => b.name).join(', ')}',
                                style: TextStyle(fontSize: 12),
                              )
                            : null,
                        dense: true,
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: _selectedKeyPair != null
              ? () => Navigator.pop(context, _selectedKeyPair)
              : null,
          child: Text('Select'),
        ),
      ],
    );
  }

  String _getActionDescription(KeyPair keyPair) {
    final parts = <String>[];
    
    if (keyPair.inGameAction != null) {
      parts.add(keyPair.inGameAction!.toString());
      if (keyPair.inGameActionValue != null) {
        parts.add('(${keyPair.inGameActionValue})');
      }
    }
    
    if (keyPair.physicalKey != null || keyPair.logicalKey != null) {
      parts.add('Key: ${keyPair.toString()}');
    }
    
    if (keyPair.touchPosition != Offset.zero) {
      parts.add('Touch: (${keyPair.touchPosition.dx.toStringAsFixed(1)}, ${keyPair.touchPosition.dy.toStringAsFixed(1)})');
    }
    
    if (keyPair.isLongPress) {
      parts.add('[Long Press]');
    }
    
    return parts.isNotEmpty ? parts.join(' • ') : 'Action';
  }
}
