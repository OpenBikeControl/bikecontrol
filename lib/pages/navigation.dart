import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/configuration.dart';
import 'package:swift_control/pages/customize.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/pages/requirements.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/menu.dart';
import 'package:swift_control/widgets/title.dart';

enum BCPage {
  configuration('Configuration', Icons.settings),
  permissions('Permissions', Icons.security),
  devices('Devices', Icons.devices),
  customization('Customization', Icons.color_lens);

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
  bool? _needsPermissions;
  var _selectedPage = BCPage.configuration;

  @override
  void initState() {
    super.initState();
    _reloadRequirements();
    connection.actionStream.listen((_) {
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _isMobile = MediaQuery.sizeOf(context).width < 600;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: AppTitle(),
          trailing: buildMenuButtons(context),
        ),
        Divider(),
      ],
      loadingProgressIndeterminate: _needsPermissions == null,
      footers: _isMobile ? [_buildNavigationBar()] : [],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isMobile) ...[
            _buildNavigationMenu(),
            VerticalDivider(),
          ],
          if (_needsPermissions != null)
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 200),
                child: Container(
                  alignment: Alignment.topLeft,
                  padding: EdgeInsets.all(16),
                  child: switch (_selectedPage) {
                    BCPage.permissions => RequirementsPage(
                      onUpdate: () {
                        _reloadRequirements();
                      },
                    ),
                    BCPage.devices => DevicePage(),
                    BCPage.customization => CustomizePage(),
                    BCPage.configuration => ConfigurationPage(
                      onUpdate: () {
                        _reloadRequirements();
                      },
                    ),
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<BCPage> get _tabPages =>
      _needsPermissions == true ? BCPage.values : BCPage.values.where((page) => page != BCPage.permissions).toList();

  Widget _buildNavigationMenu() {
    return NavigationSidebar(
      onSelected: (int index) {
        setState(() {
          _selectedPage = _tabPages[index];
        });
      },
      children: _tabPages.map((page) {
        return NavigationItem(
          selected: _selectedPage == page,
          selectedStyle: ButtonStyle.primary(size: ButtonSize(1.1)).copyWith(
            decoration: (context, states, value) {
              return BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E74B7), Color(0xFF0E9297)],
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
          label: Text(page.title),
          child: _buildIcon(page),
        );
      }).toList(),
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
      labelType: NavigationLabelType.all,
      onSelected: (int index) {
        setState(() {
          _selectedPage = _tabPages[index];
        });
      },
      children: _tabPages.map((page) {
        return NavigationItem(
          selected: _selectedPage == page,
          enabled: _isPageEnabled(page),
          label: Text(page.title),
          child: _buildIcon(page),
        );
      }).toList(),
    );
  }

  bool _isPageEnabled(BCPage page) {
    return switch (page) {
      BCPage.configuration => true,
      BCPage.permissions => settings.getTrainerApp() != null,
      _ => settings.getTrainerApp() != null && _needsPermissions == false,
    };
  }

  bool _needsAttention(BCPage page) {
    return switch (page) {
      BCPage.configuration => settings.getTrainerApp() == null,
      BCPage.permissions => true,
      BCPage.devices => connection.controllerDevices.isEmpty,
      BCPage.customization => false,
    };
  }

  void _reloadRequirements() {
    getRequirements(
      settings.getLastTarget()?.connectionType ?? ConnectionType.unknown,
    ).then((reqs) => reqs.any((req) => !req.status)).then((needsPermissions) {
      setState(() {
        if (_needsPermissions == true && needsPermissions == false) {
          if (_selectedPage == BCPage.permissions) {
            _selectedPage = BCPage.devices;
          } else if (_selectedPage == BCPage.configuration) {
            _selectedPage = BCPage.devices;
          }
        } else if (needsPermissions == true && settings.getTrainerApp() != null) {
          _selectedPage = BCPage.permissions;
        } else if (settings.getTrainerApp() != null) {
          _selectedPage = BCPage.devices;
        }
        _needsPermissions = needsPermissions;
      });
    });
  }
}
