import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HelpButton extends StatelessWidget {
  final bool isMobile;
  const HelpButton({super.key, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final border = isMobile
        ? BorderRadius.only(topRight: Radius.circular(8), topLeft: Radius.circular(8))
        : BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));
    return Container(
      decoration: BoxDecoration(
        borderRadius: border,
      ),
      child: Builder(
        builder: (context) {
          return Button(
            onPressed: () {
              showDropdown(
                context: context,
                builder: (c) => DropdownMenu(
                  children: [
                    MenuLabel(child: Text(context.i18n.instructions)),
                    MenuButton(
                      leading: Icon(Icons.ondemand_video),
                      child: const Text('Instruction Videos'),
                      onPressed: (c) {
                        openDrawer(
                          context: context,
                          position: OverlayPosition.bottom,
                          builder: (c) => const _InstructionVideosDrawer(),
                        );
                      },
                    ),
                    MenuButton(
                      leading: Icon(Icons.help_outline),
                      child: Text(AppLocalizations.of(context).troubleshootingPage),
                      onPressed: (c) {
                        openDrawer(
                          context: context,
                          position: OverlayPosition.bottom,
                          builder: (c) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md'),
                        );
                      },
                    ),
                    MenuDivider(),
                    MenuLabel(child: Text(context.i18n.getSupport)),
                    MenuButton(
                      leading: Icon(Icons.reddit_outlined),
                      onPressed: (c) {
                        launchUrlString('https://www.reddit.com/r/BikeControl/');
                      },
                      child: Text('Reddit'),
                    ),
                    MenuButton(
                      leading: Icon(Icons.facebook_outlined),
                      onPressed: (c) {
                        launchUrlString('https://www.facebook.com/groups/1892836898778912');
                      },
                      child: Text('Facebook'),
                    ),
                    MenuButton(
                      leading: Icon(RadixIcons.githubLogo),
                      onPressed: (c) {
                        launchUrlString('https://github.com/OpenBikeControl/bikecontrol/issues');
                      },
                      child: Text('GitHub'),
                    ),
                    MenuButton(
                      leading: Icon(LucideIcons.messageCircle),
                      child: Text(context.i18n.chatWithSupport),
                      onPressed: (c) async {
                        final captured = await debugText();
                        String? capturedFreetext = captured;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SupportChatPage(
                              diagnosticPreview: captured,
                              telemetryBuilder: () async {
                                if (capturedFreetext != null) {
                                  final snapshot = TelemetrySnapshot.general(
                                    freetext: capturedFreetext,
                                  );
                                  capturedFreetext = null;
                                  return snapshot;
                                }
                                return TelemetrySnapshot.general(
                                  freetext: await debugText(),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
            leading: Padding(
              padding: EdgeInsets.only(
                bottom: isMobile ? MediaQuery.viewPaddingOf(context).bottom : 0,
              ),
              child: Icon(LucideIcons.messageCircle),
            ),
            style: ButtonStyle.secondary().withBorderRadius(
              borderRadius: border,
              hoverBorderRadius: border,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isMobile ? MediaQuery.viewPaddingOf(context).bottom : 0,
              ),
              child: Text(context.i18n.troubleshootingGuide),
            ),
          );
        },
      ),
    );
  }
}

class _InstructionVideosDrawer extends StatefulWidget {
  const _InstructionVideosDrawer();

  @override
  State<_InstructionVideosDrawer> createState() => _InstructionVideosDrawerState();
}

class _InstructionVideosDrawerState extends State<_InstructionVideosDrawer> {
  static const _channelId = 'UCPuQFntEz__QxznGqNPmpsw';
  late Future<List<_InstructionVideo>> _videosFuture;

  @override
  void initState() {
    super.initState();
    _videosFuture = _fetchVideos();
  }

  void _retry() {
    setState(() {
      _videosFuture = _fetchVideos();
    });
  }

  Future<List<_InstructionVideo>> _fetchVideos() async {
    final uri = Uri.parse('https://www.youtube.com/feeds/videos.xml?channel_id=$_channelId');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load videos');
    }

    final entryRegex = RegExp(r'<entry>([\s\S]*?)</entry>');
    final videos = <_InstructionVideo>[];
    for (final match in entryRegex.allMatches(response.body)) {
      final entry = match.group(1) ?? '';
      final url = _extract(entry, RegExp(r'<link[^>]*rel="alternate"[^>]*href="([^"]+)"'));
      if (url == null || url.isEmpty) {
        continue;
      }

      final title = _normalizeTitle(
        _decodeXmlEntities(_extract(entry, RegExp(r'<title>([\s\S]*?)</title>')) ?? 'YouTube Video'),
      );
      final description = _decodeXmlEntities(
        _extract(entry, RegExp(r'<media:description>([\s\S]*?)</media:description>')) ?? '',
      ).trim();
      final videoId = _extract(entry, RegExp(r'<yt:videoId>([^<]+)</yt:videoId>'));
      final feedThumbnail = _extract(entry, RegExp(r'<media:thumbnail[^>]*url="([^"]+)"'));
      final thumbnailUrl =
          feedThumbnail ??
          (videoId == null || videoId.isEmpty
              ? 'https://img.youtube.com/vi/default/hqdefault.jpg'
              : 'https://img.youtube.com/vi/$videoId/hqdefault.jpg');

      final uri = Uri.tryParse(url);
      final isShort = uri?.pathSegments.contains('shorts') ?? url.contains('/shorts/');
      videos.add(
        _InstructionVideo(
          url: url,
          title: title,
          description: description,
          thumbnailUrl: thumbnailUrl,
          isShort: isShort,
        ),
      );
    }

    return videos;
  }

  String? _extract(String value, RegExp regex) {
    final match = regex.firstMatch(value);
    if (match == null) {
      return null;
    }
    return match.group(1)?.trim();
  }

  String _decodeXmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  String _normalizeTitle(String title) {
    const prefix = 'BikeControl - ';
    if (title.startsWith(prefix)) {
      return title.substring(prefix.length).trim();
    }
    return title.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        spacing: 8,
        children: [
          ColoredTitle(text: 'Instruction Videos'),
          Expanded(
            child: FutureBuilder<List<_InstructionVideo>>(
              future: _videosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _statusCard(text: 'Loading videos...');
                }

                if (snapshot.hasError) {
                  return _statusCard(
                    text: 'Could not load videos from YouTube.',
                    action: SecondaryButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  );
                }

                final videos = snapshot.data ?? <_InstructionVideo>[];
                if (videos.isEmpty) {
                  return _statusCard(
                    text: 'No videos found on the channel right now.',
                    action: SecondaryButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  );
                }

                final regularVideos = videos.where((video) => !video.isShort).toList();
                final shortVideos = videos.where((video) => video.isShort).toList();

                return SingleChildScrollView(
                  physics: ClampingScrollPhysics(),
                  child: Column(
                    spacing: 12,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final video in regularVideos)
                        SizedBox(
                          height: 280,
                          child: _buildVideoCard(video, fullWidth: true),
                        ),
                      if (shortVideos.isNotEmpty)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = (constraints.maxWidth / 280).floor().clamp(1, 4);
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.9,
                              ),
                              itemCount: shortVideos.length,
                              itemBuilder: (context, index) {
                                return _buildVideoCard(shortVideos[index], fullWidth: false);
                              },
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard({required String text, Widget? action}) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.gray.withAlpha(100)),
        ),
        child: Column(
          spacing: 12,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) action,
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(_InstructionVideo video, {required bool fullWidth}) {
    return GestureDetector(
      onTap: () => launchUrlString(video.url),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.gray.withAlpha(100)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(video.thumbnailUrl, fit: BoxFit.cover),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(166),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                spacing: 6,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: fullWidth ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (video.description.isNotEmpty)
                    Text(
                      video.description,
                      maxLines: fullWidth ? 4 : 2,
                      overflow: TextOverflow.ellipsis,
                    ).xSmall.muted,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionVideo {
  final String url;
  final String title;
  final String description;
  final String thumbnailUrl;
  final bool isShort;

  const _InstructionVideo({
    required this.url,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.isShort,
  });
}
