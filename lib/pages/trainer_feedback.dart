import 'dart:async';
import 'dart:io' show Platform;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/subscriptions/login.dart';
import 'package:bike_control/services/trainer_feedback_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/keymap_explanation.dart';
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
  final TrainerFeedbackRating? initialRating;
  const TrainerFeedbackPage({super.key, required this.device, this.initialRating});

  @override
  State<TrainerFeedbackPage> createState() => _TrainerFeedbackPageState();
}

class _TrainerFeedbackPageState extends State<TrainerFeedbackPage> {
  // case-insensitive short-form matches for standard services we always skip.
  static const _standardServiceShortUuids = {
    '1800',
    '1801',
    '180a',
    '180f',
    '180e',
    '1802',
  };

  final TextEditingController _feedbackController = TextEditingController();
  TrainerFeedbackRating? _rating;
  bool _submitting = false;

  StreamSubscription<AuthState>? _authSub;
  PackageInfo? _packageInfo;
  Patch? _shorebirdPatch;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
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
          title: Text(
            AppLocalizations.of(context).trainerFeedbackTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
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
              Text(
                AppLocalizations.of(context).signInToSendFeedback,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Gap(8),
          Text(
            AppLocalizations.of(context).feedbackAccountTied,
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
            child: Text(AppLocalizations.of(context).signIn),
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

        if (_rating != null) ...[
          const Gap(20),
          _feedbackSection(),

          const Gap(20),
          _diagnosticSection(),
          const Gap(20),
          _submitButton(),
        ],
      ],
    );
  }

