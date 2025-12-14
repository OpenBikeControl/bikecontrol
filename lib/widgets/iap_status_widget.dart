import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
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
    final isPurchased = iapManager.isPurchased;
    final isTrialExpired = iapManager.isTrialExpired;
    final trialDaysRemaining = iapManager.trialDaysRemaining;
    final commandsRemaining = iapManager.commandsRemainingToday;
    final dailyCommandCount = iapManager.dailyCommandCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredTitle(text: 'License Status'),
            const SizedBox(height: 16),
            if (isPurchased) ...[
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Full Version Unlocked',
                    style: TextStyle(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'You have unlimited access to all features.',
              ),
            ] else if (!isTrialExpired) ...[
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('Trial Period Active'),
                ],
              ),
              const SizedBox(height: 8),
              Text('$trialDaysRemaining days remaining in trial'),
              const SizedBox(height: 4),
              Text('Enjoy unlimited commands during your trial period.'),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.info, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('Free Version'),
                ],
              ),
              const SizedBox(height: 8),
              Text('Trial expired. Commands limited to 15 per day.'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: dailyCommandCount / _dailyCommandLimit,
                backgroundColor: Colors.gray[300],
                color: commandsRemaining > 0 ? Colors.orange : Colors.red,
              ),
              const SizedBox(height: 8),
              Text(
                commandsRemaining >= 0
                    ? '$commandsRemaining commands remaining today ($dailyCommandCount/$_dailyCommandLimit used)'
                    : 'Daily limit reached ($_dailyCommandLimit/$_dailyCommandLimit used)',
              ),
            ],
            if (!isPurchased) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  onPressed: _isPurchasing ? null : _handlePurchase,
                  child: _isPurchasing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Processing...'),
                          ],
                        )
                      : Text('Unlock Full Version'),
                ),
              ),
              const SizedBox(height: 8),
              OutlineButton(
                onPressed: _isPurchasing ? null : _handleRestorePurchases,
                child: Text('Restore Purchases'),
              ),
              const SizedBox(height: 8),
              Text(
                'Get unlimited commands with a one-time purchase.',
                textAlign: TextAlign.center,
              ).small,
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      final success = await IAPManager.instance.purchaseFullVersion();

      if (mounted) {
        if (success) {
          buildToast(
            context,
            title: 'Purchase Successful',
            subtitle: 'Thank you for your purchase! You now have unlimited access.',
          );
          setState(() {});
        } else {
          buildToast(
            context,
            title: 'Purchase Failed',
            subtitle: 'Unable to complete purchase. Please try again later.',
          );
        }
      }
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

  Future<void> _handleRestorePurchases() async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      await IAPManager.instance.restorePurchases();

      if (mounted) {
        // Wait a moment for the purchase stream to process
        await Future.delayed(Duration(seconds: 1));

        if (IAPManager.instance.isPurchased) {
          buildToast(
            context,
            title: 'Restore Successful',
            subtitle: 'Your purchase has been restored!',
          );
          setState(() {});
        } else {
          buildToast(
            context,
            title: 'No Purchases Found',
            subtitle: 'No previous purchases found to restore.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        buildToast(
          context,
          title: 'Error',
          subtitle: 'Failed to restore purchases: $e',
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
