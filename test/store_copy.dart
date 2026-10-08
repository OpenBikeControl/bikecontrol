// The marketing copy and brand styling the store boards are drawn with.
//
// Deliberately NOT in the app's ARB files. These are advertising claims, not
// app copy: they have their own review, their own lifecycle and their own
// constraint (see [kSceneHeadlineMaxChars]). Mixing them into the string table
// would put marketing claims in front of every translator working on button
// labels — and would make both harder to reason about.
//
// Kept in its own file rather than inside `screenshot_test.dart` so the board
// tests (`store_board_test.dart`) can read it without dragging in the whole app
// bootstrap that the screenshot suite needs.
import 'package:flutter/material.dart' show Color, HSLColor;

/// The scenes that make up the store listing, in the order they are shown in.
///
/// This IS the listing order — `scripts/prepare_store_screenshots.sh` numbers
/// the uploaded files `01_…`, `02_…` from the same sequence, and
/// `store_board_test.dart` asserts the two never drift. The hue ramp below
/// reads a scene's position out of this list, so it cannot disagree with the
/// order a shopper actually scrolls the boards in.
const List<String> kSceneOrder = <String>[
  'device',
  'devices',
  'virtualshifting-settings',
  'customization',
  'trainer',
  'companion',
];

/// The languages the boards are rendered in — one screenshot folder per
/// language, so the store listings get genuinely localized screenshots instead
/// of the English ones copied to every locale.
const List<String> kScreenshotLocales = <String>['en', 'de', 'es', 'fr', 'it', 'pl'];

/// The longest a headline may be before it stops fitting the board.
///
/// Measured against the narrowest board slot rather than guessed: the iPhone
/// canvas is 414 logical units wide, the headline strip is 86% of that, and the
/// type is `CustomFrame.titleFraction` of the width — which holds roughly 24
/// characters a line and three lines in the band. 56 leaves a line of headroom
/// for a translation that runs long.
///
/// Higher than the 52 the same board uses in BikeOtter, because that board
/// spends a fifth of its width on a per-scene mascot and this one has no art
/// column: the headline gets the whole strip.
///
/// `store_board_test.dart` enforces it, because the failure is invisible until
/// someone opens all 216 PNGs.
const int kSceneHeadlineMaxChars = 56;

/// The accent one phrase of every headline is painted in.
///
/// A light cyan out of the brand's own family (the gradient runs #0E74B7 →
/// #0E9297), lighter than both stops so it reads as emphasis on the darker end
/// of the board rather than as a second brand colour.
const Color kStoreAccentColor = Color(0xFF7DE3FF);

/// How far apart the two ends of the hue ramp sit, in degrees.
///
/// Scrolled past, six identical blue boards read as one image repeated; six
/// unrelated colours read as six apps. 24° is the middle: every board stays
/// recognisably this blue and the set still moves while you scroll it.
const double _hueSpread = 24;

/// Brand colours for the marketing board.
class StoreFrameStyle {
  const StoreFrameStyle({
    required this.gradientTop,
    required this.gradientBottom,
    this.titleColor = const Color(0xFFFFFFFF),
    this.accentColor = kStoreAccentColor,
  });

  final Color gradientTop;
  final Color gradientBottom;
  final Color titleColor;

  /// The colour one phrase of each headline is painted in.
  final Color accentColor;

  /// This style, rotated along the listing so the boards read as a series.
  ///
  /// The position comes from the scene's index in [kSceneOrder]; a scene that
  /// is not in it (the frameless website/blog shots, which carry no board at
  /// all) gets the unshifted style rather than an exception — the ramp is
  /// decoration.
  ///
  /// Only the two gradient stops move. The headline and its accent stay put:
  /// rotating those too would make the type a different colour on every board,
  /// which is the opposite of what a ramp is for.
  StoreFrameStyle forScene(String sceneId) {
    final order = kSceneOrder.indexOf(sceneId);
    if (order < 0) return this;
    final t = kSceneOrder.length == 1 ? 0.0 : order / (kSceneOrder.length - 1);
    final degrees = -_hueSpread / 2 + t * _hueSpread;
    return StoreFrameStyle(
      gradientTop: _rotateHue(gradientTop, degrees),
      gradientBottom: _rotateHue(gradientBottom, degrees),
      titleColor: titleColor,
      accentColor: accentColor,
    );
  }
}

/// The unshifted brand board: the app's dark-theme band pair, corner to corner.
///
/// Not the light pair (`BKColor.main` → `BKColor.mainEnd`): its teal end is
/// light enough that white type on it measured 3:1 and the accent 2:1. The
/// dark band is the same blue-to-teal, a step deeper, and carries the white
/// claim at 4.5:1 or better across the whole hue ramp.
const StoreFrameStyle kStoreBrandStyle = StoreFrameStyle(
  gradientTop: Color(0xFF0C5F96),
  gradientBottom: Color(0xFF0A5F63),
);

Color _rotateHue(Color c, double degrees) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withHue((hsl.hue + degrees) % 360).toColor();
}