  Widget _ratingSection() {
    final l10n = AppLocalizations.of(context);
    return _sectionCard(
      title: l10n.yourRating,
      subtitle: l10n.requiredField,
      child: RadioGroup<TrainerFeedbackRating>(
        value: _rating,
        onChanged: (v) => setState(() => _rating = v),
        child: Row(
          spacing: 6,
          children: [
            _ratingRadio(l10n.ratingWorks, TrainerFeedbackRating.works),
            _ratingRadio(l10n.ratingNeedsAdjustment, TrainerFeedbackRating.needsAdjustment),
            _ratingRadio(l10n.ratingDoesntWork, TrainerFeedbackRating.doesNotWork),
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
    final l10n = AppLocalizations.of(context);
    return _sectionCard(
      title: l10n.yourFeedback,
      subtitle: l10n.requiredField,
      child: TextArea(
        controller: _feedbackController,
        placeholder: Text(l10n.feedbackPlaceholder),
        expandableHeight: true,
        initialHeight: 120,
      ),
    );
  }

  Widget _diagnosticSection() {
    final l10n = AppLocalizations.of(context);
    final rows = _diagnosticRows();
    return _sectionCard(
      title: l10n.diagnosticDataTitle,
      subtitle: l10n.diagnosticDataSubtitle,
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
      child: Text(AppLocalizations.of(context).sendFeedback),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _submitting = true);
    try {
      final payload = _buildPayload();
      await TrainerFeedbackService().submit(payload);
      if (!mounted) return;
      buildToast(level: LogLevel.LOGLEVEL_INFO, title: l10n.thanksForFeedback);
      Navigator.of(context).pop();
    } on TrainerFeedbackException catch (e) {
      if (!mounted) return;
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: e.message);
    } catch (_) {
      if (!mounted) return;
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: l10n.feedbackSubmitFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  TrainerFeedbackPayload _buildPayload() {
    final def = widget.device.emulator.activeDefinition;
    final fitnessDef = def is FitnessBikeDefinition ? def : null;
    final cfg = core.shiftingConfigs.activeFor(widget.device.trainerKey);

    return TrainerFeedbackPayload(
      userFeedback: _feedbackController.text.trim(),
      userRating: _rating,
      bluetoothName: _computeBluetoothName(),
      hardwareManufacturer: widget.device.manufacturerName,
      firmwareVersion: widget.device.firmwareVersion,
      trainerSupportsVirtualShifting: fitnessDef != null ? true : null,
      trainerControlMode: _controlMode(fitnessDef),
      virtualShiftingMode: fitnessDef != null ? _vsMode(cfg.mode) : null,
      gradeSmoothing: fitnessDef != null ? cfg.gradeSmoothing : null,
      gearRatios: fitnessDef != null ? (cfg.gearRatios ?? FitnessBikeDefinition.defaultGearRatios) : null,
      appVersion: _appVersion(),
      appPlatform: _appPlatform(),
      trainerApp: core.settings.getTrainerApp()?.name,
      trainerFtmsMachineFeatures: fitnessDef?.trainerFtmsMachineFeatureFlagNames,
      trainerFtmsTargetSettingFlags: fitnessDef?.trainerFtmsTargetSettingFlagNames,
      freetext: _buildServicesFreetext(),
    );
  }

  bool _isStandardService(String uuid) {
    // universal_ble gives full 128-bit UUIDs like 00001800-0000-1000-8000-00805f9b34fb
    // or sometimes the short form. Normalise and compare on the 2-byte significant chunk.
    final lower = uuid.toLowerCase();
    // Full 128-bit form with the Bluetooth base UUID: chars [4..8] carry the short ID.
    if (lower.length >= 8 && lower.endsWith('-0000-1000-8000-00805f9b34fb')) {
      final shortId = lower.substring(4, 8);
      return _standardServiceShortUuids.contains(shortId);
    }
    return _standardServiceShortUuids.contains(lower);
  }

  String? _buildServicesFreetext() {
    final services = widget.device.emulator.services;
    if (services == null || services.isEmpty) return null;
    final filtered = services.where((s) => !_isStandardService(s.uuid)).toList();
    if (filtered.isEmpty) return null;
    final buf = StringBuffer('Services & characteristics:\n');
    for (final s in filtered) {
      buf.writeln('${s.uuid}:');
      for (final c in s.characteristics) {
        buf.writeln('  - ${c.uuid}');
      }
    }
    return buf.toString().trimRight();
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

  String _vsMode(VirtualShiftingMode mode) {
    switch (mode) {
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
    final l10n = AppLocalizations.of(context);
    final payload = _buildPayload();
    final ratios = payload.gearRatios;
    return [
      (l10n.diagBluetoothName, payload.bluetoothName),
      (l10n.diagManufacturer, payload.hardwareManufacturer),
      (l10n.diagFirmware, payload.firmwareVersion),
      (
        l10n.diagSupportsVirtualShifting,
        payload.trainerSupportsVirtualShifting == null
            ? null
            : (payload.trainerSupportsVirtualShifting! ? l10n.yes : l10n.no),
      ),
      (l10n.diagControlMode, payload.trainerControlMode),
      (l10n.diagVirtualShiftingMode, payload.virtualShiftingMode?.replaceAll('_', ' ').splitByUpperCase()),
      (
        l10n.diagGradeSmoothing,
        payload.gradeSmoothing == null ? null : (payload.gradeSmoothing! ? l10n.enabledLabel : l10n.disabledLabel),
      ),
      (
        l10n.diagGearRatios,
        ratios == null || ratios.isEmpty ? null : ratios.map((r) => r.toStringAsFixed(2)).join(', '),
      ),
      (l10n.diagTrainerApp, payload.trainerApp),
      (
        l10n.diagFtmsMachineFeatures,
        payload.trainerFtmsMachineFeatures == null || payload.trainerFtmsMachineFeatures!.isEmpty
            ? null
            : payload.trainerFtmsMachineFeatures!.join(', '),
      ),
      (
        l10n.diagFtmsTargetSettings,
        payload.trainerFtmsTargetSettingFlags == null || payload.trainerFtmsTargetSettingFlags!.isEmpty
            ? null
            : payload.trainerFtmsTargetSettingFlags!.join(', '),
      ),
      (l10n.diagAppVersion, payload.appVersion),
      (l10n.diagAppPlatform, payload.appPlatform),
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
                    AppLocalizations.of(context).notAvailable,
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: cs.mutedForeground),
                  )
                : Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
