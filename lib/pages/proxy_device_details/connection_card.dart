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
      builder: (context, mode, _) {
        final (bg, border, iconBg, iconColor, title) = switch (mode) {
          RetrofitMode.proxy => (
            const Color(0xFFF0FDF4),
            const Color(0xFFBBF7D0),
            const Color(0xFFDCFCE7),
            const Color(0xFF059669),
            'Proxy active — mirroring via WiFi',
          ),
          RetrofitMode.wifi => (
            const Color(0xFFEFF6FF),
            const Color(0xFFBFDBFE),
            const Color(0xFFDBEAFE),
            const Color(0xFF1D4ED8),
            'Virtual Shifting (WiFi) — active',
          ),
          RetrofitMode.bluetooth => (
            const Color(0xFFFDF4FF),
            const Color(0xFFF5D0FE),
            const Color(0xFFFAE8FF),
            const Color(0xFFA21CAF),
            'Virtual Shifting (Bluetooth) — active',
          ),
        };
        final usesWifi = mode != RetrofitMode.bluetooth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            _modePickerCompact(mode),
            _card(
              bg: bg,
              border: border,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Row(
                    spacing: 12,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(LucideIcons.radioTower, size: 18, color: iconColor),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (usesWifi) _bridgeRow(emulator, iconColor),
                ],
              ),
            ),
          ],
        );
      },
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

  Widget _bridgeRow(DirconEmulator emulator, Color accent) {
    final deviceName = widget.device.scanResult.name ?? 'Device';
    return ValueListenableBuilder<String?>(
      valueListenable: emulator.localAddress,
      builder: (context, ip, _) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            spacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Icon(LucideIcons.bluetooth, size: 16, color: accent),
                  Text(
                    deviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    _dot(accent),
                    _dot(accent),
                    _dot(accent),
                    Icon(LucideIcons.arrowRight, size: 14, color: accent),
                    _dot(accent),
                    _dot(accent),
                    _dot(accent),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Icon(LucideIcons.wifi, size: 16, color: accent),
                  Text(
                    ip ?? '—',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dot(Color color) => Container(
    width: 3,
    height: 3,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.45),
      shape: BoxShape.circle,
    ),
  );

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
