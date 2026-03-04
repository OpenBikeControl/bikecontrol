import 'package:bike_control/utils/interpreter.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class DeviceScriptDrawer extends StatefulWidget {
  final String deviceType;

  const DeviceScriptDrawer({super.key, required this.deviceType});

  @override
  State<DeviceScriptDrawer> createState() => _DeviceScriptDrawerState();
}

class _DeviceScriptDrawerState extends State<DeviceScriptDrawer> {
  final TextEditingController _controller = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _hasSavedScript = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _loadScript();
  }

  @override
  void dispose() {
    _controller.dispose();
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
                        onPressed: (_isLoading || _isSaving) ? null : tap,
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
                    onPressed: (_isSaving || _isDeleting) ? null : () => closeDrawer(context),
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
                      onPressed: (_isLoading || _isDeleting) ? null : tap,
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
