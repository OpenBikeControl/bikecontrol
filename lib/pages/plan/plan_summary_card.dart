import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/models/subscription_term.dart';
import 'package:bike_control/pages/home/chain_state.dart' show LinkStatus;
import 'package:bike_control/pages/paywall.dart' show paywallProOnlyFeatures, paywallShiftAppName;
import 'package:bike_control/pages/shell/app_shell.dart' show PlanTier, currentPlanTier, planName;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/plan_format.dart';
import 'package:bike_control/widgets/home/ampel.dart' show AmpelStyle;
import 'package:bike_control/widgets/plan/vs_trial_meter.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The top of Plan & account: the plan, what it covers here, and the one
/// next step — Go Pro, manage the subscription, or (Pro on the account but
/// not on this device) register this device.
class PlanSummaryCard extends StatelessWidget {
  const PlanSummaryCard({
    super.key,
    required this.manageTarget,
    required this.onManage,
    required this.onRegister,
    required this.registering,
    required this.onQuestions,
  });

  /// Where the subscription is managed from here; null hides the compact
  /// Manage link (the page passes null where Purchases sits beside it). A
  /// billing issue shows its own Manage button regardless.
  final SubscriptionStore? manageTarget;
  final VoidCallback onManage;
  final VoidCallback onRegister;
  final bool registering;
  final VoidCallback onQuestions;

