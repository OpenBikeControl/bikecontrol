/// The home screen's setup chain, as pure data.
///
/// The home screen is the chain: one card per link, each carrying the same
/// status light ("Ampel") and the same tick-off checklist. Everything the top
/// banner says is *derived* from the links below it — see [deriveBanner] — so
/// the banner can never contradict the cards.
///
/// This file deliberately imports nothing: no Flutter, no `core`, no
/// localization. Steps carry [SetupStepId]s rather than sentences, and the
/// widget layer resolves those to translated text. That keeps "which step is
/// done or pending" exhaustively unit-testable without BLE, widgets or a
/// loaded locale.
library;

/// The shared status vocabulary, used identically by the dot on a card's tile,
/// the status line under its title, and the banner at the top of the screen.
enum LinkStatus {
  /// Green. This link is doing its job.
  ready,

  /// Amber (pulsing). Set up, but not working right now — and we expect it to
  /// come back on its own or with one small action.
  attention,

  /// Red. It was working in this session and broke.
  problem,

  /// Grey. Never set up.
  off,
}

/// Which link of the chain a card represents. The chain follows the signal
/// path: your buttons, then the gears BikeControl computes from them, then the
/// app that receives them.
///
/// [sensors] takes the trainer's slot in sensors-only mode, where there is no
/// smart trainer to bridge — only sensor readings to broadcast.
enum ChainLinkKey { controller, trainer, sensors, app }

/// A checklist step. Identified by id, not by wording — the labels live in the
/// widget layer so they can be translated, and so tests never assert on text.
enum SetupStepId {
  controllerBluetoothReady,
  controllerPaired,
  controllerButtonsMapped,
  controllerInRange,
  controllerUnlocked,
  controllerSramSetup,
  controllerSramRestore,
  controllerClickV2Setup,
  controllerClickV2KeepAwake,
  trainerPaired,
  trainerAppBridged,
  trainerGearOverlay,
  appSelected,
  appConnectionMethod,
  appLocalNetwork,
  appConnected,
  appLocalControl,
}

/// What the banner's action button does. The banner never invents a target: it
/// always points at a link that is actually outstanding.
enum ChainBannerKind {
  /// Nothing is outstanding.
  ready,

  /// Something that was working has broken — jump to the fix.
  broken,

  /// Setup is incomplete — jump to the next thing to do.
  pending,
}

/// Which wording a step reads out while it is pending, when that depends on
/// what the *other* links are doing. The step's identity is still its
/// [SetupStepId]; the variant only picks the sentence.
enum SetupStepVariant {
  /// The step's ordinary copy.
  standard,

  /// [SetupStepId.appConnected] while the trainer app already holds the
  /// bridge. The app is reading the trainer through BikeControl, so "waiting
  /// for the app to connect" is only half true — the trainer half of its
  /// pairing screen is done. What is missing is the controller tile, a second
  /// pairing on the same screen, and the most common support case is a rider
  /// who never learned there were two.
  controllerLinkMissing,
}

/// One line of a card's checklist.
class SetupStep {
  const SetupStep({
    required this.id,
    required this.done,
    this.hintArg,
    this.uncertain = false,
    this.optional = false,
    this.secondaryHintArg,
    this.variant = SetupStepVariant.standard,
  });

  final SetupStepId id;
  final bool done;

  /// Whether this step is an offer rather than work. An optional step sits in
  /// the checklist like any other and can be actioned like any other, but it
  /// does not colour its card, does not count towards the banner's steps, and
  /// never stops a rider being ready to ride.
  ///
  /// Today that is the SRAM restore, the Click V2 keep-awake and Local
  /// control: things a rider may genuinely never want. It was introduced for
  /// the gear overlay, and the gear overlay is exactly where it failed —
  /// riders walked past the optional line as they had walked past the toast
  /// before it, and "why does MyWhoosh show the wrong gear?" stayed the most
  /// common support question. That step is now required until the rider has
  /// answered it once (turned the overlay on, or "not now"); only afterwards,
  /// with the overlay switched off again, is it optional in this sense. See
  /// [SetupStepId.trainerGearOverlay] in the chain builder.
  final bool optional;

