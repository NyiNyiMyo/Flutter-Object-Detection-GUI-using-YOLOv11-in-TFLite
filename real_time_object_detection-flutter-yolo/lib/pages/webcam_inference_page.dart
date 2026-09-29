import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/detector.dart';
import '../utils/frame_utils.dart';
import '../utils/layout_utils.dart';
import '../widgets/detection_image_view.dart';
import '../widgets/detection_settings.dart';
import '../widgets/ui_kit.dart';
import '../yolo.dart';

/// Live camera inference.
///
/// Periodically takes a still snapshot via `takePicture()`, and shows that
/// same snapshot with its detection boxes, so picture and boxes always
/// match exactly.
///
/// Every camera the OS reports is offered as a button (Front / Back / USB).
/// The list is loaded when the tab opens (this does NOT turn a camera on),
/// so the buttons are visible before pressing Start.
///
/// Switching cameras always RELEASES the current camera first and only then
/// opens the next one - Android can't hold two cameras open at once, and
/// opening the new one before releasing the old one was what made switching
/// unstable there.
///
/// There is no mature official Flutter camera plugin for Linux, so this tab
/// shows a clear message there.
class WebcamInferencePage extends StatefulWidget {
  final YoloModel model;
  const WebcamInferencePage({super.key, required this.model});

  @override
  State<WebcamInferencePage> createState() => _WebcamInferencePageState();
}

class _WebcamInferencePageState extends State<WebcamInferencePage> {
  static const Duration detectionInterval = Duration(milliseconds: 500);

  CameraController? _controller;
  Timer? _timer;
  bool _isProcessing = false; // a capture + detect cycle is in flight
  bool _busy = false; // starting or switching
  bool _wantRunning = false; // the user wants the camera on

  List<CameraDescription> _cameras = [];
  CameraDescription? _selected;

  String? _unsupportedReason;
  String? _error;

