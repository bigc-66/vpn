import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/services/speed_test_service.dart';

class SpeedTestCard extends StatefulWidget {
  const SpeedTestCard({super.key});

  @override
  State<SpeedTestCard> createState() => _SpeedTestCardState();
}

class _SpeedTestCardState extends State<SpeedTestCard> {
  final _service = SpeedTestService();

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.speedTestTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: strings.speedTestPing,
                        value: _pingText,
                        unit: 'ms',
                        active: _service.phase == SpeedTestPhase.ping,
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        label: strings.speedTestDownload,
                        value: _downloadText,
                        unit: 'Mbps',
                        active: _service.phase == SpeedTestPhase.download,
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        label: strings.speedTestUpload,
                        value: _uploadText,
                        unit: 'Mbps',
                        active: _service.phase == SpeedTestPhase.upload,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _service.running
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: _service.start,
                          icon: const Icon(Icons.speed, size: 18),
                          label: Text(strings.speedTestStart),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _pingText {
    if (_service.phase == SpeedTestPhase.idle) return '--';
    if (_service.pingMs == 0 &&
        _service.phase.index <= SpeedTestPhase.ping.index) return '--';
    if (_service.pingMs < 0) return '--';
    return '${_service.pingMs}';
  }

  String get _downloadText {
    if (_service.downloadMbps == 0 &&
        _service.phase.index <= SpeedTestPhase.download.index) return '--';
    return _service.downloadMbps.toStringAsFixed(1);
  }

  String get _uploadText {
    if (_service.uploadMbps == 0 &&
        _service.phase.index <= SpeedTestPhase.upload.index) return '--';
    return _service.uploadMbps.toStringAsFixed(1);
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.unit,
    this.active = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: active ? theme.colorScheme.primary : null,
          ),
        ),
        Text(unit, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
