import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Lightweight frame telemetry for local profile/debug runs.
///
/// It is intentionally absent from release builds and reports batches rather
/// than logging on every frame, so it cannot become a source of jank itself.
abstract final class FrameStatsProbe {
  static const _sampleSize = 60;
  static bool _installed = false;
  static final List<FrameTiming> _sample = <FrameTiming>[];

  static void install() {
    if (_installed || kReleaseMode) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    _sample.addAll(timings);
    if (_sample.length < _sampleSize) return;

    final totalUi = _sample.fold<int>(
      0,
      (sum, timing) => sum + timing.buildDuration.inMicroseconds,
    );
    final totalRaster = _sample.fold<int>(
      0,
      (sum, timing) => sum + timing.rasterDuration.inMicroseconds,
    );
    final jankyFrames = _sample
        .where((timing) => timing.totalSpan.inMicroseconds > 16667)
        .length;
    final maxFrame = _sample.fold<Duration>(
      Duration.zero,
      (max, timing) => timing.totalSpan > max ? timing.totalSpan : max,
    );

    developer.log(
      '[PRISM PERF] frames=${_sample.length} '
      'avgUiMs=${_milliseconds(totalUi / _sample.length)} '
      'avgRasterMs=${_milliseconds(totalRaster / _sample.length)} '
      'janky=$jankyFrames maxFrameMs=${_milliseconds(maxFrame.inMicroseconds)}',
    );
    _sample.clear();
  }

  static String _milliseconds(num microseconds) =>
      (microseconds / 1000).toStringAsFixed(2);
}
