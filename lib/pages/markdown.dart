import 'package:bike_control/widgets/ui/gradient_text.dart';
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
  List<_Group>? _groups;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChangelog();
  }

  Future<void> _loadChangelog() async {
    try {
      final md = await rootBundle.loadString(widget.assetPath);
      _parseMarkdown(md);
    } catch (e) {
      setState(() {
        _error = 'Failed to load changelog: $e';
      });
    } finally {
      _loadOnlineVersion();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _error != null
        ? Center(child: Text(_error!))
        : _groups == null
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.all(16),
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

  Future<void> _loadOnlineVersion() async {
    // load latest version
    final response = await http.get(
      Uri.parse('https://raw.githubusercontent.com/OpenBikeControl/bikecontrol/refs/heads/main/${widget.assetPath}'),
    );
    if (response.statusCode == 200) {
      final latestMd = response.body;
      _parseMarkdown(latestMd);
    }
  }
}

class _Group {
  final String title;
  final Markdown markdown;

  _Group({required this.title, required this.markdown});
}
