import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The pixel width to decode a network photo at so it's sharp in a box of
/// [width] x [height] logical pixels on this screen — and no bigger.
///
/// Uploads are up to 1600px wide; decoding one at full size for a 40px
/// avatar wastes memory and makes long lists stutter while scrolling. Uses
/// the larger side so `BoxFit.cover` crops stay sharp, and the screen width
/// for full-bleed images (`double.infinity`).
int decodeWidthFor(BuildContext context, double width, [double? height]) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final w = width.isFinite ? width : screenWidth;
  final h = height != null && height.isFinite ? height : 0.0;
  return (math.max(w, h) * MediaQuery.devicePixelRatioOf(context)).round();
}
