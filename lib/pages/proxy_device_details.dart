import 'dart:async';
import 'dart:convert';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/pages/proxy_device_details/gear_hero_card.dart';
import 'package:bike_control/pages/proxy_device_details/live_metrics_section.dart';
import 'package:bike_control/pages/proxy_device_details/mini_workout_card.dart';
import 'package:bike_control/pages/proxy_device_details/overlay_settings_section.dart';
import 'package:bike_control/pages/proxy_device_details/trainer_settings_section.dart';
import 'package:bike_control/pages/proxy_device_details/virtual_shifting_pro_notice.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/overview_screenshot.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ProxyDeviceDetailsPage extends StatefulWidget {
  final ProxyDevice device;
  const ProxyDeviceDetailsPage({super.key, required this.device});

  @override
  State<ProxyDeviceDetailsPage> createState() => _ProxyDeviceDetailsPageState();
}

class _ProxyDeviceDetailsPageState extends State<ProxyDeviceDetailsPage> {
  late StreamSubscription<BaseDevice> _connectionSub;

  void _onEmulatorStateChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.device.isStartedListenable.addListener(_onEmulatorStateChanged);
    widget.device.onChange.addListener(_onEmulatorStateChanged);
    widget.device.isConnectedListenable.addListener(_onEmulatorStateChanged);
    widget.device.retrofitMode.addListener(_onEmulatorStateChanged);
    _connectionSub = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionSub.cancel();
    widget.device.isStartedListenable.removeListener(_onEmulatorStateChanged);
    widget.device.onChange.removeListener(_onEmulatorStateChanged);
    widget.device.isConnectedListenable.removeListener(_onEmulatorStateChanged);
    widget.device.retrofitMode.removeListener(_onEmulatorStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;

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
            AppLocalizations.of(context).smartTrainer,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          trailing: [
            IconButton.ghost(
              icon: Icon(LucideIcons.x, size: 22, color: Theme.of(context).colorScheme.mutedForeground),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          backgroundColor: Theme.of(context).colorScheme.background,
        ),
        const Divider(),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _deviceCard(),
                SizedBox(height: 12),
                if (_ftmsMissingWarning() case final w?) ...[
                  w,
                  SizedBox(height: 12),
                ],

                if (!screenshotMode) ...[
                  ConnectionCard(device: device),
                  SizedBox(height: 2),
                ],
                if (!screenshotMode) _provideFeedbackBox(),
                SizedBox(height: 12),
                _gearSection(),
                SizedBox(height: 20),
                if (!IAPManager.instance.isProEnabledForCurrentDevice &&
                    widget.device.fitnessBike != null &&
                    !screenshotMode) ...[
                  ValueListenableBuilder<Duration>(
                    valueListenable: core.bridgeUsageTracker.usedTodayListenable,
                    builder: (context, used, _) {
                      final remaining = core.bridgeUsageTracker.dailyLimit - used;
                      final clamped = remaining.isNegative ? Duration.zero : remaining;
                      return VirtualShiftingProNotice(
                        trainerAppName:
                            core.settings.getTrainerApp()?.name ?? AppLocalizations.of(context).yourTrainerApp,
                        remainingToday: clamped,
                      );
                    },
                  ),
                  SizedBox(height: 26),
                ],
                LiveMetricsSection(device: device),
                SizedBox(height: 20),
                MiniWorkoutCard(device: device),
                SizedBox(height: 20),
                _settingsSection(),
                SizedBox(height: 32),
                _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _provideFeedbackBox() {
    final cs = Theme.of(context).colorScheme;
    final hasSubmitted = core.settings.getFeedbackSubmitted(widget.device.trainerKey);
    return Card(
      padding: const EdgeInsets.all(12),
      fillColor: cs.secondary,
      filled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.i18n.provideFeedback,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Button(
                  style: ButtonStyle.outline(),
                  onPressed: () => _submitFeedback('feedbackWorks', context.i18n.feedbackWorks),
                  leading: const Icon(LucideIcons.thumbsUp, size: 16),
                  child: Text(context.i18n.feedbackWorks),
                ),
              ),
              if (hasSubmitted) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Button(
                    style: ButtonStyle.outline(),
                    onPressed: () => _submitFeedback('feedbackNoDifference', context.i18n.feedbackNoDifference),
                    leading: const Icon(LucideIcons.minus, size: 16),
                    child: Text(context.i18n.feedbackNoDifference),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Button(
                  style: ButtonStyle.outline(),
                  onPressed: () => _submitFeedback('feedbackNotWorking', context.i18n.feedbackNotWorking),
                  leading: const Icon(LucideIcons.thumbsDown, size: 16),
                  child: Text(context.i18n.feedbackNotWorking),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback(String key, String label) async {
    final device = widget.device;
    final base = buildProxyServicesFreetext(device);
    final composed = (base == null || base.isEmpty) ? key : '$key\n\n$base';
    await core.settings.setFeedbackSubmitted(device.trainerKey, true);
    if (!mounted) return;
    setState(() {});
    final snapshot = TelemetrySnapshot.fromDevice(device: device, freetextOverride: composed);
    final screenshot = await captureOverviewScreenshot(context: context);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SupportChatPage(
          telemetryBuilder: () async => snapshot,
          diagnosticPreview: JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
          initialText: '$label\n',
          initialAttachment: screenshot,
        ),
      ),
    );
  }

  Widget? _ftmsMissingWarning() {
    final supportsVS = widget.device.fitnessBike?.supportsVirtualShiftingMode(VirtualShiftingMode.targetPower) == true;
    if (supportsVS) return null;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          Expanded(
            child: Text(
              AppLocalizations.of(context).trainerMissingFtmsWarning(widget.device.name),
              style: TextStyle(fontSize: 12, color: cs.foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.border),
      ),
      child: widget.device.showInformation(context, showFull: true),
    );
  }

  Widget _gearSection() {
    final def = widget.device.fitnessBike;
    if (def == null) return const SizedBox.shrink();
    return GearHeroCard(definition: def);
  }

  Widget _settingsSection() {
    final def = widget.device.fitnessBike;
    if (def == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(
          AppLocalizations.of(context).virtualShiftingSettings,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        TrainerSettingsSection(definition: def, device: widget.device),
        OverlaySettingsSection(definition: def, device: widget.device),
      ],
    );
  }

  Widget _actions() {
    final device = widget.device;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        LoadingWidget(
          futureCallback: () async {
            await core.settings.setAutoConnect(device.trainerKey, false);
            await core.connection.disconnect(device, forget: false, persistForget: false);
            if (mounted) Navigator.of(context).pop();
          },
          renderChild: (isLoading, tap) => Button(
            style: ButtonStyle.outline(),
            onPressed: tap,
            leading: isLoading ? const SmallProgressIndicator() : const Icon(LucideIcons.bluetoothOff, size: 18),
            child: Text(AppLocalizations.of(context).disconnectAndForgetForThisSession),
          ),
        ),
        LoadingWidget(
          futureCallback: () async {
            await core.settings.setAutoConnect(device.trainerKey, false);
            await core.connection.disconnect(device, forget: true, persistForget: true);
            if (mounted) Navigator.of(context).pop();
          },
          renderChild: (isLoading, tap) => Button(
            style: ButtonStyle.destructive(),
            onPressed: tap,
            leading: isLoading ? const SmallProgressIndicator() : const Icon(LucideIcons.trash2, size: 18),
            child: Text(AppLocalizations.of(context).disconnectAndForget),
          ),
        ),
      ],
    );
  }
}
