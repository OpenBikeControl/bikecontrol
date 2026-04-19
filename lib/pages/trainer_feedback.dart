import 'dart:async';
import 'dart:io' show Platform;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/subscriptions/login.dart';
import 'package:bike_control/services/trainer_feedback_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BackButton;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/prop.dart' hide TrainerMode;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrainerFeedbackPage extends StatefulWidget {
  final ProxyDevice device;
  const TrainerFeedbackPage({super.key, required this.device});

  @override
  State<TrainerFeedbackPage> createState() => _TrainerFeedbackPageState();
}

class _TrainerFeedbackPageState extends State<TrainerFeedbackPage> {
  final TextEditingController _feedbackController = TextEditingController();
  TrainerFeedbackRating? _rating;
  bool _submitting = false;

  StreamSubscription<AuthState>? _authSub;
  PackageInfo? _packageInfo;
  Patch? _shorebirdPatch;

  @override
  void initState() {
    super.initState();
    _authSub = core.supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
    _feedbackController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadEnvironment();
  }

  Future<void> _loadEnvironment() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final updater = ShorebirdUpdater();
      Patch? patch;
      if (updater.isAvailable) {
        try {
          patch = await updater.readCurrentPatch();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _packageInfo = info;
        _shorebirdPatch = patch;
      });
    } catch (_) {
      // best-effort; leave nulls
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          title: const Text(
            'Send Trainer Feedback',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          backgroundColor: Theme.of(context).colorScheme.background,
        ),
        const Divider(),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: core.supabase.auth.currentUser == null ? _signInGate() : _form(),
          ),
        ),
      ),
    );
  }

  Widget _signInGate() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.logIn, size: 20, color: cs.mutedForeground),
              const Gap(10),
              const Text(
                'Sign in to send feedback',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Gap(8),
          Text(
            'Feedback is tied to your BikeControl account so we can follow up on trainer-specific issues.',
            style: TextStyle(fontSize: 13, color: cs.mutedForeground),
          ),
          const Gap(16),
          Button.primary(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    headers: [
                      AppBar(
                        leading: [BackButton()],
                      ),
                    ],
                    child: const LoginPage(pushed: true),
                  ),
                ),
              );
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ratingSection(),
        const Gap(20),
        _feedbackSection(),
        const Gap(20),
        _diagnosticSection(),
        const Gap(20),
        _submitButton(),
      ],
    );
  }

  Widget _ratingSection() {
    return _sectionCard(
      title: 'Your rating',
      subtitle: 'Required',
      child: RadioGroup<TrainerFeedbackRating>(
        value: _rating,
        onChanged: (v) => setState(() => _rating = v),
        child: Row(
          spacing: 6,
          children: [
            _ratingRadio('Works', TrainerFeedbackRating.works),
            _ratingRadio('Needs adjustment', TrainerFeedbackRating.needsAdjustment),
            _ratingRadio("Doesn't work", TrainerFeedbackRating.doesNotWork),
          ],
        ),
      ),
    );
  }

  Widget _ratingRadio(String label, TrainerFeedbackRating value) {
    return Expanded(
      child: RadioCard<TrainerFeedbackRating>(
        value: value,
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _feedbackSection() {
    return _sectionCard(
      title: 'Your feedback',
      subtitle: 'Required',
      child: TextArea(
        controller: _feedbackController,
        placeholder: const Text('Describe how your trainer works with BikeControl…'),
        expandableHeight: true,
        initialHeight: 120,
      ),
    );
  }

  Widget _diagnosticSection() {
    final rows = _diagnosticRows();
    return _sectionCard(
      title: 'Diagnostic data being sent',
      subtitle: 'Read-only — automatically collected',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(),
            _kv(rows[i].$1, rows[i].$2),
          ],
        ],
      ),
    );
  }

  Widget _submitButton() {
    final enabled = _feedbackController.text.trim().isNotEmpty && _rating != null && !_submitting;
    return Button.primary(
      onPressed: enabled ? _submit : null,
      leading: _submitting ? const SmallProgressIndicator() : const Icon(LucideIcons.send, size: 16),
      child: const Text('Send feedback'),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final payload = _buildPayload();
      await TrainerFeedbackService().submit(payload);
      if (!mounted) return;
      buildToast(level: LogLevel.LOGLEVEL_INFO, title: 'Thanks for your feedback!');
      Navigator.of(context).pop();
    } on TrainerFeedbackException catch (e) {
      if (!mounted) return;
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: e.message);
    } catch (_) {
      if (!mounted) return;
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: 'Failed to submit feedback');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  TrainerFeedbackPayload _buildPayload() {
    final def = widget.device.emulator.activeDefinition;
    final fitnessDef = def is FitnessBikeDefinition ? def : null;

    return TrainerFeedbackPayload(
      userFeedback: _feedbackController.text.trim(),
      userRating: _rating,
      bluetoothName: _computeBluetoothName(),
      hardwareManufacturer: widget.device.manufacturerName,
      firmwareVersion: widget.device.firmwareVersion,
      trainerSupportsVirtualShifting: fitnessDef != null ? true : null,
      trainerControlMode: _controlMode(fitnessDef),
      virtualShiftingMode: _vsMode(),
      gradeSmoothing: core.settings.getProxyGradeSmoothing(),
      gearRatios: core.settings.getProxyGearRatios() ?? FitnessBikeDefinition.defaultGearRatios,
      appVersion: _appVersion(),
      appPlatform: _appPlatform(),
      trainerApp: core.settings.getTrainerApp()?.name,
    );
  }

  String? _computeBluetoothName() {
    final name = widget.device.deviceName;
    final hw = widget.device.hardwareRevision;
    if (name != null && hw != null) return '$name (HW: $hw)';
    if (name != null) return name;
    if (hw != null) return 'HW: $hw';
    return widget.device.name;
  }

  String? _controlMode(FitnessBikeDefinition? def) {
    if (def == null) return null;
    return def.trainerMode.value == TrainerMode.ergMode ? 'ERG' : 'SIM';
  }

  String? _vsMode() {
    switch (core.settings.getProxyVirtualShiftingMode()) {
      case VirtualShiftingMode.targetPower:
        return 'target_power';
      case VirtualShiftingMode.trackResistance:
        return 'track_resistance';
      case VirtualShiftingMode.basicResistance:
        return 'basic';
    }
  }

  String? _appVersion() {
    final info = _packageInfo;
    if (info == null) return null;
    final patch = _shorebirdPatch;
    return patch == null ? info.version : '${info.version}+${patch.number}';
  }

  String _appPlatform() {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }

  List<(String, String?)> _diagnosticRows() {
    final payload = _buildPayload();
    final ratios = payload.gearRatios;
    return [
      ('Bluetooth name', payload.bluetoothName),
      ('Manufacturer', payload.hardwareManufacturer),
      ('Firmware', payload.firmwareVersion),
      (
        'Supports virtual shifting',
        payload.trainerSupportsVirtualShifting == null
            ? null
            : (payload.trainerSupportsVirtualShifting! ? 'Yes' : 'No'),
      ),
      ('Control mode', payload.trainerControlMode),
      ('Virtual shifting mode', payload.virtualShiftingMode),
      (
        'Grade smoothing',
        payload.gradeSmoothing == null ? null : (payload.gradeSmoothing! ? 'Enabled' : 'Disabled'),
      ),
      (
        'Gear ratios',
        ratios == null || ratios.isEmpty ? null : ratios.map((r) => r.toStringAsFixed(2)).join(', '),
      ),
      ('Trainer app', payload.trainerApp),
      ('App version', payload.appVersion),
      ('App platform', payload.appPlatform),
    ];
  }

  Widget _sectionCard({required String title, String? subtitle, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
          if (subtitle != null) ...[
            const Gap(2),
            Text(subtitle, style: TextStyle(fontSize: 12, color: cs.mutedForeground)),
          ],
          const Gap(12),
          child,
        ],
      ),
    );
  }

  Widget _kv(String label, String? value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: TextStyle(fontSize: 13, color: cs.mutedForeground)),
          ),
          Expanded(
            child: value == null
                ? Text(
                    'Not available',
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: cs.mutedForeground),
                  )
                : Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
