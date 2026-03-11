import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/protocol/zp.pbenum.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../utils/core.dart';
import 'card_button.dart';

class TrainerFeatures extends StatelessWidget {
  final bool withCard;
  const TrainerFeatures({super.key, this.withCard = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFeatureBanner(
          context: context,
          icon: Icons.computer,
          iconColor: BKColor.main,
          bgColor: BKColor.main.withValues(alpha: 0.03),
          iconBgColor: BKColor.main.withValues(alpha: 0.08),
          title: AppLocalizations.of(
            context,
          ).manualyControllingButton(core.settings.getTrainerApp()?.name ?? 'your trainer'),
          description: context.i18n.noControllerUseCompanionMode,
          isNew: false,
          onTap: () {
            if (core.settings.getTrainerApp() == null) {
              buildToast(
                level: LogLevel.LOGLEVEL_WARNING,
                title: context.i18n.selectTrainerApp,
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => ButtonSimulator(),
                ),
              );
            }
          },
        ),
        if (kDebugMode && false) ...[
          const Gap(12),
          _buildFeatureBanner(
            context: context,
            icon: Icons.radio,
            iconColor: BKColor.mainEnd,
            bgColor: BKColor.mainEnd.withValues(alpha: 0.03),
            iconBgColor: BKColor.mainEnd.withValues(alpha: 0.08),
            title: 'Device Mirroring',
            description: 'BLE-to-WiFi bridge for trainers & sensors',
            isNew: true,
          ),
          const Gap(8),
          _buildFeatureBanner(
            context: context,
            icon: Icons.bolt,
            iconColor: BKColor.main,
            bgColor: BKColor.main.withValues(alpha: 0.03),
            iconBgColor: BKColor.main.withValues(alpha: 0.08),
            title: 'Legacy Trainer Support',
            description: 'Virtual shifting for older smart trainers',
            isNew: true,
          ),
        ],
      ],
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────

  Widget _buildFeatureBanner({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color iconBgColor,
    required String title,
    required String description,
    VoidCallback? onTap,
    bool isNew = false,
  }) {
    return withCard
        ? SizedBox(
            width: double.infinity,
            child: HoverCardButton(
              onPressed: onTap,
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              trailing: Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title).small.semiBold,
                      if (isNew) ...[
                        const Gap(6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Gap(2),
                  Text(description).xSmall.muted,
                ],
              ),
            ),
          )
        : SizedBox(
            width: double.infinity,
            child: Button.ghost(
              style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12)),
              onPressed: onTap,
              child: Basic(
                title: Text(title),
                subtitle: Text(description),
                trailingAlignment: Alignment.centerRight,
                trailing: Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
              ),
            ),
          );
  }
}
