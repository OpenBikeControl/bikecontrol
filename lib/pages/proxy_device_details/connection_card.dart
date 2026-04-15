import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
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
      valueListenable: emulator.isStarted,
      builder: (context, started, _) {
        if (!widget.device.isConnected && !started) {
          return _disconnectedCard(emulator);
        }
        return _connectedCard(emulator);
      },
    );
  }

  Widget _card({required Color bg, required Color border, required Widget child}) {
    return Container(
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
        spacing: 10,
        children: [
          Text(
            'Retrofit mode',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: cs.mutedForeground,
            ),
          ),
          Select<RetrofitMode>(
            value: _pendingMode,
            itemBuilder: (context, value) => Text(value.label),
            constraints: const BoxConstraints(minWidth: 220),
            popup: SelectPopup(
              items: SelectItemList(
                children: [
                  for (final m in _allowedModes) SelectItemButton(value: m, child: Text(m.label)),
                ],
              ),
            ).call,
            onChanged: (m) {
              if (m == null) return;
              setState(() => _pendingMode = m);
            },
          ),
          Text(
            _modeHint(_pendingMode),
            style: TextStyle(fontSize: 12, color: cs.mutedForeground),
          ),
          Button.primary(
            onPressed: () {
              emulator.setRetrofitMode(_pendingMode);
              widget.device.connect();
            },
            child: const Text('Connect'),
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
            'Retrofit (WiFi) — virtual shifting enabled',
          ),
          RetrofitMode.bluetooth => (
            const Color(0xFFFDF4FF),
            const Color(0xFFF5D0FE),
            const Color(0xFFFAE8FF),
            const Color(0xFFA21CAF),
            'Retrofit (Bluetooth) — virtual shifting enabled',
          ),
        };
        final usesWifi = mode != RetrofitMode.bluetooth;
        return _card(
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
        );
      },
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
                spacing: 6,
                children: [
                  Icon(LucideIcons.bluetooth, size: 16, color: accent),
                  Flexible(
                    child: Text(
                      deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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

  String _modeHint(RetrofitMode mode) => switch (mode) {
    RetrofitMode.proxy => 'Mirrors your trainer over WiFi without touching gear logic.',
    RetrofitMode.wifi => 'Adds virtual shifting to a WiFi-advertised trainer.',
    RetrofitMode.bluetooth => 'Advertises a virtual FTMS device with a 24-step gear table.',
  };
}
