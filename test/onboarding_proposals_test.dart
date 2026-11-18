@Tags(['screenshots'])
library;

// Onboarding simplification mock-ups (current flow, proposals A/B, trainer-first
// step 2 with flat virtual shifting scenes). Renders to build/snapshots/proposals:
//   flutter test test/onboarding_proposals_test.dart --run-skipped --tags screenshots

import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/pages/onboarding/onboarding_app_guides.dart';
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/onboarding/steps/step_app.dart';
import 'package:bike_control/pages/onboarding/steps/step_connection.dart';
import 'package:bike_control/pages/onboarding/steps/step_controller.dart';
import 'package:bike_control/pages/onboarding/steps/step_done.dart';
import 'package:bike_control/pages/onboarding/steps/step_trainer.dart';
import 'package:bike_control/pages/onboarding/steps/step_welcome.dart';
import 'package:bike_control/pages/onboarding/steps/step_where.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_headline.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/trainer_app_logo.dart';
import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/pages/onboarding/widgets/vs_shift_compare.dart';
import 'package:bike_control/pages/onboarding/widgets/vs_stage.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/controller/controller_canvas.dart';
import 'package:bike_control/widgets/ui/animated_button_widget.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_presets.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'widget_snapshot.dart';

const _w = 390.0;
const _h = 800.0;
const _out = 'build/snapshots/proposals';

SupportedApp _app(String name) => SupportedApp.supportedApps.firstWhere((a) => a.name == name);

// ── Proposal shell: X · progress · ?, body, one pill + optional text link ──
Widget protoShell(
  BuildContext context, {
  required int step,
  required int total,
  required Widget body,
  required String primary,
  bool primaryEnabled = true,
  String? secondary,
}) {
  final cs = Theme.of(context).colorScheme;
  return Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(children: [
        SizedBox(width: 48, child: Center(child: Icon(LucideIcons.x, size: 20, color: cs.mutedForeground))),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const Gap(6),
              Container(
                width: i == step ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i <= step ? onboardingAccent(context) : cs.border,
                ),
              ),
            ],
          ]),
        ),
        SizedBox(width: 48, child: Center(child: Icon(LucideIcons.circleHelp, size: 22, color: bkAccentText(context)))),
      ]),
    ),
    const Gap(8),
    Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: body,
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BkPillButton(onPressed: primaryEnabled ? () {} : null, child: Text(primary)),
        if (secondary != null) ...[
          const Gap(4),
          SizedBox(
            height: 44,
            child: Center(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: bkAccentText(context), fontWeight: FontWeight.w600),
                child: Text(secondary).small,
              ),
            ),
          ),
        ],
      ]),
    ),
  ]);
}

Widget _title(String t, [String? sub]) => Builder(
      builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OnboardingHeadline(t),
        if (sub != null) ...[const Gap(6), Text(sub).small.muted],
        const Gap(18),
      ]),
    );

/// Big 2-col app tile with real logo.
Widget _bigAppTile(BuildContext context, SupportedApp app, {bool selected = false}) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: cs.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: selected ? onboardingAccent(context) : const Color(0x00000000), width: 2),
    ),
    child: Row(children: [
      SizedBox(
        width: 36,
        height: 36,
        child: app.logoAsset != null
            ? TrainerAppLogo(asset: app.logoAsset!, url: app.logoUrl, height: 32, fit: BoxFit.contain)
            : Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), color: cs.muted),
                child: Text(app.name.substring(0, 1)).semiBold.muted,
              ),
      ),
      const Gap(10),
      Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(app.name.length > 12 ? app.name.replaceFirst(' ', '\n') : app.name, maxLines: 2).small.semiBold)),
    ]),
  );
}

Widget _topApps(BuildContext context, {String? selected}) {
  final apps = ['MyWhoosh', 'Zwift', 'Rouvy', 'TrainingPeaks Virtual', 'icTrainer', 'Biketerra'].map(_app).toList();
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    for (var r = 0; r < 3; r++) ...[
      if (r > 0) const Gap(8),
      Row(children: [
        Expanded(child: _bigAppTile(context, apps[r * 2], selected: apps[r * 2].name == selected)),
        const Gap(8),
        Expanded(child: _bigAppTile(context, apps[r * 2 + 1], selected: apps[r * 2 + 1].name == selected)),
      ]),
    ],
    const Gap(8),
    BkGroupedSection(children: [
      BkGroupedRow(
        icon: LucideIcons.layoutGrid,
        title: 'Other apps',
        subtitle: 'Strappo, FulGaz, Tacx and ${SupportedApp.supportedApps.length - 9} more',
        chevron: true,
        onPressed: () {},
      ),
    ]),
  ]);
}

