import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Widget to display IAP status and allow purchases
class IAPStatusWidget extends StatefulWidget {
  const IAPStatusWidget({super.key});

  @override
  State<IAPStatusWidget> createState() => _IAPStatusWidgetState();
}

class _IAPStatusWidgetState extends State<IAPStatusWidget> {
  static const int _dailyCommandLimit = 15; // Should match IAPService.dailyCommandLimit
  bool _isPurchasing = false;

  @override
  Widget build(BuildContext context) {
    final iapManager = IAPManager.instance;
    final isTrialExpired = iapManager.isTrialExpired;
    final trialDaysRemaining = iapManager.trialDaysRemaining;
    final commandsRemaining = iapManager.commandsRemainingToday;
    final dailyCommandCount = iapManager.dailyCommandCount;

    return Card(
      child: SizedBox(
        width: double.infinity,
        child: ValueListenableBuilder(
          valueListenable: IAPManager.instance.isPurchased,
          builder: (context, isPurchased, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ColoredTitle(text: AppLocalizations.of(context).licenseStatus),
                const SizedBox(height: 16),
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
                  Basic(
                    leadingAlignment: Alignment.centerLeft,
                    leading: Icon(Icons.access_time, color: Colors.blue),
                    title: Text(AppLocalizations.of(context).trialPeriodActive(trialDaysRemaining)),
                    subtitle: Text(
                      AppLocalizations.of(context).trialPeriodDescription(_dailyCommandLimit),
                    ),
                  ),
                ] else ...[
                  Basic(
                    leadingAlignment: Alignment.centerLeft,
                    leading: Icon(Icons.lock),
                    title: Text(AppLocalizations.of(context).trialExpired(_dailyCommandLimit)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 6),
                        Text(
                          commandsRemaining >= 0
                              ? context.i18n.commandsRemainingToday(commandsRemaining, _dailyCommandLimit)
                              : AppLocalizations.of(context).dailyLimitReached(dailyCommandCount, _dailyCommandLimit),
                        ).small,
                        if (commandsRemaining >= 0)
                          SizedBox(
                            width: 300,
                            child: LinearProgressIndicator(
                              value: dailyCommandCount.toDouble() / _dailyCommandLimit.toDouble(),
                              backgroundColor: Colors.gray[300],
                              color: commandsRemaining > 0 ? Colors.orange : Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (!IAPManager.instance.isPurchased.value) ...[
                  const SizedBox(height: 16),
                  PrimaryButton(
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
