import 'package:bike_control/utils/iap/iap_manager.dart';
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
            Text(
              'License Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (isPurchased) ...[
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Full Version Unlocked',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'You have unlimited access to all features.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else if (!isTrialExpired) ...[
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Trial Period Active',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$trialDaysRemaining days remaining in trial',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Enjoy unlimited commands during your trial period.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.info, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Free Version',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Trial expired. Commands limited to 15 per day.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: dailyCommandCount / _dailyCommandLimit,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  commandsRemaining > 0 ? Colors.orange : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                commandsRemaining >= 0
                    ? '$commandsRemaining commands remaining today (${dailyCommandCount}/$_dailyCommandLimit used)'
                    : 'Daily limit reached ($_dailyCommandLimit/$_dailyCommandLimit used)',
                style: Theme.of(context).textTheme.bodySmall,
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
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
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
          showToast(
            context: context,
            builder: (context) => Toast(
              title: const Text('Purchase Successful'),
              description: const Text('Thank you for your purchase! You now have unlimited access.'),
            ),
          );
          setState(() {});
        } else {
          showToast(
            context: context,
            builder: (context) => Toast(
              title: const Text('Purchase Failed'),
              description: const Text('Unable to complete purchase. Please try again later.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(
          context: context,
          builder: (context) => Toast(
            title: const Text('Error'),
            description: Text('An error occurred: $e'),
          ),
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
          showToast(
            context: context,
            builder: (context) => Toast(
              title: const Text('Restore Successful'),
              description: const Text('Your purchase has been restored!'),
            ),
          );
          setState(() {});
        } else {
          showToast(
            context: context,
            builder: (context) => Toast(
              title: const Text('No Purchases Found'),
              description: const Text('No previous purchases found to restore.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(
          context: context,
          builder: (context) => Toast(
            title: const Text('Error'),
            description: Text('Failed to restore purchases: $e'),
          ),
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
