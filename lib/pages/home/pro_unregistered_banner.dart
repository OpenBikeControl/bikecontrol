import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/register_this_device.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Home banner for the rider whose account has Pro but whose device is not
/// registered for it — until now signalled only by "Pro (unregistered
/// device)" in the title bar, which riders do not read.
/// Says what is going on and carries the fix. Not dismissible: the state
/// itself is what clears it. Renders nothing (no gap either) otherwise, and
/// follows the IAP notifiers so a restore or a registration moves it without
/// a page rebuild.
///
/// Built from the same parts as the chain cards and the trial card so it
/// belongs to the stack.
class ProUnregisteredBanner extends StatefulWidget {
  /// Test seam for the registration; production runs [registerThisDevice].
  final Future<bool> Function(BuildContext context)? register;

  const ProUnregisteredBanner({super.key, this.register});

  @override
  State<ProUnregisteredBanner> createState() => _ProUnregisteredBannerState();
}

class _ProUnregisteredBannerState extends State<ProUnregisteredBanner> {
  final IAPManager _iap = IAPManager.instance;

  /// Everything [IAPManager.isProButDeviceUnregistered] reads that can change
  /// at runtime: the account's entitlements (and registration flag), the
  /// purchase flag, and the store-side Pro flag.
  late final Listenable _iapState = Listenable.merge([_iap.entitlements, _iap.isPurchased, _iap.isLocalPro]);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _iapState,
      builder: (context, _) {
        if (!_iap.isProButDeviceUnregistered) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final l = context.i18n;
        final warning = AmpelStyle.of(context, LinkStatus.attention);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: ShapeDecoration(
              color: theme.colorScheme.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: warning.color, width: 1.5),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: warning.wash, borderRadius: BorderRadius.circular(11)),
                        child: Icon(LucideIcons.badgeAlert, size: 19, color: warning.color),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.proUnregisteredTitle,
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                            ),
                            const Gap(2),
                            Text(
                              l.proUnregisteredBody,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RegisterThisDeviceButton(register: widget.register, size: ButtonSize.small),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
