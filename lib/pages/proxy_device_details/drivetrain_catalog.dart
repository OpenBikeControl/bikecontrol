/// The cranks and cassettes the "Like my bike" sheet offers in one tap.
/// Anything else is entered as custom teeth.
library;

class CranksetOption {
  /// Largest first; one ring for a 1×.
  final List<int> chainrings;

  const CranksetOption(this.chainrings);

  bool get isSingle => chainrings.length == 1;

  /// "50/34" or "1× 42".
  String get label => isSingle ? '1× ${chainrings.single}' : chainrings.join('/');
}

class CassetteOption {
  final String id;
  final String brand;
  final int speeds;

  /// Smallest first.
  final List<int> cogs;

  const CassetteOption(this.id, this.brand, this.speeds, this.cogs);

  /// "11-34".
  String get range => '${cogs.first}-${cogs.last}';

  /// "Shimano 11-34".
  String get label => '$brand $range';
}

const List<CranksetOption> cranksets = [
  CranksetOption([50, 34]),
  CranksetOption([52, 36]),
  CranksetOption([53, 39]),
  CranksetOption([48, 35]),
  CranksetOption([40]),
  CranksetOption([42]),
  CranksetOption([44]),
];

const List<CassetteOption> cassettes = [
  // 12-speed
  CassetteOption('shimano-12-11-28', 'Shimano', 12, [11, 12, 13, 14, 15, 16, 17, 19, 21, 23, 25, 28]),
  CassetteOption('shimano-12-11-30', 'Shimano', 12, [11, 12, 13, 14, 15, 16, 17, 19, 21, 24, 27, 30]),
  CassetteOption('shimano-12-11-34', 'Shimano', 12, [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30, 34]),
  CassetteOption('sram-12-10-28', 'SRAM', 12, [10, 11, 12, 13, 14, 15, 16, 17, 19, 21, 24, 28]),
  CassetteOption('sram-12-10-33', 'SRAM', 12, [10, 11, 12, 13, 14, 15, 17, 19, 21, 24, 28, 33]),
  CassetteOption('sram-12-10-36', 'SRAM', 12, [10, 11, 12, 13, 15, 17, 19, 21, 24, 28, 32, 36]),
  CassetteOption('sram-12-10-44', 'SRAM XPLR', 12, [10, 11, 13, 15, 17, 19, 21, 24, 28, 32, 38, 44]),
  CassetteOption('campagnolo-12-11-29', 'Campagnolo', 12, [11, 12, 13, 14, 15, 16, 17, 19, 21, 23, 26, 29]),
  CassetteOption('campagnolo-12-11-32', 'Campagnolo', 12, [11, 12, 13, 14, 15, 16, 17, 19, 22, 25, 28, 32]),
  // 11-speed
  CassetteOption('shimano-11-11-28', 'Shimano', 11, [11, 12, 13, 14, 15, 17, 19, 21, 23, 25, 28]),
  CassetteOption('shimano-11-11-30', 'Shimano', 11, [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30]),
  CassetteOption('shimano-11-11-32', 'Shimano', 11, [11, 12, 13, 14, 16, 18, 20, 22, 25, 28, 32]),
  CassetteOption('shimano-11-11-34', 'Shimano', 11, [11, 13, 15, 17, 19, 21, 23, 25, 27, 30, 34]),
  CassetteOption('campagnolo-11-11-29', 'Campagnolo', 11, [11, 12, 13, 14, 15, 17, 19, 21, 23, 26, 29]),
];
