import 'package:flutter/widgets.dart';

/// Height of the main image/camera panel.
///
/// Phones in portrait get a compact panel so the controls and sliders stay
/// visible without a huge scroll; wider/taller screens (desktop, tablets)
/// get a larger one.
double outputPanelHeight(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  if (size.width < 600) {
    return (size.height * 0.36).clamp(220.0, 360.0).toDouble();
  }
  return (size.height * 0.52).clamp(320.0, 560.0).toDouble();
}
