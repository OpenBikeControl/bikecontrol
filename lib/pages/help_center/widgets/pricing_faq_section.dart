// "Pricing & account" FAQ section body (Task 11). Eight Q/A rows covering the
// one-time purchase, the Pro subscription, the daily virtual-shifting trial,
// the pre-subscription "grandfather" purchases, refunds, restoring purchases
// after a reinstall, and (content round) the two other big pricing sub-themes
// from the support corpus: "I paid but it still shows Trial/Basic" and
// "I bought on one store, can I use it on another?".
//
// Copy was fact-checked against `IAPManager` (isProEnabledForCurrentDevice /
// hasPurchasedBefore50RVC / ensureProForFeature / isRegisteredDevice),
// `windows_iap_service.dart`, `revenuecat_service.dart`, `paywall.dart`'s
// feature matrix, and the existing `vsWithoutProNote` /
// `bridgeTrialTimeOverBody` strings before being written — see
// task-11-report.md (original six) and content-round-report.md (the three
// content-round additions) for the corrections that came out of each check
// (most notably: the virtual-shifting trial is a 20-minute *daily*
// allowance that resets every day, not a per-ride limit; the pre-subscription
// grandfather explicitly does not extend to virtual shifting; and Windows
// purchases made outside the Microsoft Store go through Stripe, not
// RevenueCat, so "Restore Purchases" is a literal no-op for them).
//
// shadcn_flutter's `Accordion`/`AccordionItem` keep their `content` mounted
// in the tree at all times (collapsed to zero height via `SizeTransition`
// rather than removed), which would make collapsed-vs-expanded assertions by
// key impossible. This rolls a minimal single-expansion accordion instead —
// `Button.ghost` triggers per house convention, with each answer only
// entering the widget tree while its row is expanded.
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class _FaqItem {
  final String key;
  final String question;
  final String answer;

  const _FaqItem({required this.key, required this.question, required this.answer});
}

class PricingFaqSection extends StatefulWidget {
  const PricingFaqSection({super.key});

  @override
  State<PricingFaqSection> createState() => _PricingFaqSectionState();
}

class _PricingFaqSectionState extends State<PricingFaqSection> {
  String? _expandedKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.i18n;
    final items = <_FaqItem>[
      _FaqItem(key: 'faqOneTime', question: l10n.faqOneTimeQ, answer: l10n.faqOneTimeA),
      _FaqItem(key: 'faqPro', question: l10n.faqProQ, answer: l10n.faqProA),
      // The largest pricing sub-theme in the support corpus: paid, but the
      // app still reads as Trial/Basic. Sits right after "why Pro" since
      // it's the natural next question once someone has actually paid.
      _FaqItem(key: 'faqStillTrial', question: l10n.faqStillTrialQ, answer: l10n.faqStillTrialA),
      _FaqItem(key: 'faqTrial', question: l10n.faqTrialQ, answer: l10n.faqTrialA),
      _FaqItem(key: 'faqGrandfather', question: l10n.faqGrandfatherQ, answer: l10n.faqGrandfatherA),
      _FaqItem(key: 'faqRefund', question: l10n.faqRefundQ, answer: l10n.faqRefundA),
      // Firm store policy, not a workaround — grouped with Restore at the
      // end since both are "something's wrong after I paid" entries.
      _FaqItem(key: 'faqCrossStore', question: l10n.faqCrossStoreQ, answer: l10n.faqCrossStoreA),
      // Content-round rework: this used to be "I reinstalled and my purchase
      // is gone" with an answer that just said "press Restore" — which
      // dead-ends the riders asking this exact question. Same key, reworked
      // copy (see the ARB files) covering same-store-account, one-time
      // purchases being store-bound, and Windows-outside-the-Store going
      // through Stripe rather than RevenueCat.
      _FaqItem(key: 'faqRestore', question: l10n.faqRestoreQ, answer: l10n.faqRestoreA),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(),
          _FaqRow(
            item: items[i],
            expanded: _expandedKey == items[i].key,
            onTap: () => setState(() {
              _expandedKey = _expandedKey == items[i].key ? null : items[i].key;
            }),
          ),
        ],
      ],
    );
  }
}

class _FaqRow extends StatelessWidget {
  final _FaqItem item;
  final bool expanded;
  final VoidCallback onTap;

  const _FaqRow({required this.item, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Button.ghost(
          key: ValueKey('help-faq-question-${item.key}'),
          // Bug 6: the default ghost-button padding read as cramped for an
          // accordion trigger — bump it using the same
          // `ButtonStyle.ghost().withPadding(...)` idiom vs_stage.dart uses.
          // 12/14 matches the mockup's row padding (`padding:12px 14px`) now
          // that the card itself carries no padding — rows run edge-to-edge
          // and supply their own inset.
          style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14)),
          onPressed: onTap,
          child: Basic(
            title: Text(item.question),
            trailing: Icon(
              expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              size: 18,
            ).iconMutedForeground,
          ),
        ),
        if (expanded)
          Padding(
            key: ValueKey('help-faq-answer-${item.key}'),
            // Matches the mockup's answer padding (`padding:0 14px 13px`) —
            // it hugs the question above with no top gap.
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
            child: Text(item.answer).muted.small,
          ),
      ],
    );
  }
}
