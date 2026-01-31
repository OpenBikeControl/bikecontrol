import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/title.dart';
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
}