/// Two-option segmented control.
Widget _segmented(BuildContext context, List<(IconData, String)> options, int selected) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      for (var i = 0; i < options.length; i++)
        Expanded(
          child: Container(
            height: 44,
            decoration: i == selected
                ? BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(11), boxShadow: [
                    BoxShadow(color: const Color(0x14000000), blurRadius: 4, offset: const Offset(0, 1)),
                  ])
                : null,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(options[i].$1, size: 16, color: i == selected ? onboardingAccent(context) : cs.mutedForeground),
              const Gap(8),
              i == selected ? Text(options[i].$2).small.semiBold : Text(options[i].$2).small.muted,
            ]),
          ),
        ),
    ]),
  );
}

Widget _choiceRow(BuildContext context, IconData icon, String title, String sub, {bool selected = false}) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: cs.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: selected ? onboardingAccent(context) : const Color(0x00000000), width: 2),
    ),
    child: Row(children: [
      BkIconTile(icon: icon, color: selected ? onboardingAccent(context) : null),
      const Gap(12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title).semiBold,
          Text(sub).xSmall.muted,
        ]),
      ),
      Icon(selected ? LucideIcons.circleCheck : LucideIcons.circle,
          size: 20, color: selected ? onboardingAccent(context) : cs.border),
    ]),
  );
}

Widget _deviceRow(BuildContext context, IconData icon, String name, {String? sub, Widget? trailing}) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(16)),
    child: Row(children: [
      BkIconTile(icon: icon),
      const Gap(12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name).small.semiBold,
          if (sub != null) Text(sub).xSmall.muted,
        ]),
      ),
      ?trailing,
    ]),
  );
}

Widget _label(BuildContext context, String t, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(children: [
        Expanded(child: BkGroupedHeader(t)),
        ?trailing,
      ]),
    );

/// The live "checklist" row used by proposal B's last step / proposal A's done.
Widget _checkRow(BuildContext context, IconData icon, String name, String status, {required bool ok, bool first = false}) {
  final cs = Theme.of(context).colorScheme;
  final st = BkStatusColors.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: cs.border))),
    child: Row(children: [
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? st.success : cs.muted),
        child: ok
            ? Icon(LucideIcons.check, size: 15, color: st.successForeground)
            : Padding(padding: const EdgeInsets.all(6), child: CircularProgressIndicator(size: 14)),
      ),
      const Gap(12),
      Icon(icon, size: 16, color: cs.mutedForeground),
      const Gap(8),
      Expanded(child: Text(name).small.semiBold),
      ok ? Text(status).xSmall.muted : Text(status).xSmall.semiBold,
    ]),
  );
}

Widget _card(BuildContext context, Widget child) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.card, borderRadius: BorderRadius.circular(16)),
      child: child,
    );


/// Controller card with its contour, as on today's controller step.
Widget _contour(BuildContext context, BaseDevice device, {double? maxHeight}) {
  final size = (maxHeight == null ? 52 : 44) / Theme.of(context).scaling;
  return _card(context, Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 44, child: Row(children: [
        BkIconTile(icon: device.icon),
        const Gap(12),
        Expanded(child: Text(device.displayName(context)).small.semiBold),
        const BkStatusDot(label: 'Connected'),
      ])),
      const Gap(4),
      ConstrainedBox(constraints: BoxConstraints(maxHeight: maxHeight ?? double.infinity), child: ControllerCanvas(
        layout: device.controllerLayout!,
        availableButtons: device.availableButtons,
        buttonSize: size,
        buttonBuilder: (btn) => AnimatedButtonWidget(
          key: ValueKey(btn.name), button: btn, pressGeneration: 0,
          keymap: core.actionHandler.supportedApp?.keymap, device: device, size: size, onUpdate: () {}),
      )),
      const Gap(6),
      Center(child: Text('Press a button — it lights up here.').xSmall.muted),
    ]),
  ));
}

Widget _trainerCard(BuildContext context, {required bool on, Widget? explainer}) {
  final cs = Theme.of(context).colorScheme;
  return _card(context, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        const BkIconTile(icon: LucideIcons.bike),
        const Gap(12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('KICKR CORE 1EB7').small.semiBold,
          const Text('Bluetooth').xSmall.muted,
        ])),
        const BkStatusDot(label: 'Connected'),
      ]),
    ),
    Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.border))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Text('Shift with BikeControl').small.semiBold, const Gap(8), const ProBadge()]),
          Text(on ? 'BikeControl shifts at your trainer.' : 'Off: MyWhoosh does the shifting.').xSmall.muted,
        ])),
        const Gap(10),
        Switch(value: on, onChanged: (_) {}),
      ]),
    ),
    ?explainer,
  ]));
}

Widget _benefit(BuildContext context, IconData icon, String title, String sub) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30, height: 30, alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: onboardingAccent(context).withValues(alpha: 0.12)),
          child: Icon(icon, size: 15, color: onboardingAccent(context)),
        ),
        const Gap(11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title).small.semiBold,
          Text(sub).xSmall.muted,
        ])),
      ]),
    );

