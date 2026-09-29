import 'package:flutter/widgets.dart';

/// The pixel width to decode a network image at so it fills [logicalWidth]
/// sharply on this screen — and no wider. Without it a thumbnail keeps the
/// full-size download decoded in memory. Null when the width is unbounded.
int? decodeWidthFor(BuildContext context, double logicalWidth) =>
    logicalWidth.isFinite ? (logicalWidth * MediaQuery.devicePixelRatioOf(context)).ceil() : null;
