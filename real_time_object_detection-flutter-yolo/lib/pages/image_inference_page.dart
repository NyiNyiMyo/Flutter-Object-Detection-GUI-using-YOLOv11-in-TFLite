import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../utils/detector.dart';
import '../utils/frame_utils.dart';
import '../utils/layout_utils.dart';
import '../widgets/detection_image_view.dart';
import '../widgets/detection_settings.dart';
import '../widgets/ui_kit.dart';
import '../yolo.dart';

class ImageInferencePage extends StatefulWidget {
  final YoloModel model;
  const ImageInferencePage({super.key, required this.model});

  @override
  State<ImageInferencePage> createState() => _ImageInferencePageState();
}

class _ImageInferencePageState extends State<ImageInferencePage> {
  ui.Image? _image;
  bool _isProcessing = false;

  double confidenceThreshold = 0.3;
  double iouThreshold = 0.3;

  // Cached raw model output so moving the sliders only re-runs the cheap
  // postprocessing step, not the full (expensive) inference.
  List<List<double>>? _inferenceOutput;
  DetectionResult _result = DetectionResult.empty;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _pickAndDetect() async {
    if (_isProcessing) return;
    final XFile? picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isProcessing = true);
    try {
      final bytes = await picked.readAsBytes();
      // One decoded image is used for BOTH display and detection.
      final image = await decodeUiImage(bytes);
      final mat = await uiImageToBgrMat(image);

      final output = runInference(widget.model, mat);
      final result = runPostprocess(
        widget.model,
        output,
        mat.cols,
        mat.rows,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
      );
      mat.dispose();

      if (!mounted) {
        image.dispose();
        return;
      }
      final old = _image;
      setState(() {
        _image = image;
        _inferenceOutput = output;
        _result = result;
        _isProcessing = false;
      });
      disposeImageAfterFrame(old);
    } catch (e) {
      debugPrint('Image inference error: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not process this image: $e')),
      );
    }
  }

  void _rerunPostprocess() {
    final output = _inferenceOutput;
    final image = _image;
    if (output == null || image == null) return;
    setState(() {
      _result = runPostprocess(
        widget.model,
        output,
        image.width,
        image.height,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
      );
    });
  }

  void _clear() {
    final old = _image;
    setState(() {
      _image = null;
      _inferenceOutput = null;
      _result = DetectionResult.empty;
      _isProcessing = false;
    });
    disposeImageAfterFrame(old);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        MediaPanel(
          height: outputPanelHeight(context),
          onTap: image == null && !_isProcessing ? _pickAndDetect : null,
          child: image == null
              ? EmptyState(
                  icon: Icons.add_photo_alternate_rounded,
                  title: _isProcessing ? 'Analyzing…' : 'Pick an image',
                  subtitle: _isProcessing
                      ? null
                      : 'Tap to choose a photo and detect objects',
                  busy: _isProcessing,
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    DetectionImageView(image: image, result: _result),
                    if (_isProcessing)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0x88000000),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _isProcessing ? null : _pickAndDetect,
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(image == null ? 'Choose image' : 'Change image'),
              ),
              if (image != null)
                TextButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ),
        if (image != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                InfoChip(
                  icon: Icons.category_rounded,
                  label: '${_result.bboxes.length} objects',
                  color: AppColors.mint,
                ),
                InfoChip(
                  icon: Icons.aspect_ratio_rounded,
                  label: '${image.width}×${image.height}',
                  color: AppColors.violet,
                ),
              ],
            ),
          ),
        DetectionSettings(
          confidenceThreshold: confidenceThreshold,
          iouThreshold: iouThreshold,
          onConfidenceChanged: (v) {
            setState(() => confidenceThreshold = v);
            _rerunPostprocess();
          },
          onIouChanged: (v) {
            setState(() => iouThreshold = v);
            _rerunPostprocess();
          },
        ),
      ],
    );
  }
}
