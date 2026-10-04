import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/help_center/widgets/pricing_faq_section.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// "Questions about the plans?": the Help Center's pricing & account answers
/// on their own page.
class PlanFaqPage extends StatelessWidget {
  const PlanFaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [BkPageHeader(title: AppLocalizations.of(context).helpCenterPricingFaq)],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: BkPageColumn(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const PricingFaqSection(),
          ),
        ),
      ),
    );
  }
}
