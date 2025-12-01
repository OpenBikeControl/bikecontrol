import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/gen/app_localizations.dart';
import 'package:swift_control/pages/customize.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/pages/trainer.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/widgets/logviewer.dart';
import 'package:swift_control/widgets/menu.dart';
import 'package:swift_control/widgets/title.dart';
import 'package:swift_control/widgets/ui/colors.dart';

import '../widgets/changelog_dialog.dart';

enum BCPage {
  devices(Icons.gamepad),
  trainer(Icons.pedal_bike),
  customization(Icons.videogame_asset_outlined),
  logs(Icons.article);

  final IconData icon;

  const BCPage(this.icon);

  String getTitle(BuildContext context) {
    return switch (this) {
      BCPage.devices => context.i18n.controllers,
      BCPage.trainer => context.i18n.trainer,
      BCPage.customization => context.i18n.configuration,
      BCPage.logs => context.i18n.logs,
    };
  }
}

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  bool _isMobile = false;
  var _selectedPage = BCPage.devices;

  @override
  void initState() {
    super.initState();

    core.connection.initialize();
    core.logic.initialize();

    core.connection.actionStream.listen((_) {
      _updateTrainerConnectionStatus();
      setState(() {});
    });
    _updateTrainerConnectionStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(
        Theme.of(context).colorScheme.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      );
      _checkAndShowChangelog();
    });
  }

  void _updateTrainerConnectionStatus() async {
    final isConnected = await core.logic.isTrainerConnected();
    if (mounted) {
      setState(() {
        _isTrainerConnected = isConnected;
      });
    }
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
      final lastSeenVersion = core.settings.getLastSeenVersion();

      if (mounted) {
        await ChangelogDialog.showIfNeeded(context, currentVersion, lastSeenVersion);
      }

      // Update last seen version
      await core.settings.setLastSeenVersion(currentVersion);
    } catch (e) {
      print('Failed to check changelog: $e');
    }
  }

  final List<BCPage> _tabs = BCPage.values.whereNot((e) => e == BCPage.logs).toList();

  bool _isTrainerConnected = false;

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
                      setState(() {});
                    },
                    goToNextPage: () {
                      setState(() {
                        _selectedPage = BCPage.customization;
                      });
                    },
                  ),
                  BCPage.customization => CustomizePage(),
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
            children: _tabs.map((page) => _buildNavigationItem(page, true)).toList(),
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
              label: Text(BCPage.logs.getTitle(context)),
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
            child: RepeatedAnimationBuilder<double>(
              duration: Duration(seconds: 1),
              reverseDuration: Duration(seconds: 1),
              start: 10,
              end: 12,
              mode: RepeatMode.pingPong,
              builder: (context, value, child) {
                return Container(
                  width: value,
                  height: value,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNavigationBar() {
    return NavigationBar(
      backgroundColor: Theme.of(context).colorScheme.background,
      labelType: NavigationLabelType.all,
      onSelected: (int index) {
        setState(() {
          _selectedPage = _tabs[index];
        });
      },
      children: _tabs.map((page) {
        return _buildNavigationItem(page, false);
      }).toList(),
    );
  }

  bool _isPageEnabled(BCPage page) {
    return switch (page) {
      BCPage.customization => core.settings.getTrainerApp() != null,
      _ => true,
    };
  }

  bool _needsAttention(BCPage page) {
    return switch (page) {
      BCPage.devices => core.connection.controllerDevices.isEmpty,
      BCPage.customization => false,
      BCPage.trainer => core.settings.getTrainerApp() == null || !_isTrainerConnected,
      BCPage.logs => false,
    };
  }

  NavigationBarItem _buildNavigationItem(BCPage page, bool withPadding) {
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
        padding: withPadding
            ? (context, states, value) {
                return EdgeInsets.symmetric(horizontal: 12, vertical: 16);
              }
            : null,
      ),
      style: ButtonStyle.ghost(density: ButtonDensity.icon, size: ButtonSize(1.1)).copyWith(
        decoration: (context, states, value) {
          return BoxDecoration(
            color: states.contains(WidgetState.hovered) ? Theme.of(context).colorScheme.secondary : null,
            borderRadius: BorderRadius.circular(8),
          );
        },
        padding: withPadding
            ? (context, states, value) {
                return EdgeInsets.symmetric(horizontal: 12, vertical: 16);
              }
            : null,
      ),
      enabled: _isPageEnabled(page),
      label: Text(
        page == BCPage.trainer ? core.settings.getTrainerApp()?.name.split(' ').first ?? page.getTitle(context) : page.getTitle(context),
      ),
      child: _buildIcon(page),
    );
  }
}
