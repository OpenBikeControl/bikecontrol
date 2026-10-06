import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/customize.dart';
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The two icons beside the mapping dropdown — sync (a cloud with a dot) and
/// manage (a gear) — had no words: a rider couldn't tell what they do, and a
/// screen reader read "button".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'customize-icon-labels-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.settings.setTrainerApp(MyWhoosh());
    core.actionHandler.init(MyWhoosh());
  });

  testWidgets('sync and manage say what they do, to the eye and to a screen reader', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    debugHostPlatformOverride = TargetPlatform.macOS;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(child: CustomizePage(isMobile: false)),
      ),
    );
    await tester.pump();
    final l = AppLocalizations.current;

    for (final (label, icon) in [
      (l.keymapSyncLabel, LucideIcons.cloudUpload),
      (l.keymapManageLabel, LucideIcons.settings),
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      expect(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(Tooltip)),
        findsOneWidget,
        reason: '$label shows on hover',
      );
    }
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
    debugHostPlatformOverride = null;
  });
}