  static String? periodLabel(AppLocalizations l10n, SubscriptionPeriod? period) => switch (period) {
    SubscriptionPeriod.monthly => l10n.paywall_monthly,
    SubscriptionPeriod.yearly => l10n.paywall_yearly,
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final iap = IAPManager.instance;
    if (iap.isProButDeviceUnregistered) return _unregistered(context);
    final tier = currentPlanTier();
    return _Card(
      key: const ValueKey('plan-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (tier) {
          PlanTier.pro => _pro(context),
          PlanTier.base => _base(context),
          PlanTier.trial => _trial(context),
        },
      ),
    );
  }

  Widget _header(BuildContext context, {required String name, String? tag}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context).currentPlan,
                style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
              ),
              Text(name.toUpperCase(), style: BkDisplay.title(context)),
            ],
          ),
        ),
        if (tag != null) _Tag(tag),
      ],
    );
  }

  List<Widget> _pro(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final term = IAPManager.instance.subscriptionTerm;
    final billingIssue = term?.renewal == SubscriptionRenewal.billingIssue;
    final line = term == null || billingIssue ? null : subscriptionTermLine(l10n, term);
    return [
      _header(context, name: 'Pro', tag: periodLabel(l10n, term?.period)),
      const Gap(8),
      Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          BkStatusDot(label: l10n.proActiveOnThisDevice),
          if (line != null)
            Text(
              line,
              key: const ValueKey('plan-term'),
              style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
            ),
        ],
      ),
      if (billingIssue) ...[
        const Gap(12),
        _Notice(
          icon: LucideIcons.triangleAlert,
          title: l10n.subscriptionBillingIssue,
          body: l10n.subscriptionBillingIssueBody,
        ),
        const Gap(12),
        BkPillButton(onPressed: onManage, child: Text(l10n.manageSubscription)),
      ] else if (manageTarget != null) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: BkTouchTarget(
            child: Semantics(
              button: true,
              label: l10n.manageSubscription,
              excludeSemantics: true,
              child: Button.ghost(
                key: const ValueKey('plan-manage-link'),
                style: const ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(vertical: 8)),
                onPressed: onManage,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      l10n.manageAction,
                      style: context.typography.small.copyWith(
                        color: bkAccentText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, size: 16, color: bkAccentText(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _base(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      _header(context, name: planName(context, PlanTier.base), tag: l10n.planOneTimePurchase),
      const Gap(12),
      _Check(l10n.planBaseUnlimitedCommands),
      const Gap(6),
      _Check(_shiftLine(l10n)),
      const VsTrialMeterSlot(gap: 14),
      const Gap(16),
      _proAdds(context),
      const Gap(16),
      _goPro(context),
      _questions(context),
    ];
  }

  /// Why Go Pro: what Pro adds on top of Base, in the paywall's words.
  Widget _proAdds(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const ValueKey('plan-pro-adds'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Row(
          spacing: 8,
          children: [
            Text(l10n.planProAdds, style: context.typography.small.copyWith(fontWeight: FontWeight.w600)),
            const ProBadge(),
          ],
        ),
        for (final line in paywallProOnlyFeatures(l10n)) _Check(line, icon: LucideIcons.plus),
      ],
    );
  }

  /// The paywall's line: names the picked trainer app where it shifts.
  static String _shiftLine(AppLocalizations l10n) {
    final app = paywallShiftAppName(core.settings.getTrainerApp());
    return app == null ? l10n.paywall_shiftInYourApp : l10n.paywall_shiftInNamedApp(app);
  }

  List<Widget> _trial(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final iap = IAPManager.instance;
    final status = iap.getStatusMessage();
    return [
      _header(context, name: planName(context, PlanTier.trial)),
      if (status.isNotEmpty) ...[
        const Gap(6),
        Text(status, style: context.typography.small.copyWith(color: cs.mutedForeground)),
      ],
      const VsTrialMeterSlot(gap: 14),
      const Gap(16),
      _goPro(context),
      if (!iap.isOutsideStoreWindowsBuild) ...[
        const Gap(8),
        BkPillButton.secondary(
          onPressed: () => _run(context, 'Plan: buy full version', () => iap.purchaseFullVersion(context)),
          child: Text(l10n.buyFullVersion),
        ),
      ],
      _questions(context),
    ];
  }

  Widget _goPro(BuildContext context) => BkPillButton(
    onPressed: () => _run(context, 'Plan: go Pro', () => IAPManager.instance.purchaseSubscription(context)),
    child: Text(AppLocalizations.of(context).goPro),
  );

  Widget _questions(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Center(
      child: BkTouchTarget(
        child: Button.ghost(
          onPressed: onQuestions,
          child: Text(
            AppLocalizations.of(context).planQuestions,
            style: context.typography.small.copyWith(color: bkAccentText(context), fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ),
  );

  static Future<void> _run(BuildContext context, String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (e, s) {
      recordError(e, s, context: what);
    }
  }

  Widget _unregistered(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final warning = AmpelStyle.of(context, LinkStatus.attention);
    final term = IAPManager.instance.subscriptionTerm;
    final footer = [
      ?periodLabel(l10n, term?.period),
      if (term != null) ?subscriptionTermLine(l10n, term),
    ].join(' · ');
    return _Card(
      key: const ValueKey('plan-unregistered'),
      border: warning.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: warning.wash, borderRadius: BorderRadius.circular(11)),
                  child: Icon(LucideIcons.triangleAlert, size: 19, color: warning.text),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      l10n.proUnregisteredTitle,
                      style: context.typography.base.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      l10n.proUnregisteredBody,
                      style: context.typography.small.copyWith(color: cs.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(14),
          BkPillButton(
            key: const ValueKey('plan-register-device'),
            onPressed: registering ? null : onRegister,
            leading: registering ? const SmallProgressIndicator() : const Icon(LucideIcons.monitorSmartphone, size: 16),
            child: Text(l10n.registerThisDevice),
          ),
          const Gap(12),
          Row(
            spacing: 8,
            children: [
              const ProBadge(),
              if (footer.isNotEmpty)
                Flexible(
                  child: Text(footer, style: context.typography.xSmall.copyWith(color: cs.mutedForeground)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.child, this.border});

  final Widget child;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        border: border == null ? null : Border.all(color: border!, width: 1.5),
      ),
      child: child,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: context.typography.xSmall.copyWith(color: cs.foreground, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check(this.text, {this.icon = LucideIcons.check});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: bkAccentText(context)),
        ),
        Expanded(child: Text(text, style: context.typography.small)),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final warning = AmpelStyle.of(context, LinkStatus.attention);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: warning.wash, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Icon(icon, size: 18, color: warning.text),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(title, style: context.typography.small.copyWith(fontWeight: FontWeight.w700)),
                Text(body, style: context.typography.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
