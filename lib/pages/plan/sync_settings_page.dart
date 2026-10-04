import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/subscriptions/sync_settings_view.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Settings sync, pushed from Plan & account's sync row.
class SyncSettingsPage extends StatelessWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [BkPageHeader(title: AppLocalizations.of(context).syncTitle)],
      child: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: BkPageColumn(child: SyncSettingsView()),
      ),
    );
  }
}