Widget _howLink(BuildContext context, String t) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: bkAccentText(context), fontWeight: FontWeight.w600),
        child: Row(children: [Text(t).small, const Gap(4), Icon(LucideIcons.chevronRight, size: 14, color: bkAccentText(context))]),
      ),
    );

/// Variant 1: three benefits inside the trainer card.
Widget _pitchBenefits(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      decoration: BoxDecoration(
        color: onboardingAccent(context).withValues(alpha: 0.06),
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _benefit(context, LucideIcons.zap, 'Snappier shifts', 'The gear changes right at the trainer, not a beat later via the app.'),
        _benefit(context, LucideIcons.cog, 'Front derailleur', 'Big and small ring, like on the road.'),
        _benefit(context, LucideIcons.slidersHorizontal, 'Your own gears', 'Pick a cassette and ratios — in any app.'),
        _howLink(context, 'See how it works'),
      ]),
    );

/// Variant 2: the existing shift-curve comparison as the explainer.
Widget _pitchCurve(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const VsShiftCompare(app: 'MyWhoosh', native: false, active: false),
        _howLink(context, 'Front derailleur, own gears & more'),
      ]),
    );


// ── C: trainer connection as the default path ──
enum _Tr { searching, found, connected }

Widget _trainerRow(BuildContext context, _Tr state) {
  final cs = Theme.of(context).colorScheme;
  final st = BkStatusColors.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Row(children: [
      BkIconTile(icon: LucideIcons.bike, color: state == _Tr.connected ? st.success : null),
      const Gap(12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(state == _Tr.searching ? 'Looking for your trainer…' : 'KICKR CORE 1EB7').small.semiBold,
        Text(switch (state) {
          _Tr.searching => 'Pedal once to wake it up.',
          _Tr.found => 'Found nearby',
          _Tr.connected => 'Virtual shifting by BikeControl',
        }).xSmall.muted,
      ])),
      switch (state) {
        _Tr.searching => SizedBox(width: 18, height: 18, child: CircularProgressIndicator(size: 18, color: cs.mutedForeground)),
        _Tr.found => PrimaryButton(size: ButtonSize.small, onPressed: () {}, child: const Text('Connect')),
        _Tr.connected => const BkStatusDot(label: 'Connected'),
      },
    ]),
  );
}

Widget _whyBikeControl(BuildContext context, {required String app}) => Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: onboardingAccent(context).withValues(alpha: 0.06),
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Why through BikeControl?').xSmall.semiBold.muted,
        _benefit(context, LucideIcons.bike, 'Virtual shifting on almost any trainer', 'Also on trainers $app can\'t shift itself.'),
        _benefit(context, LucideIcons.zap, 'Shifts you feel instantly', 'The gear changes right at the trainer.'),
        _benefit(context, LucideIcons.cog, 'Front derailleur & your own gears', 'Big and small ring, any cassette.'),
        _howLink(context, 'See how it works'),
      ]),
    );

Widget _trainerSection(BuildContext context, _Tr state, {String app = 'MyWhoosh'}) => _card(
    context,
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _trainerRow(context, state),
      if (state != _Tr.connected) _whyBikeControl(context, app: app),
    ]));

Widget _whyVisual(BuildContext context, int scene) => Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: onboardingAccent(context).withValues(alpha: 0.06),
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Why through BikeControl?').xSmall.semiBold.muted,
        const Gap(8),
        VirtualShiftingStage(initialScene: scene),
      ]),
    );

Widget _trainerSectionV(BuildContext context, _Tr state, int scene) => _card(
    context,
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _trainerRow(context, state),
      if (state != _Tr.connected) _whyVisual(context, scene),
    ]));

/// Compact controller card: contour on the left, name + status on the right.
Widget _contourCompact(BuildContext context, BaseDevice device) {
  final size = 34 / Theme.of(context).scaling;
  return _card(context, Padding(
    padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
    child: Row(children: [
      SizedBox(width: 120, height: 96, child: ControllerCanvas(
        layout: device.controllerLayout!,
        availableButtons: device.availableButtons,
        buttonSize: size,
        buttonBuilder: (btn) => AnimatedButtonWidget(
          key: ValueKey(btn.name), button: btn, pressGeneration: 0,
          keymap: core.actionHandler.supportedApp?.keymap, device: device, size: size, onUpdate: () {}),
      )),
      const Gap(12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(device.displayName(context)).small.semiBold,
        const Gap(2),
        const BkStatusDot(label: 'Connected'),
        const Gap(6),
        Text('Press a button — it lights up here.').xSmall.muted,
      ])),
    ]),
  ));
}

// ── Flat VS scenes: drawn straight on the trainer card, one height, no nested boxes ──
const _sceneH = 120.0;

