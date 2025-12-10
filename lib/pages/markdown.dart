import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart' show BackButton;
import 'package:flutter/services.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/widgets/ui/colored_title.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MarkdownPage extends StatefulWidget {
  final String assetPath;
  const MarkdownPage({super.key, required this.assetPath});

  @override
  State<MarkdownPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<MarkdownPage> {
  Markdown? _markdown;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChangelog();
  }

  Future<void> _loadChangelog() async {
    try {
      final md = await rootBundle.loadString(widget.assetPath);
      setState(() {
        _markdown = Markdown.fromString(md);
      });

      // load latest version
      final response = await http.get(
        Uri.parse('https://raw.githubusercontent.com/jonasbark/swiftcontrol/refs/heads/main/${widget.assetPath}'),
      );
      if (response.statusCode == 200) {
        final latestMd = response.body;
        if (latestMd != md) {
          setState(() {
            _markdown = Markdown.fromString(md);
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load changelog: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          leading: [
            BackButton(),
          ],
          title: Text(widget.assetPath.replaceAll('.md', '').toLowerCase().capitalize()),
        ),
      ],
      child: _error != null
          ? Center(child: Text(_error!))
          : _markdown == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Accordion(
                items: _markdown!.blocks.fold(<Widget>[], (acc, block) {
                  if (block is MD$Heading) {
                    acc.add(
                      AccordionItem(
                        trigger: AccordionTrigger(child: ColoredTitle(text: block.text)),
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [],
                        ),
                      ),
                    );
                  } else {
                    ((acc.last as AccordionItem).content as Column).children.add(
                      switch (block.type) {
                        _ when block is MD$Paragraph => Text(block.text).small,
                        _ when block is MD$List => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var item in block.items) ...[
                              if (item.children.isEmpty)
                                fromString(item.text).li
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    fromString(item.text),
                                    for (var line in item.children) fromString(line.text).li,
                                  ],
                                ).li,
                            ],
                          ],
                        ),
                        _ when block is MD$Spacer => SizedBox(height: 16),
                        _ => SizedBox.shrink(),
                      },
                    );
                  }
                  return acc;
                }),
              ),
            ),
    );
  }

  MarkdownWidget fromString(String md) {
    final markdown = Markdown.fromString(md);
    return MarkdownWidget(
      markdown: markdown,
      theme: MarkdownThemeData(
        onLinkTap: (title, url) {
          launchUrlString(url);
        },
        textStyle: TextStyle(),
      ),
    );
  }
}
