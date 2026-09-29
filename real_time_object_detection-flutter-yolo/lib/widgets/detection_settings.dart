import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact, centered confidence / IoU card.
class DetectionSettings extends StatelessWidget {
  final double confidenceThreshold;
  final double iouThreshold;
  final ValueChanged<double> onConfidenceChanged;
  final ValueChanged<double> onIouChanged;

  const DetectionSettings({
    super.key,
    required this.confidenceThreshold,
    required this.iouThreshold,
    required this.onConfidenceChanged,
    required this.onIouChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded,
                        size: 18, color: AppColors.cyan),
                    const SizedBox(width: 8),
                    Text(
                      'Detection settings',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _sliderRow(context, 'Confidence', confidenceThreshold,
                    AppColors.cyan, onConfidenceChanged),
                _sliderRow(context, 'IoU threshold', iouThreshold,
                    AppColors.pink, onIouChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sliderRow(
    BuildContext context,
    String label,
    double value,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${(value * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
            overlayColor: color.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 1,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
