import 'package:dartx/dartx.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/configuration.dart';
import 'package:swift_control/pages/customize.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/pages/trainer.dart';
import 'package:swift_control/widgets/logviewer.dart';
import 'package:swift_control/widgets/menu.dart';
import 'package:swift_control/widgets/title.dart';
import 'package:swift_control/widgets/ui/colors.dart';

import '../widgets/changelog_dialog.dart';

enum BCPage {
  configuration('Configuration', Icons.settings),
  devices('Controllers', Icons.gamepad),
  trainer('Trainer', Icons.pedal_bike),
  customization('Adjust', Icons.color_lens),
  logs('Logs', Icons.article);

  final String title;
  final IconData icon;

  const BCPage(this.title, this.icon);
}

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  bool _isMobile = false;
  var _selectedPage = BCPage.configuration;

  @override
  void initState() {
    super.initState();
    connection.actionStream.listen((_) {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowChangelog();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _isMobile = MediaQuery.sizeOf(context).width < 600;
  }

  Future<void> _checkAndShowChangelog() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final lastSeenVersion = settings.getLastSeenVersion();

      if (mounted) {
        await ChangelogDialog.showIfNeeded(context, currentVersion, lastSeenVersion);
      }

      // Update last seen version
      await settings.setLastSeenVersion(currentVersion);
    } catch (e) {
      print('Failed to check changelog: $e');
    }
  }

  final List<BCPage> _tabs = BCPage.values.whereNot((e) => e == BCPage.logs).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          backgroundColor: Theme.of(context).colorScheme.background,
          title: AppTitle(),
          trailing: buildMenuButtons(
            context,
            _isMobile
                ? () {
                    setState(() {
                      _selectedPage = BCPage.logs;
                    });
                  }
                : null,
          ),
        ),
        Divider(),
      ],
      footers: _isMobile
          ? [
              Divider(),
              _buildNavigationBar(),
            ]
          : [],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isMobile) ...[
            _buildNavigationMenu(),
            VerticalDivider(),
          ],
          Expanded(
            child: Container(
              alignment: Alignment.topLeft,
              padding: EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 200),
                child: switch (_selectedPage) {
                  BCPage.devices => DevicePage(
                    onUpdate: () {
                      setState(() {
                        _selectedPage = BCPage.trainer;
                      });
                    },
                  ),
                  BCPage.trainer => TrainerPage(
                    onUpdate: () {
                      setState(() {
                        _selectedPage = BCPage.customization;
                      });
                    },
                  ),
                  BCPage.customization => CustomizePage(),
                  BCPage.configuration => ConfigurationPage(
                    onUpdate: () {
                      setState(() {
                        _selectedPage = BCPage.devices;
                      });
                    },
                  ),
                  BCPage.logs => LogViewer(),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationMenu() {
    return Column(
      children: [
        Expanded(
          child: NavigationSidebar(
            onSelected: (int index) {
              setState(() {
                _selectedPage = BCPage.values[index];
              });
            },
            children: [
              ..._tabs.map((page) {
                return NavigationItem(
                  selected: _selectedPage == page,
                  selectedStyle: ButtonStyle.primary(size: ButtonSize(1.1)).copyWith(
                    decoration: (context, states, value) {
                      return BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [BKColor.main, BKColor.mainEnd],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      );
                    },
                    padding: (context, states, value) {
                      return EdgeInsets.symmetric(horizontal: 12, vertical: 16);
                    },
                  ),
                  style: ButtonStyle.ghost(density: ButtonDensity.icon, size: ButtonSize(1.1)).copyWith(
                    decoration: (context, states, value) {
                      return BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      );
                    },
                    padding: (context, states, value) {
                      return EdgeInsets.symmetric(horizontal: 12, vertical: 16);
                    },
                  ),
                  enabled: _isPageEnabled(page),
                  label: Text(page == BCPage.trainer ? settings.getTrainerApp()?.name ?? page.title : page.title),
                  child: _buildIcon(page),
                );
              }),
            ],
          ),
        ),

        NavigationSidebar(
          onSelected: (int index) {
            setState(() {
              _selectedPage = BCPage.logs;
            });
          },
          children: [
            NavigationDivider(),
            NavigationItem(
              label: Text(BCPage.logs.title),
              selected: _selectedPage == BCPage.logs,
              child: _buildIcon(BCPage.logs),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIcon(BCPage page) {
    final needsAttention = _needsAttention(page);
    return Stack(
      children: [
        Icon(page.icon),
        if (needsAttention) ...[
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNavigationBar() {
    return NavigationBar(
      backgroundColor: Theme.of(context).colorScheme.background,
      labelType: NavigationLabelType.tooltip,
      onSelected: (int index) {
        setState(() {
          _selectedPage = _tabs[index];
        });
      },
      children: _tabs.map((page) {
        return NavigationItem(
          selected: _selectedPage == page,
          enabled: _isPageEnabled(page),
          label: Text(page == BCPage.trainer ? settings.getTrainerApp()?.name ?? page.title : page.title),
          child: _buildIcon(page),
        );
      }).toList(),
    );
  }

  bool _isPageEnabled(BCPage page) {
    return switch (page) {
      BCPage.configuration => true,
      _ => settings.getTrainerApp() != null,
    };
  }

  bool _needsAttention(BCPage page) {
    return switch (page) {
      BCPage.configuration => settings.getTrainerApp() == null,
      BCPage.devices => connection.controllerDevices.isEmpty,
      BCPage.customization => false,
      BCPage.trainer => false,
      BCPage.logs => false,
    };
  }
}
