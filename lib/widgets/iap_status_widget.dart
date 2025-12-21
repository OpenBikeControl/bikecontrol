import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget to display IAP status and allow purchases
class IAPStatusWidget extends StatefulWidget {
  final bool small;
  const IAPStatusWidget({super.key, required this.small});

  @override
  State<IAPStatusWidget> createState() => _IAPStatusWidgetState();
}

class _IAPStatusWidgetState extends State<IAPStatusWidget> {
  bool _isPurchasing = false;
  bool _isSmall = false;

  @override
  void initState() {
    super.initState();
    _isSmall = widget.small;
  }

  @override
  void didUpdateWidget(covariant IAPStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.small != widget.small) {
      setState(() {
        _isSmall = widget.small;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final iapManager = IAPManager.instance;
    final isTrialExpired = iapManager.isTrialExpired;
    if (isTrialExpired) {
      _isSmall = false;
    }
    final trialDaysRemaining = iapManager.trialDaysRemaining;
    final commandsRemaining = iapManager.commandsRemainingToday;
    final dailyCommandCount = iapManager.dailyCommandCount;

    return Button(
      onPressed: _isSmall
          ? () {
              setState(() {
                _isSmall = false;
              });
            }
          : _handlePurchase,
      style: ButtonStyle.card().withBackgroundColor(
        color: Theme.of(context).colorScheme.muted,
        hoverColor: Theme.of(context).colorScheme.primaryForeground,
      ),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 700),
        width: double.infinity,
        child: ValueListenableBuilder(
          valueListenable: IAPManager.instance.isPurchased,
          builder: (context, isPurchased, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPurchased) ...[
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).fullVersion,
                        style: TextStyle(
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ] else if (!isTrialExpired) ...[
                  if (!Platform.isAndroid)
                    Basic(
                      leadingAlignment: Alignment.centerLeft,
                      leading: Icon(Icons.access_time, color: Colors.blue),
                      title: Text(AppLocalizations.of(context).trialPeriodActive(trialDaysRemaining)),
                      subtitle: _isSmall
                          ? null
                          : Text(AppLocalizations.of(context).trialPeriodDescription(IAPManager.dailyCommandLimit)),
                      trailing: _isSmall ? Icon(Icons.expand_more) : null,
                    )
                  else
                    Basic(
                      leadingAlignment: Alignment.centerLeft,
                      leading: Icon(Icons.lock),
                      title: Text(AppLocalizations.of(context).trialPeriodActive(trialDaysRemaining)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          SizedBox(),
                          Text(
                            commandsRemaining >= 0
                                ? context.i18n
                                      .commandsRemainingToday(commandsRemaining, IAPManager.dailyCommandLimit)
                                      .replaceAll(
                                        '${IAPManager.dailyCommandLimit}/${IAPManager.dailyCommandLimit}',
                                        IAPManager.dailyCommandLimit.toString(),
                                      )
                                : AppLocalizations.of(
                                    context,
                                  ).dailyLimitReached(dailyCommandCount, IAPManager.dailyCommandLimit),
                          ).small,
                          if (commandsRemaining >= 0)
                            SizedBox(
                              width: 300,
                              child: LinearProgressIndicator(
                                value: dailyCommandCount.toDouble() / IAPManager.dailyCommandLimit.toDouble(),
                                backgroundColor: Colors.gray[300],
                                color: commandsRemaining > 0 ? Colors.orange : Colors.red,
                              ),
                            ),
                        ],
                      ),
                      trailing: _isSmall ? Icon(Icons.expand_more) : null,
                      trailingAlignment: Alignment.centerRight,
                    ),
                ] else ...[
                  Basic(
                    leadingAlignment: Alignment.centerLeft,
                    leading: Icon(Icons.lock),
                    title: Text(AppLocalizations.of(context).trialExpired(IAPManager.dailyCommandLimit)),
                    trailing: _isSmall ? Icon(Icons.expand_more) : null,
                    trailingAlignment: Alignment.centerRight,
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        SizedBox(),
                        Text(
                          commandsRemaining >= 0
                              ? context.i18n.commandsRemainingToday(commandsRemaining, IAPManager.dailyCommandLimit)
                              : AppLocalizations.of(
                                  context,
                                ).dailyLimitReached(dailyCommandCount, IAPManager.dailyCommandLimit),
                        ).small,
                        if (commandsRemaining >= 0)
                          SizedBox(
                            width: 300,
                            child: LinearProgressIndicator(
                              value: dailyCommandCount.toDouble() / IAPManager.dailyCommandLimit.toDouble(),
                              backgroundColor: Colors.gray[300],
                              color: commandsRemaining > 0 ? Colors.orange : Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (!IAPManager.instance.isPurchased.value && !_isSmall) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 42.0),
                    child: PrimaryButton(
                      onPressed: _isPurchasing ? null : _handlePurchase,
                      leading: Icon(Icons.star),
                      child: _isPurchasing
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SmallProgressIndicator(),
                                const SizedBox(width: 8),
                                Text('Processing...'),
                              ],
                            )
                          : Text(AppLocalizations.of(context).unlockFullVersion),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 42.0, top: 8.0),
                    child: Text(AppLocalizations.of(context).fullVersionDescription).xSmall,
                  ),
                  if (Platform.isAndroid)
                    Padding(
                      padding: const EdgeInsets.only(left: 42.0, top: 8.0),
                      child: Column(
                        spacing: 8,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(),
                          Text(
                            AppLocalizations.of(context).alreadyBoughtTheApp,
                          ).small,
                          OutlineButton(
                            child: Text(context.i18n.getSupport),
                            onPressed: () {
                              String email = Uri.encodeComponent('jonas@bikecontrol.app');
                              Uri mail = Uri.parse("mailto:$email?subject=Unlock full version");

                              launchUrl(mail);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      await IAPManager.instance.purchaseFullVersion();
    } catch (e) {
      if (mounted) {
        buildToast(
          context,
          title: 'Error',
          subtitle: 'An error occurred: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }
}