  double confidenceThreshold = 0.3;
  double iouThreshold = 0.3;
  DetectionResult _result = DetectionResult.empty;
  ui.Image? _frame;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isLinux) {
      _unsupportedReason =
          'Live camera capture isn\'t supported on Linux yet.\n'
          'Use the Image tab to detect objects in photos instead.';
      return;
    }
    _loadCameras();
  }

  @override
  void dispose() {
    _wantRunning = false;
    _timer?.cancel();
    _controller?.dispose();
    _frame?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- cameras

  Future<void> _loadCameras() async {
    try {
      final cams = await availableCameras();
      if (!mounted) return;
      setState(() {
        _cameras = cams;
        if (cams.isEmpty) {
          _selected = null;
          _error = 'No camera found on this device.';
          return;
        }
        _error = null;
        // Keep the current choice if it still exists; otherwise prefer the
        // back camera, then whatever comes first.
        final keep = cams.where((c) => c.name == _selected?.name);
        _selected = keep.isNotEmpty
            ? keep.first
            : cams.firstWhere(
                (c) => c.lensDirection == CameraLensDirection.back,
                orElse: () => cams.first,
              );
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not list cameras: $e');
    }
  }

  String _cameraLabel(CameraDescription cam) {
    final base = switch (cam.lensDirection) {
      CameraLensDirection.front => 'Front',
      CameraLensDirection.back => 'Back',
      CameraLensDirection.external => 'USB',
    };
    final same =
        _cameras.where((c) => c.lensDirection == cam.lensDirection).toList();
    if (same.length <= 1) return base;
    return '$base ${same.indexWhere((c) => c.name == cam.name) + 1}';
  }

  IconData _cameraIcon(CameraDescription cam) {
    switch (cam.lensDirection) {
      case CameraLensDirection.front:
        return Icons.camera_front_rounded;
      case CameraLensDirection.back:
        return Icons.camera_rear_rounded;
      case CameraLensDirection.external:
        return Icons.usb_rounded;
    }
  }

  // -------------------------------------------------------------- lifecycle

  /// Stops capturing and fully releases the current camera.
  Future<void> _releaseController() async {
    _timer?.cancel();
    _timer = null;
    final controller = _controller;
    _controller = null;

    // Let any in-flight capture finish before disposing under it.
    var waited = 0;
    while (_isProcessing && waited < 3000) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      waited += 50;
    }
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint('Camera dispose error: $e');
      }
    }
  }

  /// Releases whatever is open, THEN opens [description].
  Future<void> _open(CameraDescription description) async {
    await _releaseController();

    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await controller.initialize();
    } catch (e) {
      await controller.dispose();
      rethrow;
    }
    try {
      await controller.setFlashMode(FlashMode.off);
    } catch (_) {
      // Not supported on every platform/camera - safe to ignore.
    }

    if (!mounted || !_wantRunning) {
      await controller.dispose();
      return;
    }
    _controller = controller;
    _timer = Timer.periodic(detectionInterval, (_) => _captureAndDetect());
  }

  void _clearFrame() {
    final old = _frame;
    _frame = null;
    _result = DetectionResult.empty;
    disposeImageAfterFrame(old);
  }

  Future<void> _start() async {
    final camera = _selected;
    if (camera == null || _busy) return;
    setState(() {
      _busy = true;
      _wantRunning = true;
      _error = null;
      _clearFrame();
    });
    try {
      await _open(camera);
    } catch (e) {
      if (mounted) {
        setState(() {
          _wantRunning = false;
          _error = 'Could not start the ${_cameraLabel(camera)} camera: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    _wantRunning = false;
    setState(_clearFrame);
    await _releaseController();
  }

  Future<void> _select(CameraDescription camera) async {
    if (_busy || camera.name == _selected?.name) return;
    setState(() => _selected = camera);
    if (!_wantRunning) return; // just remember the choice until Start

    setState(() {
      _busy = true;
      _error = null;
      _clearFrame();
    });
    try {
      await _open(camera);
    } catch (e) {
      if (mounted) {
        setState(() {
          _wantRunning = false;
          _error = 'Could not open the ${_cameraLabel(camera)} camera: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -------------------------------------------------------------- detection

  Future<void> _captureAndDetect() async {
    final controller = _controller;
    if (controller == null ||
        _isProcessing ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    _isProcessing = true;
    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      unawaited(File(photo.path).delete().catchError((_) => File(photo.path)));

      final image = await decodeUiImage(bytes);
      final mat = await uiImageToBgrMat(image);
      final result = runDetection(
        widget.model,
        mat,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
      );
      mat.dispose();

      // The camera may have been stopped or switched while we were busy.
      if (!mounted || _controller != controller) {
        image.dispose();
        return;
      }
      final old = _frame;
      setState(() {
        _frame = image;
        _result = result;
      });
      disposeImageAfterFrame(old);
    } catch (e) {
      debugPrint('Camera frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // --------------------------------------------------------------------- UI

  Widget _panelContent() {
    final frame = _frame;
    if (!_wantRunning) {
      return const EmptyState(
        icon: Icons.videocam_rounded,
        title: 'Camera is off',
        subtitle: 'Choose a camera below, then press Start',
      );
    }
    if (frame == null) {
      return const EmptyState(
        icon: Icons.videocam_rounded,
        title: 'Starting camera…',
        busy: true,
      );
    }
    return DetectionImageView(image: frame, result: _result);
  }

  Widget _cameraPicker() {
    if (_cameras.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final cam in _cameras)
            ChoiceChip(
              avatar: Icon(_cameraIcon(cam), size: 18),
              label: Text(_cameraLabel(cam)),
              selected: _selected?.name == cam.name,
              onSelected: _busy ? null : (_) => _select(cam),
            ),
          if (!_wantRunning)
            IconButton(
              tooltip: 'Rescan cameras',
              onPressed: _busy ? null : _loadCameras,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_unsupportedReason != null) {
      return EmptyState(
        icon: Icons.videocam_off_rounded,
        title: 'Camera unavailable',
        subtitle: _unsupportedReason,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        MediaPanel(height: outputPanelHeight(context), child: _panelContent()),
        _cameraPicker(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: _wantRunning
                ? OutlinedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop camera'),
                  )
                : FilledButton.icon(
                    onPressed: (_busy || _selected == null) ? null : _start,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start camera'),
                  ),
          ),
        ),
        if (_wantRunning && _frame != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: InfoChip(
                icon: Icons.category_rounded,
                label: '${_result.bboxes.length} objects',
                color: AppColors.mint,
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        DetectionSettings(
          confidenceThreshold: confidenceThreshold,
          iouThreshold: iouThreshold,
          onConfidenceChanged: (v) => setState(() => confidenceThreshold = v),
          onIouChanged: (v) => setState(() => iouThreshold = v),
        ),
      ],
    );
  }
}
