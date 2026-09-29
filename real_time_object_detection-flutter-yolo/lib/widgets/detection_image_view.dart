import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/bbox_utils.dart';
import '../utils/detector.dart';

/// Draws [image] fitted inside the available space, with detection boxes on
/// top.
///
/// The image is drawn at an EXPLICIT size (never at whatever size a widget
/// like Image.file happens to pick - Image.file doesn't upscale small
/// images, which used to make boxes drift on small pictures), and the boxes
/// are scaled by exactly the same factor, so they always line up.
class DetectionImageView extends StatelessWidget {
  final ui.Image image;
  final DetectionResult result;

  const DetectionImageView({
    super.key,
    required this.image,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iw = image.width.toDouble();
        final ih = image.height.toDouble();
        final scale = min(constraints.maxWidth / iw, constraints.maxHeight / ih);

        return Center(
          child: SizedBox(
            width: iw * scale,
            height: ih * scale,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: RawImage(
                    image: image,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                ...buildBboxWidgets(result, scale),
              ],
            ),
          ),
        );
      },
    );
  }
}
