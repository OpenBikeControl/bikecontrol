import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/widgets/ui/gradient_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MarkdownPage extends StatefulWidget {
  final String assetPath;
  const MarkdownPage({super.key, required this.assetPath});

  @override
  State<MarkdownPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<MarkdownPage> {
  static const String _troubleshootingPath = 'TROUBLESHOOTING.md';
  static const String _myWhooshLinkPath = 'INSTRUCTIONS_MYWHOOSH_LINK.md';
  static const String _remoteControlPath = 'INSTRUCTIONS_REMOTE_CONTROL.md';
  static const String _localPath = 'INSTRUCTIONS_LOCAL.md';
  static const String _rouvyPath = 'INSTRUCTIONS_ROUVY.md';
  static const String _zwiftPath = 'INSTRUCTIONS_ZWIFT.md';

  List<_Group>? _groups;
  String? _error;
  late String _selectedAssetPath;
  late final List<_InstructionOption> _instructionOptions;

  bool get _showInstructionSwitcher => widget.assetPath == _troubleshootingPath;

  @override
  void initState() {
    super.initState();
    _selectedAssetPath = widget.assetPath;
    _instructionOptions = _buildInstructionOptions();
    _loadMarkdown(_selectedAssetPath);
  }

  @override
  void didUpdateWidget(covariant MarkdownPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _selectedAssetPath = widget.assetPath;
      _loadMarkdown(_selectedAssetPath);
    }
  }

  Future<void> _loadMarkdown(String assetPath) async {
    setState(() {
      _groups = null;
      _error = null;
    });

    try {
      final md = await rootBundle.loadString(assetPath);
      _parseMarkdown(md);
    } catch (e) {
      setState(() {
        _error = 'Failed to load markdown: $e';
      });
    } finally {
      _loadOnlineVersion(assetPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _error != null
        ? Center(child: Text(_error!))
        : _groups == null
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 500,
              child: Accordion(
                items: _groups!
                    .map(
                      (group) => AccordionItem(
                        trigger: AccordionTrigger(child: GradientText(group.title).bold),
                        content: MarkdownWidget(
                          markdown: group.markdown,
                          theme: MarkdownThemeData(
                            textStyle: TextStyle(
                              fontSize: 14.0,
                              color: Theme.of(context).colorScheme.brightness == Brightness.dark
                                  ? Colors.white.withAlpha(255 * 70)
                                  : Colors.black.withAlpha(87 * 255),
                            ),
                            onLinkTap: (title, url) {
                              launchUrlString(url);
                            },
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          );

    if (!_showInstructionSwitcher) {
      return content;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: ButtonGroup(
            children: _instructionOptions
                .map(
                  (option) => Button(
                    style: option.assetPath == _selectedAssetPath ? ButtonStyle.primary() : ButtonStyle.secondary(),
                    onPressed: () {
                      final newAssetPath = option.assetPath;
                      if (newAssetPath == _selectedAssetPath) {
                        return;
                      }
                      setState(() {
                        _selectedAssetPath = newAssetPath;
                      });
                      _loadMarkdown(newAssetPath);
                    },
                    child: Text(option.label),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  void _parseMarkdown(String md) {
    setState(() {
      _error = null;
      _groups = md
          .split('## ')
          .map((section) {
            final lines = section.split('\n');
            final title = lines.first.replaceFirst('# ', '').trim();
            final content = lines.skip(1).join('\n').trim();
            return _Group(
              title: title,
              markdown: Markdown.fromString('## $content'),
            );
          })
          .where((group) => group.title.isNotEmpty)
          .toList();
    });
  }

  Future<void> _loadOnlineVersion(String assetPath) async {
    // load latest version
    final response = await http.get(
      Uri.parse('https://raw.githubusercontent.com/OpenBikeControl/bikecontrol/refs/heads/main/$assetPath'),
    );
    if (response.statusCode == 200) {
      final latestMd = response.body;
      if (assetPath == _selectedAssetPath) {
        _parseMarkdown(latestMd);
      }
    }
  }

  List<_InstructionOption> _buildInstructionOptions() {
    final options = <_InstructionOption>[
      _InstructionOption(label: 'Q&A', assetPath: _troubleshootingPath),
      _InstructionOption(label: 'MyWhoosh Link', assetPath: _myWhooshLinkPath),
      _InstructionOption(label: 'Remote Control', assetPath: _remoteControlPath),
    ];

    final platformSupportsLocal =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);

    if (platformSupportsLocal) {
      options.add(_InstructionOption(label: 'Local', assetPath: _localPath));
    }

    final trainerApp = core.settings.getTrainerApp();
    if (trainerApp is Rouvy) {
      options.add(_InstructionOption(label: 'Rouvy', assetPath: _rouvyPath));
    } else if (trainerApp is Zwift) {
      options.add(_InstructionOption(label: 'Zwift', assetPath: _zwiftPath));
    }

    return options;
  }
}

class _Group {
  final String title;
  final Markdown markdown;

  _Group({required this.title, required this.markdown});
}

class _InstructionOption {
  final String label;
  final String assetPath;

  const _InstructionOption({required this.label, required this.assetPath});
}