  /// Whether [done] is a best guess rather than a fact. Only
  /// [SetupStepId.controllerUnlocked] uses it: BikeControl cannot read a Click
  /// V2's lock state back, so after an unlock it knows when the 24 hours ought
  /// to run out but not whether the unlock actually took — and the step has to
  /// say "likely" instead of claiming more than it knows.
  final bool uncertain;

  /// Optional runtime detail folded into the step's hint, e.g. the gear count
  /// and ratio on [SetupStepId.trainerGears]. Kept as raw data so the
  /// localized sentence is assembled in the widget layer.
  final String? hintArg;

  /// A second runtime detail for hints that name two things. Only
  /// [SetupStepId.trainerAppBridged] uses it: [hintArg] is the bridge entry
  /// to pick, this is the trainer's own name — the entry right beside it in
  /// the trainer app's list that riders pick instead, bypassing BikeControl.
  /// Null when the name isn't known, and the hint then names only the bridge.
  final String? secondaryHintArg;

  /// See [SetupStepVariant].
  final SetupStepVariant variant;

  SetupStep copyWith({bool? done, String? hintArg, bool? uncertain, bool? optional}) => SetupStep(
    id: id,
    done: done ?? this.done,
    hintArg: hintArg ?? this.hintArg,
    uncertain: uncertain ?? this.uncertain,
    optional: optional ?? this.optional,
    secondaryHintArg: secondaryHintArg,
    variant: variant,
  );

  @override
  String toString() => 'SetupStep(${id.name}, done: $done)';
}

/// One card in the chain.
/// Whether the app link's "Show me how" should open Trainer Connections
/// rather than the trainer-app guide.
///
/// While a connection method still has to be switched on, the guide answers
/// the step after this one — what to do inside the trainer app — and leaves
/// the rider reading pairing instructions for a bridge that isn't running.
/// The button label follows the same rule, so the two cannot drift.
bool appLinkOpensConnectionSettings(ChainLink link) => link.activeStep?.id == SetupStepId.appConnectionMethod;

/// Whether the app card's status line should name the outstanding step instead
/// of saying it is waiting for the app.
///
/// "Waiting for MyWhoosh" is only true once everything on this side is done.
/// While a permission is missing or no method is switched on, the app is never
/// going to connect however long the rider waits — and saying otherwise sends
/// them into the trainer app hunting for a problem that is over here.
bool appStatusFollowsActiveStep(ChainLink link) {
  final active = link.activeStep;
  return active != null && !active.optional && active.id != SetupStepId.appConnected;
}

class ChainLink {
  const ChainLink({
    required this.key,
    required this.id,
    required this.status,
    required this.title,
    required this.steps,
    this.optional = false,
    this.subtitleArg,
    this.deviceId,
    this.dismissible = false,
  });

  final ChainLinkKey key;

  /// Stable identity for this card, unique within a chain. The controller link
  /// uses the device's `uniqueId` so several controllers can coexist; the
  /// trainer and app links use their key's name.
  final String id;

  final LinkStatus status;

  /// Already-resolved display name — a device name like "Zwift Click V2" or a
  /// trainer app name. Not a translatable sentence, so it lives here.
  final String title;

  final List<SetupStep> steps;

  /// An optional link at rest is not a blocker: the rider can ride without a
  /// smart trainer, so an [LinkStatus.off] trainer must not stop the banner
  /// saying "Ready to ride".
  final bool optional;

  /// Runtime detail for the status line, e.g. live metrics or the connection
  /// method. Raw data; the widget assembles the sentence.
  final String? subtitleArg;

  /// The underlying device, when this link stands for one.
  final String? deviceId;

  /// Whether this card can be swiped away. Only ever true for a device that is
  /// remembered but not currently connected — a live device must not be
  /// dismissible, or a stray swipe drops a working controller off the screen.
  final bool dismissible;

  /// Whether this link stops the rider being ready.
  bool get isBlocking {
    if (status == LinkStatus.ready) return false;
    if (optional && status == LinkStatus.off) return false;
    return true;
  }

  /// The steps that are actually required — an optional one is an offer, and
  /// counting it would have the banner announce work a rider may ignore
  /// forever.
  List<SetupStep> get requiredSteps => steps.where((s) => !s.optional).toList();

  int get doneSteps => requiredSteps.where((s) => s.done).length;

  int get remainingSteps => requiredSteps.length - doneSteps;

