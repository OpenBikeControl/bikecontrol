import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
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
        if (core.settings.getTrainerApp() != null)
          FeatureWidget(
            icon: Icons.computer,
            iconColor: BKColor.main,
            bgColor: BKColor.main.withValues(alpha: 0.03),
            iconBgColor: BKColor.main.withValues(alpha: 0.08),
            title: AppLocalizations.of(
              context,
            ).manualyControllingButton(core.settings.getTrainerApp()?.name ?? 'your trainer'),
            description: context.i18n.noControllerUseCompanionMode,
            isNew: false,
            withCard: withCard,
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
          FeatureWidget(
            icon: Icons.radio,
            withCard: withCard,
            iconColor: BKColor.mainEnd,
            bgColor: BKColor.mainEnd.withValues(alpha: 0.03),
            iconBgColor: BKColor.mainEnd.withValues(alpha: 0.08),
            title: 'Device Mirroring',
            description: 'BLE-to-WiFi bridge for trainers & sensors',
            isNew: true,
          ),
          const Gap(8),
          FeatureWidget(
            icon: Icons.bolt,
            withCard: withCard,
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
}

class FeatureWidget extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? bgColor;
  final Color? iconBgColor;
  final String title;
  final String? description;
  final VoidCallback? onTap;
  final bool isNew;
  final bool withCard;

  const FeatureWidget({
    super.key,
    this.icon,
    this.iconColor,
    this.bgColor,
    this.iconBgColor,
    required this.title,
    this.description,
    this.onTap,
    this.isNew = false,
    this.withCard = true,
  });

  @override
  Widget build(BuildContext context) {
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
                      Flexible(child: Text(title).small.semiBold),
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
                  if (description != null) ...[
                    const Gap(2),
                    Text(description!).xSmall.muted,
                  ],
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
                subtitle: description != null ? Text(description!) : null,
                trailingAlignment: Alignment.centerRight,
                trailing: Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
              ),
            ),
          );
  }
}

class SwitchFeature extends StatelessWidget {
  final VoidCallback onPressed;
  final String title;
  final String? subtitle;
  final bool value;
  final bool isProOnly;
  final bool isMobile;

  const SwitchFeature({
    super.key,
    required this.onPressed,
    required this.title,
    required this.isMobile,
    this.subtitle,
    required this.value,
    this.isProOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Button.ghost(
            style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12)),
            onPressed: !isProOnly
                ? onPressed
                : () async {
                    if (await IAPManager.instance.ensureProForFeature(context)) {
                      onPressed();
                    }
                  },
            child: Basic(
              padding: EdgeInsets.only(right: isProOnly && !IAPManager.instance.isProEnabled ? 32 : 0),
              title: isMobile && false ? Text(title).xSmall.normal : Text(title),
              subtitle: subtitle != null ? Text(subtitle!).xSmall.normal.muted : null,
              trailing: Switch(
                value: value,
                onChanged: (val) {
                  onPressed();
                },
              ),
            ),
          ),
          if (isProOnly && !IAPManager.instance.isProEnabled)
            Positioned(
              top: 0,
              right: 0,
              child: IgnorePointer(
                child: ProBadge(
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