class _ShiftPainter extends CustomPainter {
  _ShiftPainter(this.grey, this.accent, this.grid);
  final Color grey, accent, grid;
  @override
  void paint(Canvas canvas, Size size) {
    final base = size.height - 6, top = 8.0;
    final g = Paint()..color = grid..strokeWidth = 1;
    canvas.drawLine(Offset(0, base + 4), Offset(size.width, base + 4), g);
    // press marker
    final px = size.width * 0.16;
    for (var y = top; y < base + 4; y += 6) {
      canvas.drawLine(Offset(px, y), Offset(px, y + 3), g..strokeWidth = 1.2);
    }
    Path curve(double start, double end) {
      final p = Path()..moveTo(0, base);
      p.lineTo(size.width * start, base);
      p.cubicTo(size.width * (start + (end - start) * .5), base, size.width * (start + (end - start) * .5), top,
          size.width * end, top);
      p.lineTo(size.width, top);
      return p;
    }
    canvas.drawPath(curve(.52, .74), Paint()..color = grey..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    canvas.drawPath(curve(.2, .36), Paint()..color = accent..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _sceneShift(BuildContext context, String app) {
  final cs = Theme.of(context).colorScheme;
  final accent = onboardingAccent(context);
  Widget key(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 3, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const Gap(6),
        Text(t).xSmall.semiBold,
      ]);
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [key(accent, 'BikeControl'), const Gap(14), key(cs.mutedForeground.withValues(alpha: .6), app)]),
    const Gap(8),
    Expanded(child: LayoutBuilder(builder: (context, box) => Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(bottom: 18, child: CustomPaint(painter: _ShiftPainter(cs.mutedForeground.withValues(alpha: .45), accent, cs.border))),
      Positioned(left: box.maxWidth * 0.16 - 6, bottom: 0, child: Row(children: [
        Icon(LucideIcons.arrowUp, size: 11, color: cs.mutedForeground),
        const Gap(3),
        Text('you shift').xSmall.muted,
      ])),
    ]))),
  ]);
}

Widget _sceneRatios(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final accent = onboardingAccent(context);
  final presets = gearRatioPresets(context, 24);
  final r = presets.first.values;
  final mn = r.reduce((a, b) => a < b ? a : b), mx = r.reduce((a, b) => a > b ? a : b);
  return Column(children: [
    Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < r.length; i++) ...[
        if (i > 0) const Gap(3),
        Expanded(child: FractionallySizedBox(
          heightFactor: 0.18 + 0.82 * (r[i] - mn) / (mx - mn),
          child: Container(decoration: BoxDecoration(
            color: i == 7 ? accent : Color.lerp(cs.border, cs.foreground, i / (r.length - 1)),
            borderRadius: BorderRadius.circular(2))),
        )),
      ],
    ])),
    const Gap(10),
    Row(children: [
      for (var i = 0; i < presets.length; i++) ...[
        if (i > 0) const Gap(6),
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: i == 0 ? accent : cs.muted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: i == 0 ? onboardingOnAccent(context) : cs.mutedForeground, fontWeight: FontWeight.w600),
            child: Text(presets[i].label, maxLines: 1, overflow: TextOverflow.ellipsis).xSmall),
        )),
      ],
    ]),
  ]);
}

Widget _sceneFront(BuildContext context) => Center(child: DrivetrainView(
      gear: 6, gearCount: 12, frontShift: true, largeRingActive: false,
      smallChainringTeeth: ShiftingConfig.smallChainringDefault,
      largeChainringTeeth: ShiftingConfig.largeChainringDefault,
      moving: false, cadence: 85, showGear: false, framed: false,
    ));

Widget _sceneMore(BuildContext context) {
  const items = ['Shifts at the trainer', 'Bluetooth → Wi-Fi', 'Every controller', '1 to 30 gears', 'SIM & ERG', 'Setting profiles'];
  return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    for (var row = 0; row < 3; row++) ...[
      if (row > 0) const Gap(12),
      Row(children: [
        for (var col = 0; col < 2; col++)
          Expanded(child: Row(children: [
            Icon(LucideIcons.check, size: 15, color: onboardingAccent(context)),
            const Gap(8),
            Flexible(child: Text(items[row * 2 + col]).xSmall.semiBold),
          ])),
      ]),
    ],
  ]);
}

