import 'package:bike_control/pages/proxy_device_details/live_metrics_section.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The no-trainer path's own page: the Broadcast switch and the signals grid
/// behind the Sensors chain card.
///
/// Same scaffold shape as `ProxyDeviceDetailsPage`, so a rider moving between
/// a trainer's page and this one meets the same header in the same place.
/// The Broadcast card, its transport control and the empty-state panel land
/// with the page's own task; for now the page carries the grid alone, so the
/// chain card already has somewhere real to open.
class SensorsPage extends StatelessWidget {
  const SensorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(
            context.i18n.sensorsPageTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          backgroundColor: theme.colorScheme.background,
        ),
        const Divider(),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LiveMetricsSection(device: null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