  /// The first unfinished step: the one thing to do next on this card, and the
  /// only step that shows an instructions affordance. Null when the checklist
  /// is complete or empty.
  int? get activeStepIndex {
    final index = steps.indexWhere((s) => !s.done);
    return index == -1 ? null : index;
  }

  SetupStep? get activeStep {
    final index = activeStepIndex;
    return index == null ? null : steps[index];
  }

  /// The steps still to do. A finished step has served its purpose the moment
  /// it ticks: it is the outstanding work a rider needs on screen, not a
  /// receipt for the work already behind them.
  List<SetupStep> get pendingSteps => steps.where((s) => !s.done).toList();

  ChainLink copyWith({LinkStatus? status, List<SetupStep>? steps, String? subtitleArg, bool? dismissible}) {
    return ChainLink(
      key: key,
      id: id,
      status: status ?? this.status,
      title: title,
      steps: steps ?? this.steps,
      optional: optional,
      subtitleArg: subtitleArg ?? this.subtitleArg,
      deviceId: deviceId,
      dismissible: dismissible ?? this.dismissible,
    );
  }

  @override
  String toString() => 'ChainLink($id, ${status.name}, $doneSteps/${requiredSteps.length})';
}

/// The one-glance answer at the top of the screen.
class ChainBanner {
  const ChainBanner({
    required this.kind,
    required this.status,
    required this.stepsLeft,
    this.targetLinkId,
    this.targetKey,
    this.outstandingKeys = const [],
    this.soleStep,
  });

  final ChainBannerKind kind;
  final LinkStatus status;

  /// Total unfinished steps across every blocking link. Zero when ready.
  final int stepsLeft;

  /// The link the action button jumps to, or null when there is no action.
  final String? targetLinkId;
  final ChainLinkKey? targetKey;

  /// The distinct link kinds still outstanding, in render order. Drives the
  /// banner's sub-copy ("Controller and MyWhoosh still need setting up").
  final List<ChainLinkKey> outstandingKeys;

  /// The one required step still outstanding across the whole chain, or null
  /// when there are none or several. With exactly one thing left the banner
  /// can speak to that step rather than to its card — "connect the
  /// controller tile" instead of "finish the Trainer app card", which sends
  /// a rider back to a screen they have already been on once.
  final SetupStep? soleStep;

  bool get hasAction => targetLinkId != null;

  @override
  String toString() => 'ChainBanner(${kind.name}, stepsLeft: $stepsLeft, target: $targetLinkId)';
}

/// Derives the banner from the links, in render order.
///
/// Order matters: a link that *broke* outranks one that was never finished,
/// because a red card is the thing the rider is staring at. Within each case
/// the first matching link in render order wins, so the banner's action always
/// lands on the topmost card that needs attention.
ChainBanner deriveBanner(List<ChainLink> links) {
  final outstanding = links.where((l) => l.isBlocking).toList();

  if (outstanding.isEmpty) {
    return const ChainBanner(kind: ChainBannerKind.ready, status: LinkStatus.ready, stepsLeft: 0);
  }

  final stepsLeft = outstanding.fold<int>(0, (sum, l) => sum + l.remainingSteps);
  final outstandingKeys = <ChainLinkKey>[];
  for (final link in outstanding) {
    if (!outstandingKeys.contains(link.key)) outstandingKeys.add(link.key);
  }
  // Required steps only, same as [stepsLeft]: an outstanding offer does not
  // stop the one real step from being the one real step.
  final remaining = [for (final link in outstanding) ...link.requiredSteps.where((s) => !s.done)];
  final soleStep = remaining.length == 1 ? remaining.single : null;

  final broken = outstanding.where((l) => l.status == LinkStatus.problem).toList();
  if (broken.isNotEmpty) {
    return ChainBanner(
      kind: ChainBannerKind.broken,
      status: LinkStatus.problem,
      stepsLeft: stepsLeft,
      targetLinkId: broken.first.id,
      targetKey: broken.first.key,
      outstandingKeys: outstandingKeys,
      soleStep: soleStep,
    );
  }

  return ChainBanner(
    kind: ChainBannerKind.pending,
    status: LinkStatus.attention,
    stepsLeft: stepsLeft,
    targetLinkId: outstanding.first.id,
    targetKey: outstanding.first.key,
    outstandingKeys: outstandingKeys,
    soleStep: soleStep,
  );
}
