import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dartcv4/dartcv.dart' as cv;
import 'package:flutter/widgets.dart' show WidgetsBinding;

/// Decodes compressed image bytes (jpg/png/...) into a [ui.Image], shrinking
/// it so its longest side is at most [maxSide].
///
/// The SAME returned image is used both for drawing on screen and for
/// running detection, so the picture and the boxes can never disagree about
/// size or orientation. The size cap also keeps huge phone photos from
/// exhausting memory and speeds up the RGBA -> Mat conversion.
Future<ui.Image> decodeUiImage(Uint8List bytes, {int maxSide = 1280}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  final decoded = frame.image;

  final w = decoded.width;
  final h = decoded.height;
  final longSide = math.max(w, h);
  if (longSide <= maxSide) return decoded;

  final scale = maxSide / longSide;
  final tw = math.max(1, (w * scale).round());
  final th = math.max(1, (h * scale).round());

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    decoded,
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(tw, th);
  } finally {
    picture.dispose();
    decoded.dispose();
  }
}

/// Converts an already-decoded [ui.Image] (RGBA) into a BGR OpenCV [cv.Mat]
/// ready to feed into [YoloModel.infer]. Does not dispose [uiImage].
Future<cv.Mat> uiImageToBgrMat(ui.Image uiImage) async {
  final ByteData? rgbaData =
      await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (rgbaData == null) {
    throw Exception('Could not extract raw pixels from image.');
  }
  final Uint8List rawRgbaPixels = rgbaData.buffer.asUint8List();

  final imageRGBA = cv.Mat.fromList(
    uiImage.height,
    uiImage.width,
    cv.MatType.CV_8UC4,
    rawRgbaPixels,
  );

  final bgr = cv.cvtColor(imageRGBA, cv.COLOR_RGBA2BGR);
  imageRGBA.dispose();
  return bgr;
}

/// Disposes a replaced [ui.Image] only after the next frame has painted, so
/// a widget that was still drawing it never touches a disposed image.
void disposeImageAfterFrame(ui.Image? image) {
  if (image == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
}
