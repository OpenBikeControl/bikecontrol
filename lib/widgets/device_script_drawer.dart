import 'package:bike_control/utils/interpreter.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class DeviceScriptDrawer extends StatefulWidget {
  final String deviceType;

  const DeviceScriptDrawer({super.key, required this.deviceType});

  @override
  State<DeviceScriptDrawer> createState() => _DeviceScriptDrawerState();
}

class _DeviceScriptDrawerState extends State<DeviceScriptDrawer> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _tryCharacteristicController = TextEditingController();
  final TextEditingController _tryHexController = TextEditingController(text: '01 02 03');

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isTrying = false;
  bool _hasSavedScript = false;
  String? _validationError;
  String? _tryOutputCharacteristic;
  String? _tryOutputHex;
  String? _tryError;

  @override
  void initState() {
    super.initState();
    _tryCharacteristicController.text = '00000000-0000-0000-0000-000000000000';
    _loadScript();
  }

  @override
  void dispose() {
    _controller.dispose();
    _tryCharacteristicController.dispose();
    _tryHexController.dispose();
    super.dispose();
  }

  Future<void> _loadScript() async {
    final hasSavedScript = await DeviceScriptService.instance.hasCustomScript(widget.deviceType);
    final source = await DeviceScriptService.instance.loadScriptForEditing(widget.deviceType);
    if (!mounted) {
      return;
    }

    _controller.text = source;
    setState(() {
      _isLoading = false;
      _hasSavedScript = hasSavedScript;
    });
  }

  Future<void> _saveScript() async {
    setState(() {
      _validationError = null;
    });

    final result = await DeviceScriptService.instance.saveScript(
      deviceType: widget.deviceType,
      source: _controller.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _validationError = result.errorMessage;
    });

    if (!result.isValid) {
      return;
    }

    buildToast(title: 'Script saved for ${widget.deviceType}.');
    closeDrawer(context);
  }

  Future<void> _deleteScript() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete script?'),
        content: Text('This will remove the saved script for ${widget.deviceType}.'),
        actions: [
          OutlineButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          DestructiveButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _validationError = null;
    });

    await DeviceScriptService.instance.deleteScript(widget.deviceType);

    if (!mounted) {
      return;
    }

    _controller.text = kDefaultDeviceScript;
    setState(() {
      _hasSavedScript = false;
    });

    buildToast(title: 'Script deleted for ${widget.deviceType}.');
  }

  Future<void> _tryScript() async {
    final characteristicUuid = _tryCharacteristicController.text.trim().toLowerCase();
    final hexInput = _tryHexController.text.trim();

    setState(() {
      _tryError = null;
      _tryOutputCharacteristic = null;
      _tryOutputHex = null;
    });

    if (characteristicUuid.isEmpty) {
      setState(() {
        _tryError = 'Characteristic UUID is required.';
      });
      return;
    }

    try {
      final data = _parseHexInput(hexInput);
      final result = await DeviceScriptService.instance.runScriptSource(
        source: _controller.text,
        characteristicUuid: characteristicUuid,
        data: data,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _tryOutputCharacteristic = result.characteristicUuid;
        _tryOutputHex = _toHex(result.data);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _tryError = e.toString();
      });
    }
  }

  Uint8List _parseHexInput(String input) {
    final normalized = input
        .replaceAll(RegExp(r'0x', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9a-fA-F]'), '');

    if (normalized.isEmpty) {
      return Uint8List(0);
    }

    if (normalized.length.isOdd) {
      throw const FormatException('Hex input must have an even number of characters.');
    }

    final bytes = <int>[];
    for (var i = 0; i < normalized.length; i += 2) {
      bytes.add(int.parse(normalized.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  String _toHex(Uint8List bytes) {
    if (bytes.isEmpty) {
      return '(empty)';
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 780,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text('Run Script', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text(
                'Device type: ${widget.deviceType}',
                style: TextStyle(color: Theme.of(context).colorScheme.mutedForeground, fontSize: 12),
              ),
              Text(
                'This script will run whenever a value is received via bluetooth.\nRequired signature: Future<List<dynamic>> main(String characteristicUuid, List<int> data)',
                style: TextStyle(color: Theme.of(context).colorScheme.mutedForeground, fontSize: 12),
              ),
              Expanded(
                child: _isLoading
                    ? Center(child: SmallProgressIndicator())
                    : TextArea(
                        controller: _controller,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        placeholder: Text('Write your script here...'),
                      ).inlineCode,
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.card.withAlpha(180),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text('Try Script', style: TextStyle(fontWeight: FontWeight.w600)),
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              TextField(
                                controller: _tryCharacteristicController,
                                placeholder: const Text('Characteristic UUID'),
                                hintText: 'Characteristic UUID',
                              ),
                              TextField(
                                controller: _tryHexController,
                                placeholder: const Text('Hex input (e.g. 01 FF 2A)'),
                                hintText: 'Hex input (e.g. 01 FF 2A)',
                              ),
                            ],
                          ),
                        ),
                        LoadingWidget(
                          onLoadCallback: (isLoading) {
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _isTrying = isLoading;
                            });
                          },
                          futureCallback: _tryScript,
                          renderChild: (isLoading, tap) => OutlineButton(
                            onPressed: (_isLoading || _isSaving || _isDeleting) ? null : tap,
                            child: isLoading
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: 8,
                                    children: [
                                      SmallProgressIndicator(),
                                      Text('Trying...'),
                                    ],
                                  )
                                : const Text('Try'),
                          ),
                        ),
                      ],
                    ),
                    if (_tryError != null)
                      Text(
                        _tryError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.destructive, fontSize: 12),
                      ),
                    if (_tryOutputCharacteristic != null && _tryOutputHex != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          Text(
                            'Output characteristic: $_tryOutputCharacteristic',
                          ).inlineCode,
                          Text(
                            'Output data (hex): $_tryOutputHex',
                          ).inlineCode,
                        ],
                      ),
                  ],
                ),
              ),
              if (_validationError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.destructive.withAlpha(24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _validationError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.destructive, fontSize: 12),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                spacing: 8,
                children: [
                  if (_hasSavedScript)
                    LoadingWidget(
                      onLoadCallback: (isLoading) {
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _isDeleting = isLoading;
                        });
                      },
                      futureCallback: _deleteScript,
                      renderChild: (isLoading, tap) => DestructiveButton(
                        onPressed: (_isLoading || _isSaving || _isTrying) ? null : tap,
                        child: isLoading
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 8,
                                children: [
                                  SmallProgressIndicator(),
                                  Text('Deleting...'),
                                ],
                              )
                            : const Text('Delete'),
                      ),
                    ),
                  if (!_hasSavedScript) const SizedBox.shrink(),
                  const Spacer(),
                  OutlineButton(
                    onPressed: (_isSaving || _isDeleting || _isTrying) ? null : () => closeDrawer(context),
                    child: const Text('Cancel'),
                  ),
                  LoadingWidget(
                    onLoadCallback: (isLoading) {
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _isSaving = isLoading;
                      });
                    },
                    futureCallback: _saveScript,
                    renderChild: (isLoading, tap) => PrimaryButton(
                      onPressed: (_isLoading || _isDeleting || _isTrying) ? null : tap,
                      child: isLoading
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 8,
                              children: [
                                SmallProgressIndicator(color: Colors.black),
                                Text('Saving...'),
                              ],
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
