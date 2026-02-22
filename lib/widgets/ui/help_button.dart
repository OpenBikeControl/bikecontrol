import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
                    if (!kIsWeb) ...[
                      MenuButton(
                        leading: Icon(Icons.email_outlined),
                        child: Text('Mail'),
                        onPressed: (c) {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Mail Support'),
                                content: Container(
                                  constraints: BoxConstraints(maxWidth: 400),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    spacing: 16,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context).mailSupportExplanation,
                                      ),
                                      ...[
                                        OutlineButton(
                                          leading: Icon(Icons.reddit_outlined),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            launchUrlString('https://www.reddit.com/r/BikeControl/');
                                          },
                                          child: const Text('Reddit'),
                                        ),
                                        OutlineButton(
                                          leading: Icon(Icons.facebook_outlined),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            launchUrlString('https://www.facebook.com/groups/1892836898778912');
                                          },
                                          child: const Text('Facebook'),
                                        ),
                                        OutlineButton(
                                          leading: Icon(RadixIcons.githubLogo),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            launchUrlString('https://github.com/OpenBikeControl/bikecontrol/issues');
                                          },
                                          child: const Text('GitHub'),
                                        ),
                                        SecondaryButton(
                                          leading: Icon(Icons.mail_outlined),
                                          onPressed: () async {
                                            Navigator.pop(context);

                                            final isFromStore = (Platform.isAndroid
                                                ? isFromPlayStore == true
                                                : Platform.isIOS);
                                            final suffix = isFromStore ? '' : '-sw';

                                            String email = Uri.encodeComponent('jonas$suffix@bikecontrol.app');
                                            String subject = Uri.encodeComponent(
                                              context.i18n.helpRequested(packageInfoValue?.version ?? ''),
                                            );
                                            final dbg = await debugText();
                                            String body = Uri.encodeComponent("""
                
        $dbg""");
                                            Uri mail = Uri.parse("mailto:$email?subject=$subject&body=$body");

                                            launchUrl(mail);
                                          },
                                          child: const Text('Mail'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                    MenuDivider(),
                    MenuLabel(child: Text(context.i18n.instructions)),
                    MenuButton(
                      leading: Icon(Icons.ondemand_video),
                      child: const Text('Instruction Videos'),
                      onPressed: (c) {
                        openDrawer(
                          context: context,
                          position: OverlayPosition.bottom,
                          builder: (c) => _InstructionVideosDrawer(videos: _instructionVideos(context)),
                        );
                      },
                    ),
                    MenuButton(
                      leading: Icon(Icons.help_outline),
                      child: Text(context.i18n.troubleshootingGuide),
                      onPressed: (c) {
                        openDrawer(
                          context: context,
                          position: OverlayPosition.bottom,
                          builder: (c) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md'),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
            leading: Icon(Icons.help_outline),
            style: ButtonVariance.primary.withBorderRadius(
              borderRadius: border,
              hoverBorderRadius: border,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: core.settings.getShowOnboarding() && (kIsWeb || Platform.isAndroid || Platform.isIOS) ? 14 : 0,
              ),
              child: Text(context.i18n.troubleshootingGuide),
            ),
          );
        },
      ),
    );
  }

  List<_InstructionVideo> _instructionVideos(BuildContext context) {
    return [
      _InstructionVideo(
        url: 'https://youtube.com/shorts/qalBSiAz7wg',
        title: AppLocalizations.of(context).bluetoothKeyboardExplanation,
      ),
      _InstructionVideo(
        url: 'https://youtube.com/shorts/SvLOQqu2Dqg?feature=share',
        title: context.i18n.simulateTouch,
      ),
      _InstructionVideo(
        url: 'https://youtube.com/shorts/ClY1eTnmAv0?feature=share',
        title: context.i18n.simulateMediaKey,
      ),
      _InstructionVideo(
        url: 'https://youtube.com/shorts/zqD5ARGIVmE?feature=share',
        title: context.i18n.enableSteeringWithPhone,
      ),
    ];
  }
}

class _InstructionVideosDrawer extends StatelessWidget {
  final List<_InstructionVideo> videos;
  const _InstructionVideosDrawer({required this.videos});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        spacing: 8,
        children: [
          ColoredTitle(text: 'Instruction Videos'),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = (constraints.maxWidth / 280).floor().clamp(1, 4);
              return GridView.builder(
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 16 / 12,
                ),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index];
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
                            child: Text(
                              video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InstructionVideo {
  final String url;
  final String title;

  const _InstructionVideo({required this.url, required this.title});

  String get _videoId {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return '';
    }
    if (uri.pathSegments.contains('shorts')) {
      final shortsIndex = uri.pathSegments.indexOf('shorts');
      if (shortsIndex >= 0 && uri.pathSegments.length > shortsIndex + 1) {
        return uri.pathSegments[shortsIndex + 1];
      }
    }
    final queryVideoId = uri.queryParameters['v'];
    if (queryVideoId != null && queryVideoId.isNotEmpty) {
      return queryVideoId;
    }
    return '';
  }

  String get thumbnailUrl {
    final id = _videoId;
    if (id.isEmpty) {
      return 'https://img.youtube.com/vi/default/hqdefault.jpg';
    }
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }
}