Widget _flatStage(BuildContext context, int scene) {
  final cs = Theme.of(context).colorScheme;
  const captions = [
    ('Shifts sooner', 'The gear changes right at your trainer.'),
    ('Your gearing, your way', 'Pick a preset or set every gear.'),
    ('Virtual front derailleur', 'A big and a small ring, like on the road.'),
    ('And there\'s more', 'All in one place, in any app.'),
  ];
  return Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
    decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.border))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: _sceneH, child: switch (scene) {
        0 => _sceneShift(context, 'MyWhoosh'),
        1 => _sceneRatios(context),
        2 => _sceneFront(context),
        _ => _sceneMore(context),
      }),
      const Gap(12),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(captions[scene].$1).small.semiBold,
          Text(captions[scene].$2).xSmall.muted,
        ])),
        const Gap(10),
        Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const Gap(5),
            Container(width: i == scene ? 16 : 6, height: 6, decoration: BoxDecoration(
              color: i == scene ? onboardingAccent(context) : cs.border, borderRadius: BorderRadius.circular(3))),
          ],
        ])),
      ]),
    ]),
  );
}

Widget _trainerSectionFlat(BuildContext context, _Tr state, int scene) => _card(
    context,
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _trainerRow(context, state),
      if (state != _Tr.connected) _flatStage(context, scene),
    ]));

