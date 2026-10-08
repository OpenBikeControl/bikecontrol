import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/title.dart' show packageInfoListenable, shorebirdPatchListenable;
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// What [AppVersionLine] shows: the running version, the Shorebird patch on
/// top of it, and whether patches come from the beta lane. Notifies when any
/// of them changes (the version and patch are read asynchronously).
abstract interface class AppVersionSource implements Listenable {
  /// The store version ("7.1.0"); null until it has been read.
  String? get version;

  /// The installed Shorebird patch; null without one (or without Shorebird).
  int? get patch;

  /// True when Shorebird is running and checks the beta update track.
  bool get onBetaTrack;

  /// The app's own values, filled in by [AppUpdateButton] and the account.
  static final AppVersionSource live = _LiveAppVersionSource();
}

class _LiveAppVersionSource implements AppVersionSource {
  late final Listenable _changes = Listenable.merge([
    packageInfoListenable,
    shorebirdPatchListenable,
    IAPManager.instance.entitlements,
  ]);

  bool? _shorebirdAvailable;

  bool get _hasShorebird {
    if (_shorebirdAvailable case final available?) return available;
    try {
      return _shorebirdAvailable = ShorebirdUpdater().isAvailable;
    } catch (e, s) {
      recordError(e, s, context: 'AppVersionSource.shorebirdAvailable');
      return _shorebirdAvailable = false;
    }
  }

  @override
  String? get version => packageInfoListenable.value?.version;

  @override
  int? get patch => shorebirdPatchListenable.value?.number;

  // The same flag checkForAppUpdate() picks the update track with.
  @override
  bool get onBetaTrack => _hasShorebird && IAPManager.instance.isBetaTester;

  @override
  void addListener(VoidCallback listener) => _changes.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _changes.removeListener(listener);
}

/// "Version 7.1.0 · Patch 4 · Beta", leaving out what does not apply; null
/// before the version is known.
String? appVersionText(AppLocalizations l10n, AppVersionSource source) {
  final version = source.version;
  if (version == null) return null;
  return [
    l10n.version(version),
    if (source.patch case final patch?) l10n.versionPatch(patch),
    if (source.onBetaTrack) l10n.versionBetaTrack,
  ].join(' · ');
}

/// The running version as a quiet caption, for the foot of Settings → App and
/// the Help Center. A tap copies it, for pasting into a support message.
class AppVersionLine extends StatelessWidget {
  const AppVersionLine({super.key, this.source, this.textAlign});

  /// Defaults to [AppVersionSource.live].
  final AppVersionSource? source;

  final TextAlign? textAlign;

  Future<void> _copy(String text, AppLocalizations l10n) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      buildToast(title: l10n.versionCopied);
    } catch (e, s) {
      recordError(e, s, context: 'AppVersionLine.copy');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final source = this.source ?? AppVersionSource.live;
    return ListenableBuilder(
      listenable: source,
      builder: (context, _) {
        final text = appVersionText(l10n, source);
        if (text == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return Button(
          style: const ButtonStyle.ghost(density: ButtonDensity.compact),
          onPressed: () => _copy(text, l10n),
          child: Text(
            text,
            textAlign: textAlign,
            style: context.typography.caption.copyWith(color: cs.mutedForeground),
          ),
        );
      },
    );
  }
}
