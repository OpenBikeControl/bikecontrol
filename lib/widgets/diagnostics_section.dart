import 'package:bike_control/services/debug_diagnostics.dart';
import 'package:flutter/material.dart' show SelectionArea;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Renders a [DebugDiagnostics] snapshot (advertised + discovered mDNS,
/// interfaces, servers, permissions) above the log list. Pure: it takes the
/// snapshot and a refresh callback, so it is testable without app globals.
class DiagnosticsSection extends StatelessWidget {
  final DebugDiagnostics? diagnostics;
  final bool scanning;
  final VoidCallback onRefresh;

  const DiagnosticsSection({
    super.key,
    required this.diagnostics,
    required this.scanning,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final diag = diagnostics;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Diagnostics').bold,
              Row(
                children: [
                  if (scanning) Text('scanning…').muted,
                  IconButton.ghost(
                    key: const ValueKey('diagnostics-refresh'),
                    icon: Icon(LucideIcons.refreshCw, size: 18),
                    onPressed: scanning ? null : onRefresh,
                  ),
                ],
              ),
            ],
          ),
          if (diag != null)
            // Bounded + scrollable: a long block must not overflow the Logs
            // Column (which has an Expanded log list below it).
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: SelectionArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      diag.toText(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontFamilyFallback: ['Courier'],
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (!scanning)
            Text('No diagnostics yet').muted,
        ],
      ),
    );
  }
}