Future<void> main() async {
  await ensureSnapshotHarness();

  final click = ZwiftClick(BleDevice(deviceId: 'click-snap', name: 'Zwift Click'))..isConnected = true;

  Future<void> shot(WidgetTester tester, String name, Widget Function(BuildContext) b, {bool settle = false}) =>
      captureWidget(tester, name: name, width: _w, height: _h, outputDir: _out, settle: settle, pixelRatio: 2,
          padding: EdgeInsets.zero, builder: b);

  // ═══════════════ CURRENT (real widgets in the real shell) ═══════════════
  Widget cur(BuildContext c, OnboardingStep step, Widget body, List<Widget> footer) => onboardingShell(
        c,
        step: step,
        body: body,
        footerActions: footer,
        onBack: step == OnboardingStep.app || step == OnboardingStep.done ? null : () {},
        onHelp: () {},
        onClose: () {},
        onSelectStep: (_) {},
        stepValues: {
          if (step.index > 0) OnboardingStep.app: 'MyWhoosh',
          if (step.index > 1) OnboardingStep.where: 'Other Device',
        },
      );
  Widget pill(String t, {bool enabled = true}) =>
      PrimaryButton(alignment: Alignment.center, onPressed: enabled ? () {} : null, child: Text(t));
  Widget ghost(String t) => GhostButton(alignment: Alignment.center, onPressed: () {}, child: Text(t));

  testWidgets('cur0 welcome', (t) async {
    await shot(t, 'cur0_welcome', (c) => OnboardingWelcome(onStart: () {}, onLater: () {}), settle: true);
  });
  testWidgets('cur1 app', (t) async {
    await shot(t, 'cur1_app', (c) => cur(c, OnboardingStep.app,
        onboardingAppBody(c, selected: null, onSelect: (_) {}), [pill('Pick an app to continue', enabled: false)]));
  });
  testWidgets('cur2 where', (t) async {
    await shot(t, 'cur2_where', (c) => cur(c, OnboardingStep.where,
        onboardingWhereBody(c, app: MyWhoosh(), selected: Target.otherDevice, onSelect: (_) {}), [pill('Continue')]));
  });
  testWidgets('cur3 controller', (t) async {
    await shot(t, 'cur3_controller', (c) => cur(c, OnboardingStep.controller,
        onboardingControllerBody(c, phase: ControllerPhase.list, devices: [click], appName: 'MyWhoosh'),
        [pill('Continue')]));
  });
  testWidgets('cur4 vs', (t) async {
    await shot(t, 'cur4_vs', (c) => cur(c, OnboardingStep.virtualShifting,
        onboardingTrainerBody(c, app: MyWhoosh(), trainers: const [], onPick: (_) {}),
        [ghost('Let MyWhoosh handle virtual shifting')]));
  });
  testWidgets('cur5 connection', (t) async {
    await shot(t, 'cur5_connection', (c) => cur(c, OnboardingStep.connection,
        onboardingConnectionBody(c, app: MyWhoosh(), target: Target.otherDevice, hasTrainer: true,
            trainerName: 'KICKR CORE', onUpdate: () {}),
        [pill('Finish setup')]));
  });
  testWidgets('cur6 done', (t) async {
    await shot(t, 'cur6_done', (c) => cur(c, OnboardingStep.done,
        onboardingDoneBody(c, app: MyWhoosh(), controllerName: 'Zwift Click', trainerName: 'KICKR CORE',
            appConnected: true, trainerAppConnected: false, reduceMotion: true, showTestMode: true),
        [pill('Start riding'), ghost('See plan options')]));
  });

  // ═══════════════ A — "TRIM": same flow, ~half the words ═══════════════
  testWidgets('A0 welcome', (t) async {
    await shot(t, 'a0_welcome', (c) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Spacer(flex: 2),
            Image.asset('icon.png', width: 64, height: 64),
            const Gap(22),
            Text("Let's get you set up").x3Large.semiBold,
            const Gap(10),
            Text('About 2 minutes. You need your controller and your trainer app.').small.muted,
            const Spacer(flex: 3),
            BkPillButton(onPressed: () {}, child: const Text("Let's go")),
            const Gap(4),
            SizedBox(height: 44, child: Center(child: Text('Later').small.muted)),
          ]),
        ));
  });
  testWidgets('A1 app', (t) async {
    await shot(t, 'a1_app', (c) => protoShell(c, step: 0, total: 5,
        primary: 'Continue with MyWhoosh',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Which app do you ride with?'),
          _topApps(c, selected: 'MyWhoosh'),
        ])));
  });
  testWidgets('A2 where', (t) async {
    await shot(t, 'a2_where', (c) => protoShell(c, step: 1, total: 5, primary: 'Continue',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Where do you run MyWhoosh?'),
          _choiceRow(c, LucideIcons.smartphone, 'On this phone', 'Same device as BikeControl'),
          _choiceRow(c, LucideIcons.monitor, 'On another device', 'PC, Mac, tablet or Apple TV', selected: true),
        ])));
  });
  testWidgets('A3 controller', (t) async {
    await shot(t, 'a3_controller', (c) => protoShell(c, step: 2, total: 5, primary: 'Continue',
        body: onboardingControllerBody(c, phase: ControllerPhase.list, devices: [click], appName: 'MyWhoosh')));
  });
  testWidgets('A4 trainer', (t) async {
    await shot(t, 'a4_trainer', (c) => protoShell(c, step: 3, total: 5,
        primary: 'Connect KICKR CORE', secondary: 'Skip — MyWhoosh does the shifting',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Expanded(child: OnboardingHeadline('Got a smart trainer?')),
            const Gap(10),
            const Padding(padding: EdgeInsets.only(top: 4), child: ProBadge()),
          ]),
          const Gap(6),
          Text('BikeControl can do the shifting itself: faster gears, a front derailleur, your own ratios.').small.muted,
          const Gap(18),
          _label(c, 'Found nearby'),
          _deviceRow(c, LucideIcons.bluetooth, 'KICKR CORE 1EB7', sub: 'Bluetooth',
              trailing: Icon(LucideIcons.circleCheck, size: 20, color: onboardingAccent(c))),
          const Gap(12),
          Button.ghost(
            onPressed: () {},
            child: Row(children: [
              const Icon(LucideIcons.circlePlay, size: 15),
              const Gap(8),
              const Text('See how it works').small,
            ]),
          ),
        ])));
  });
  testWidgets('A5 connect', (t) async {
    await shot(t, 'a5_connect', (c) => protoShell(c, step: 4, total: 5,
        primary: 'Waiting for MyWhoosh…', primaryEnabled: false, secondary: 'Other ways to connect',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Now open MyWhoosh', 'BikeControl is already visible on your Wi-Fi.'),
          OnboardingAppGuideCard(app: MyWhoosh()),
          const Gap(12),
          _card(c, Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(LucideIcons.bike, size: 18, color: onboardingAccent(c)),
              const Gap(10),
              Expanded(child: Text.rich(TextSpan(children: [
                const TextSpan(text: 'As your trainer, pick '),
                TextSpan(text: 'KICKR CORE - BikeControl', style: const TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: ', not KICKR CORE.'),
              ])).small),
            ]),
          )),
        ])));
  });
  testWidgets('A6 done', (t) async {
    await shot(t, 'a6_done', (c) => protoShell(c, step: 4, total: 5, primary: 'Start riding',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Gap(24),
          Center(child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: BkStatusColors.of(c).success),
            child: Icon(LucideIcons.check, size: 38, color: BkStatusColors.of(c).successForeground),
          )),
          const Gap(18),
          const OnboardingHeadline("You're ready to ride", textAlign: TextAlign.center),
          const Gap(6),
          Center(child: Text('Press a button on your Zwift Click — MyWhoosh will shift.', textAlign: TextAlign.center).small.muted),
          const Gap(20),
          _card(c, Column(children: [
            _checkRow(c, LucideIcons.gamepad2, 'Zwift Click', 'Connected', ok: true, first: true),
            _checkRow(c, LucideIcons.bike, 'KICKR CORE', 'Virtual shifting', ok: true),
            _checkRow(c, LucideIcons.monitor, 'MyWhoosh', 'Connected', ok: true),
          ])),
          const Gap(14),
          Center(child: Text('Free trial: 30 min of virtual shifting a day.').xSmall.muted),
        ])));
  });

  // ═══════════════ B — "3 STEPS": merge screens ═══════════════
  testWidgets('B1 setup', (t) async {
    await shot(t, 'b1_setup', (c) => protoShell(c, step: 0, total: 3, primary: 'Continue',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Image.asset('icon.png', width: 28, height: 28),
            const Gap(10),
            const Text('BikeControl').semiBold,
          ]),
          const Gap(16),
          _title('Which app do you ride with?'),
          _topApps(c, selected: 'MyWhoosh'),
          const Gap(20),
          _label(c, 'MyWhoosh runs on'),
          _segmented(c, [(LucideIcons.smartphone, 'This phone'), (LucideIcons.monitor, 'Another device')], 1),
        ])));
  });
  testWidgets('B2 gear', (t) async {
    await shot(t, 'b2_gear', (c) => protoShell(c, step: 1, total: 3, primary: 'Continue',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Wake up your gear', 'Press a button on your controller. Pedal once to wake the trainer.'),
          _label(c, 'Controller'),
          onboardingDeviceRow(c, click),
          const Gap(12),
          _label(c, 'Smart trainer', trailing: Text('optional').xSmall.muted),
          _card(c, Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                const BkIconTile(icon: LucideIcons.bike),
                const Gap(12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('KICKR CORE 1EB7').small.semiBold,
                  const Text('Bluetooth').xSmall.muted,
                ])),
                BkStatusDot(label: 'Connected'),
              ]),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(c).colorScheme.border))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Text('BikeControl shifting').small.semiBold, const Gap(8), const ProBadge()]),
                  const Text('Faster gears and a front derailleur. Off = MyWhoosh shifts.').xSmall.muted,
                ])),
                const Gap(10),
                Switch(value: true, onChanged: (_) {}),
              ]),
            ),
          ])),
        ])));
  });
  testWidgets('B3 link waiting', (t) async {
    await shot(t, 'b3_link_waiting', (c) => protoShell(c, step: 2, total: 3,
        primary: 'Waiting for MyWhoosh…', primaryEnabled: false, secondary: 'Finish later',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Open MyWhoosh'),
          _card(c, Column(children: [
            _checkRow(c, LucideIcons.gamepad2, 'Zwift Click', 'Connected', ok: true, first: true),
            _checkRow(c, LucideIcons.bike, 'KICKR CORE', 'Ready', ok: true),
            _checkRow(c, LucideIcons.monitor, 'MyWhoosh', 'Waiting…', ok: false),
          ])),
          const Gap(14),
          OnboardingAppGuideCard(app: MyWhoosh()),
        ])));
  });
  testWidgets('B3 link ready', (t) async {
    await shot(t, 'b3_link_ready', (c) => protoShell(c, step: 2, total: 3, primary: 'Start riding',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title("You're ready to ride", 'Press a button — MyWhoosh shifts.'),
          _card(c, Column(children: [
            _checkRow(c, LucideIcons.gamepad2, 'Zwift Click', 'Connected', ok: true, first: true),
            _checkRow(c, LucideIcons.bike, 'KICKR CORE', 'Virtual shifting', ok: true),
            _checkRow(c, LucideIcons.monitor, 'MyWhoosh', 'Connected', ok: true),
          ])),
          const Gap(14),
          Center(child: Text('Free trial: 30 min of virtual shifting a day.').xSmall.muted),
        ])));
  });

  // ═══════════════ B2 variants: contour + VS pitch ═══════════════
  Widget b2(BuildContext c, {required bool on, Widget? explainer, Widget? below}) => protoShell(c, step: 1, total: 3,
      primary: on ? 'Continue' : 'Continue without',
      secondary: null,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Wake up your gear', 'Press a button on your controller. Pedal once to wake the trainer.'),
        _label(c, 'Controller'),
        _contour(c, click),
        const Gap(16),
        _label(c, 'Smart trainer', trailing: Text('optional').xSmall.muted),
        _trainerCard(c, on: on, explainer: explainer),
        if (below != null) ...[const Gap(14), below],
      ]));
  for (final (h, suffix) in const [(_h, ''), (1120.0, '_full')]) {
    Future<void> shotH(WidgetTester tester, String name, Widget Function(BuildContext) b) =>
        captureWidget(tester, name: '$name$suffix', width: _w, height: h, outputDir: _out, settle: false, pixelRatio: 2,
            padding: EdgeInsets.zero, builder: b);
    testWidgets('B2v1 benefits $suffix', (t) async {
      await shotH(t, 'b2v1_benefits', (c) => b2(c, on: true, explainer: _pitchBenefits(c)));
    });
    testWidgets('B2v2 curve $suffix', (t) async {
      await shotH(t, 'b2v2_curve', (c) => b2(c, on: true, explainer: _pitchCurve(c)));
    });
    testWidgets('B2v3 stage off $suffix', (t) async {
      await shotH(t, 'b2v3_stage', (c) => b2(c, on: false, below: const VirtualShiftingStage(initialScene: 2)));
    });
  }

  // ═══════════════ C: trainer through BikeControl is the default ═══════════════
  Widget c2(BuildContext c, _Tr state) => protoShell(c, step: 1, total: 3,
      primary: switch (state) {
        _Tr.searching => 'Looking for your trainer…',
        _Tr.found => 'Connect KICKR CORE',
        _Tr.connected => 'Continue',
      },
      primaryEnabled: state != _Tr.searching,
      secondary: state == _Tr.connected ? null : 'Skip — MyWhoosh shifts instead',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Connect your gear', 'Press a button on your controller and pedal once to wake your trainer.'),
        _label(c, 'Controller'),
        _contour(c, click, maxHeight: 150),
        const Gap(16),
        _label(c, 'Smart trainer', trailing: const ProBadge()),
        _trainerSection(c, state),
        const Gap(10),
        Center(child: Text('Free trial: 30 min of virtual shifting a day.').xSmall.muted),
      ]));
  for (final (h, suffix) in const [(_h, ''), (1000.0, '_full')]) {
    Future<void> shotH(WidgetTester tester, String name, Widget Function(BuildContext) b) =>
        captureWidget(tester, name: '$name$suffix', width: _w, height: h, outputDir: _out, settle: false, pixelRatio: 2,
            padding: EdgeInsets.zero, builder: b);
    testWidgets('C2 searching $suffix', (t) async => shotH(t, 'c2_searching', (c) => c2(c, _Tr.searching)));
    testWidgets('C2 found $suffix', (t) async => shotH(t, 'c2_found', (c) => c2(c, _Tr.found)));
    testWidgets('C2 connected $suffix', (t) async => shotH(t, 'c2_connected', (c) => c2(c, _Tr.connected)));
  }

  // ═══════════════ C visual: animated scenes instead of text benefits ═══════════════
  Widget c3(BuildContext c, _Tr state, int scene) => protoShell(c, step: 1, total: 3,
      primary: switch (state) {
        _Tr.searching => 'Looking for your trainer…',
        _Tr.found => 'Connect KICKR CORE',
        _Tr.connected => 'Continue',
      },
      primaryEnabled: state != _Tr.searching,
      secondary: state == _Tr.connected ? null : 'Skip — MyWhoosh shifts instead',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Connect your gear', 'Press a button on your controller and pedal once to wake your trainer.'),
        _label(c, 'Controller'),
        _contourCompact(c, click),
        const Gap(16),
        _label(c, 'Smart trainer', trailing: const ProBadge()),
        _trainerSectionV(c, state, scene),
        const Gap(10),
        Center(child: Text('Free trial: 30 min of virtual shifting a day.').xSmall.muted),
      ]));
  for (final (h, suffix) in const [(_h, ''), (1060.0, '_full')]) {
    Future<void> shotH(WidgetTester tester, String name, Widget Function(BuildContext) b) =>
        captureWidget(tester, name: '$name$suffix', width: _w, height: h, outputDir: _out, settle: false, pixelRatio: 2,
            padding: EdgeInsets.zero, builder: b);
    testWidgets('C3 searching $suffix', (t) async => shotH(t, 'c3_searching', (c) => c3(c, _Tr.searching, 0)));
    for (var sc = 0; sc < 4; sc++) {
      testWidgets('C3 found s$sc $suffix', (t) async => shotH(t, 'c3_found_s$sc', (c) => c3(c, _Tr.found, sc)));
    }
    testWidgets('C3 connected $suffix', (t) async => shotH(t, 'c3_connected', (c) => c3(c, _Tr.connected, 0)));
  }

  // ═══════════════ C flat: scenes drawn on the card ═══════════════
  Widget c4(BuildContext c, _Tr state, int scene) => protoShell(c, step: 1, total: 3,
      primary: switch (state) {
        _Tr.searching => 'Looking for your trainer…',
        _Tr.found => 'Connect KICKR CORE',
        _Tr.connected => 'Continue',
      },
      primaryEnabled: state != _Tr.searching,
      secondary: state == _Tr.connected ? null : 'Skip — MyWhoosh shifts instead',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Connect your gear', 'Press a button, then pedal to wake your trainer.'),
        _label(c, 'Controller'),
        _contourCompact(c, click),
        const Gap(16),
        _label(c, 'Smart trainer', trailing: const ProBadge()),
        _trainerSectionFlat(c, state, scene),
        const Gap(10),
        Center(child: Text('Free trial: 30 min of virtual shifting a day.').xSmall.muted),
      ]));
  testWidgets('C4 searching', (t) async => shot(t, 'c4_searching', (c) => c4(c, _Tr.searching, 0)));
  for (var sc = 0; sc < 4; sc++) {
    testWidgets('C4 found s$sc', (t) async => shot(t, 'c4_found_s$sc', (c) => c4(c, _Tr.found, sc)));
  }
  testWidgets('C4 connected', (t) async => shot(t, 'c4_connected', (c) => c4(c, _Tr.connected, 0)));
}
