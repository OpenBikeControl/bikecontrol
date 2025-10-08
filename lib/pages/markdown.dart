import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:http/http.dart' as http;
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
        Uri.parse('https://raw.githubusercontent.com/jonasbark/swiftcontrol/refs/heads/ios/${widget.assetPath}'),
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
      appBar: AppBar(
        title: Text(widget.assetPath.replaceAll('.md', '').toLowerCase().capitalize),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body:
          _error != null
              ? Center(child: Text(_error!))
              : _markdown == null
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: MarkdownWidget(
                        markdown: _markdown!,
                        theme: MarkdownThemeData(
                          textStyle: TextStyle(fontSize: 14.0, color: Colors.black87),
                          onLinkTap: (title, url) {
                            launchUrlString(url);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
