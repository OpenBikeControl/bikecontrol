import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/customize.dart';
import 'package:bike_control/pages/device.dart';
import 'package:bike_control/pages/trainer.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/iap_status_widget.dart';
import 'package:bike_control/widgets/logviewer.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
  final BCPage page;
  const Navigation({super.key, this.page = BCPage.devices});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  bool _isMobile = false;
  late BCPage _selectedPage;

  @override
  void initState() {
    super.initState();

    _selectedPage = widget.page;

    core.connection.initialize();
    core.logic.startEnabledConnectionMethod();

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

  @override
  void didUpdateWidget(covariant Navigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.page != oldWidget.page) {
      setState(() {
        _selectedPage = widget.page;
      });
    }
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
          padding:
              const EdgeInsets.only(top: 12, bottom: 8, left: 12, right: 12) *
              (screenshotMode ? 2 : Theme.of(context).scaling),
          title: AppTitle(),
          backgroundColor: Theme.of(context).colorScheme.background,
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
      footers: _isMobile ? [Divider(), _buildNavigationBar()] : [],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isMobile) ...[
            _buildNavigationMenu(),
            VerticalDivider(),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IAPStatusWidget(),
                ),
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
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? BKColor.backgroundLight
                : Theme.of(context).colorScheme.card,
            onSelected: (int index) {
              setState(() {
                _selectedPage = BCPage.values[index];
              });
            },
            spacing: 4,
            children: _tabs.map((page) => _buildNavigationItemDesktop(page)).toList(),
          ),
        ),

        NavigationSidebar(
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? BKColor.backgroundLight
              : Theme.of(context).colorScheme.card,
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
        Icon(
          page.icon,
          color: !_isPageEnabled(page)
              ? null
              : Theme.of(context).colorScheme.brightness == Brightness.dark
              ? Colors.white
              : null,
        ),
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
      padding:
          EdgeInsets.only(top: 6, left: 12, right: 12, bottom: !kIsWeb && Platform.isMacOS ? 8 : 0) *
          Theme.of(context).scaling,
      labelType: NavigationLabelType.all,
      onSelected: (int index) {
        setState(() {
          _selectedPage = _tabs[index];
        });
      },
      children: _tabs.map((page) {
        return NavigationItem(
          selected: _selectedPage == page,
          selectedStyle: ButtonStyle.primary(density: ButtonDensity.dense).copyWith(
            decoration: (context, states, value) {
              return BoxDecoration(
                gradient: const LinearGradient(
                  colors: [BKColor.main, BKColor.mainEnd],
                ),
                borderRadius: BorderRadius.circular(8),
              );
            },
          ),
          style: ButtonStyle.ghost(density: ButtonDensity.dense).copyWith(
            decoration: (context, states, value) {
              return BoxDecoration(
                gradient: states.contains(WidgetState.hovered)
                    ? const LinearGradient(
                        colors: [BKColor.main, BKColor.mainEnd],
                      )
                    : null,
                borderRadius: BorderRadius.circular(8),
              );
            },
          ),
          enabled: _isPageEnabled(page),
          label: Text(
            page == BCPage.trainer && !screenshotMode
                ? core.settings.getTrainerApp()?.name.split(' ').first ?? page.getTitle(context)
                : page.getTitle(context),
            style: TextStyle(
              color: !_isPageEnabled(page)
                  ? null
                  : Theme.of(context).colorScheme.brightness == Brightness.dark
                  ? Colors.white
                  : null,
            ),
          ),
          child: _buildIcon(page),
        );
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

  NavigationBarItem _buildNavigationItemDesktop(BCPage page) {
    return NavigationItem(
      selected: _selectedPage == page,
      selectedStyle: ButtonStyle.primary(density: ButtonDensity.dense).copyWith(
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
      style: ButtonStyle.ghost(density: ButtonDensity.dense).copyWith(
        decoration: (context, states, value) {
          return BoxDecoration(
            gradient: states.contains(WidgetState.hovered)
                ? const LinearGradient(
                    colors: [BKColor.main, BKColor.mainEnd],
                  )
                : null,
            borderRadius: BorderRadius.circular(8),
          );
        },
        padding: (context, states, value) {
          return EdgeInsets.symmetric(horizontal: 12, vertical: 16);
        },
      ),
      enabled: _isPageEnabled(page),
      child: SizedBox(
        width: screenshotMode ? 180 : 152,
        child: Basic(
          padding: screenshotMode ? EdgeInsets.all(0) : null,
          leading: _buildIcon(page),
          leadingAlignment: Alignment.centerLeft,
          title: Text(
            page == BCPage.trainer && !screenshotMode
                ? core.settings.getTrainerApp()?.name.split(' ').first ?? page.getTitle(context)
                : page.getTitle(context),
            style: TextStyle(
              color: !_isPageEnabled(page)
                  ? null
                  : Theme.of(context).colorScheme.brightness == Brightness.dark
                  ? Colors.white
                  : null,
            ),
          ),
          subtitle: _needsAttention(page)
              ? Text(
                  switch (page) {
                    BCPage.devices => AppLocalizations.of(context).noControllerConnected,
                    BCPage.trainer when !_isTrainerConnected => AppLocalizations.of(context).notConnected,
                    BCPage.trainer when core.settings.getTrainerApp() == null => AppLocalizations.of(
                      context,
                    ).noTrainerSelected,
                    _ => '',
                  },
                  style: _selectedPage == page ? TextStyle(color: Colors.gray.shade300) : null,
                )
              : null,
        ),
      ),
    );
  }
}
