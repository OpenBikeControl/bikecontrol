import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ConnectionCard extends StatefulWidget {
  final ProxyDevice device;
  const ConnectionCard({super.key, required this.device});

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {
  late RetrofitMode _pendingMode;

  @override
  void initState() {
    super.initState();
    final saved = widget.device.emulator.retrofitMode.value;
    _pendingMode = _allowedModes.contains(saved) ? saved : RetrofitMode.proxy;
  }

  List<RetrofitMode> get _allowedModes => [
    RetrofitMode.proxy,
    if (widget.device.scanResult.services.any((s) => s == FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID))
      RetrofitMode.wifi,
    RetrofitMode.bluetooth,
  ];

  @override
  Widget build(BuildContext context) {
    final emulator = widget.device.emulator;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.device.isStarting,
      builder: (context, starting, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: emulator.isStarted,
          builder: (context, started, _) {
            if (starting && !started) {
              return _connectingCard(emulator);
            }
            if (!widget.device.isConnected && !started) {
              return _disconnectedCard(emulator);
            }
            return _connectedCard(emulator);
          },
        );
      },
    );
  }

  Widget _connectingCard(DirconEmulator emulator) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      bg: cs.card,
      border: cs.border,
      child: Row(
        spacing: 12,
        children: [
          const SmallProgressIndicator(),
          Expanded(
            child: Text(
              'Connecting in ${emulator.retrofitMode.value.label} mode…',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Color bg, required Color border, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  Widget _disconnectedCard(DirconEmulator emulator) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      bg: cs.card,
      border: cs.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Text(
            'CONNECT MODE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: cs.mutedForeground,
            ),
          ),
          RadioGroup<RetrofitMode>(
            value: _pendingMode,
            onChanged: (m) async {
              setState(() => _pendingMode = m);
              await core.settings.setRetrofitMode(widget.device.trainerKey, m);
            },
            child: Column(
              spacing: 8,
              children: [
                for (final m in _allowedModes)
                  RadioCard<RetrofitMode>(
                    value: m,
                    child: Row(
                      spacing: 12,
                      children: [
                        Icon(_modeIcon(m), size: 20, color: cs.mutedForeground),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              Text(
                                m.label,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                _modeHint(m),
                                style: TextStyle(fontSize: 11, color: cs.mutedForeground),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          LoadingWidget(
            futureCallback: () async {
              emulator.setRetrofitMode(_pendingMode);
              await core.settings.setRetrofitMode(widget.device.trainerKey, _pendingMode);
              await widget.device.startProxy();
            },
            renderChild: (isLoading, tap) => Button.primary(
              onPressed: tap,
              child: isLoading ? SmallProgressIndicator() : const Text('Connect'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectedCard(DirconEmulator emulator) {
    return ValueListenableBuilder<RetrofitMode>(
      valueListenable: emulator.retrofitMode,
      builder: (context, mode, _) => _modePickerCompact(mode),
    );
  }

  Widget _modePickerCompact(RetrofitMode active) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      bg: cs.card,
      border: cs.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            'CONNECT MODE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: cs.mutedForeground),
          ),
          RadioGroup<RetrofitMode>(
            value: active,
            onChanged: (m) async {
              if (m == active) return;
              await core.settings.setRetrofitMode(widget.device.trainerKey, m);
              setState(() => _pendingMode = m);
              try {
                // The emulator seeds any freshly-created FitnessBikeDefinition
                // synchronously via ProxyDevice.onFitnessBikeDefinitionCreated,
                // so by the time switchRetrofitMode returns the new transport
                // is already running against the user's active ShiftingConfig.
                await widget.device.emulator.switchRetrofitMode(m);
              } catch (e) {
                if (kDebugMode) print('switchRetrofitMode failed: $e');
              }
            },
            child: Column(
              spacing: 8,
              children: [
                for (final m in _allowedModes)
                  RadioCard<RetrofitMode>(
                    value: m,
                    child: Row(
                      spacing: 12,
                      children: [
                        Icon(_modeIcon(m), size: 20, color: cs.mutedForeground),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              Text(m.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(_modeHint(m), style: TextStyle(fontSize: 11, color: cs.mutedForeground)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _modeIcon(RetrofitMode mode) => switch (mode) {
    RetrofitMode.proxy => LucideIcons.wifi,
    RetrofitMode.wifi => LucideIcons.cog,
    RetrofitMode.bluetooth => LucideIcons.bluetooth,
  };

  String _modeHint(RetrofitMode mode) => switch (mode) {
    RetrofitMode.proxy => 'Mirrors your trainer over WiFi without touching gear logic.',
    RetrofitMode.wifi => 'Adds or adjusts virtual shifting and creates a WiFi-advertised trainer.',
    RetrofitMode.bluetooth =>
      'Adds or adjusts virtual shifting and creates a Bluetooth-advertised trainer (recommended on iOS).',
  };
}