/// Scene id -> language code -> headline. English is the source of truth.
///
/// Each one is what the rider gets, not what the screen is called: a shopper
/// scrolling past reads a claim, not a settings page. No other company's
/// product or app names — the boards name the trainer app generically, and so
/// does the copy. The French copy says "tu", like the app does.
const Map<String, Map<String, String>> kSceneHeadlines = <String, Map<String, String>>{
  'device': <String, String>{
    'en': 'Shift and steer from your handlebars',
    'de': 'Schalten und lenken direkt vom Lenker',
    'es': 'Cambia y gira desde el manillar',
    'fr': 'Passe les vitesses et dirige depuis ton guidon',
    'it': 'Cambia e sterza direttamente dal manubrio',
    'pl': 'Zmieniaj biegi i skręcaj prosto z kierownicy',
  },
  'devices': <String, String>{
    'en': 'Use the controllers you already own',
    'de': 'Nutze die Controller, die du schon hast',
    'es': 'Usa los mandos que ya tienes',
    'fr': 'Utilise les contrôleurs que tu as déjà',
    'it': 'Usa i controller che hai già',
    'pl': 'Używaj kontrolerów, które już masz',
  },
  'virtualshifting-settings': <String, String>{
    'en': 'Real gears on any smart trainer',
    'de': 'Echte Gänge auf jedem Smart-Trainer',
    'es': 'Marchas reales en cualquier rodillo inteligente',
    'fr': 'De vraies vitesses sur tout home-trainer connecté',
    'it': 'Marce vere su qualsiasi rullo smart',
    'pl': 'Prawdziwe biegi na każdym trenażerze smart',
  },
  'customization': <String, String>{
    'en': 'Every button does exactly what you want',
    'de': 'Jede Taste macht genau, was du willst',
    'es': 'Cada botón hace exactamente lo que quieres',
    'fr': 'Chaque bouton fait exactement ce que tu veux',
    'it': 'Ogni pulsante fa esattamente ciò che vuoi',
    'pl': 'Każdy przycisk robi dokładnie to, co chcesz',
  },
  'trainer': <String, String>{
    'en': 'Connect over Wi-Fi or on the same device',
    'de': 'Verbinde per WLAN oder auf demselben Gerät',
    'es': 'Conéctate por wifi o en el mismo dispositivo',
    'fr': 'Connecte-toi en Wi-Fi ou sur le même appareil',
    'it': 'Collegati via Wi-Fi o sullo stesso dispositivo',
    'pl': 'Połącz przez Wi-Fi lub na tym samym urządzeniu',
  },
  'companion': <String, String>{
    'en': 'Your phone becomes a remote for your ride',
    'de': 'Dein Handy wird zur Fernbedienung',
    'es': 'Tu móvil se convierte en un control remoto',
    'fr': 'Ton téléphone devient une télécommande',
    'it': 'Il tuo telefono diventa un telecomando',
    'pl': 'Twój telefon staje się pilotem',
  },
};

/// Scene id -> language code -> the run of the headline painted in
/// [StoreFrameStyle.accentColor].
///
/// The part of the claim a rider scanning the listing is looking for — "from
/// your handlebars", "you already own", "Real gears".
///
/// Per language, because these are substrings of the *translated* headline and
/// German does not put its noun where English does. A phrase that is off by one
/// character does not throw and does not warn — it silently renders that one
/// headline plain, which is the kind of miss nobody notices until the listing
/// is live. `store_board_test.dart` checks all 36.
const Map<String, Map<String, String>> kSceneAccents = <String, Map<String, String>>{
  'device': <String, String>{
    'en': 'your handlebars',
    'de': 'direkt vom Lenker',
    'es': 'desde el manillar',
    'fr': 'depuis ton guidon',
    'it': 'dal manubrio',
    'pl': 'prosto z kierownicy',
  },
  'devices': <String, String>{
    'en': 'you already own',
    'de': 'die du schon hast',
    'es': 'que ya tienes',
    'fr': 'que tu as déjà',
    'it': 'che hai già',
    'pl': 'które już masz',
  },
  'virtualshifting-settings': <String, String>{
    'en': 'Real gears',
    'de': 'Echte Gänge',
    'es': 'Marchas reales',
    'fr': 'De vraies vitesses',
    'it': 'Marce vere',
    'pl': 'Prawdziwe biegi',
  },
  'customization': <String, String>{
    'en': 'exactly what you want',
    'de': 'genau, was du willst',
    'es': 'exactamente lo que quieres',
    'fr': 'exactement ce que tu veux',
    'it': 'esattamente ciò che vuoi',
    'pl': 'dokładnie to, co chcesz',
  },
  'trainer': <String, String>{
    'en': 'Wi-Fi',
    'de': 'WLAN',
    'es': 'wifi',
    'fr': 'Wi-Fi',
    'it': 'Wi-Fi',
    'pl': 'Wi-Fi',
  },
  'companion': <String, String>{
    'en': 'a remote',
    'de': 'Fernbedienung',
    'es': 'control remoto',
    'fr': 'une télécommande',
    'it': 'un telecomando',
    'pl': 'pilotem',
  },
};

/// The headline for a scene in a language, falling back to English.
///
/// Throws for an unknown scene rather than returning a placeholder: a missing
/// headline means the scene list and this table have drifted, and a board
/// captured with an empty headline looks deliberate.
String sceneHeadline(String sceneId, String language) {
  final byLanguage = kSceneHeadlines[sceneId];
  if (byLanguage == null) {
    throw ArgumentError('no headlines for scene `$sceneId` — add it to kSceneHeadlines');
  }
  return byLanguage[language] ?? byLanguage['en']!;
}

/// The accented run of a scene's headline in a language, falling back to
/// English and then to none.
///
/// Unlike [sceneHeadline] this does not throw for an unknown scene: the accent
/// is a decoration on a claim, not the claim, and a board is still a correct
/// board without it.
String? sceneAccent(String sceneId, String language) {
  final byLanguage = kSceneAccents[sceneId];
  if (byLanguage == null) return null;
  return byLanguage[language] ?? byLanguage['en'];
}
