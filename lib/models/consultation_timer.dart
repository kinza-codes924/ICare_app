// Consultation Timer Model
// Handles consultation duration tracking and validation

import 'dart:async';

class ConsultationTimer {
  static const Duration minDuration = Duration(minutes: 15);
  static Duration maxDuration = Duration(minutes: 30); // Admin can change this
  static const Duration warningBeforeEnd = Duration(minutes: 2);

  Duration _elapsed = Duration.zero;
  Timer? _timer;
  final Function(Duration)? onTick;
  final Function()? onMinimumReached;
  final Function()? onWarningBeforeMax;
  final Function()? onMaximumReached;

  bool _isRunning = false;
  bool _minimumReached = false;
  bool _warningShown = false;

  ConsultationTimer({
    this.onTick,
    this.onMinimumReached,
    this.onWarningBeforeMax,
    this.onMaximumReached,
  });

  Duration get elapsed => _elapsed;
  bool get isRunning => _isRunning;
  bool get canEnd => _elapsed >= minDuration;
  bool get hasReachedMaximum => _elapsed >= maxDuration;
  
  String get formattedTime {
    final minutes = _elapsed.inMinutes;
    final seconds = _elapsed.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get progress {
    return _elapsed.inSeconds / maxDuration.inSeconds;
  }

  Duration get remainingTime {
    final remaining = maxDuration - _elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String get remainingTimeFormatted {
    final remaining = remainingTime;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Sync timer to a known start time (e.g. from backend / first message)
  void syncFromStartTime(DateTime startTime) {
    final now = DateTime.now();
    final serverElapsed = now.difference(startTime);
    if (serverElapsed > Duration.zero && serverElapsed < maxDuration) {
      _elapsed = serverElapsed;
      _minimumReached = _elapsed >= minDuration;
    }
  }

  void start() {
    if (_isRunning) return;
    
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsed += const Duration(seconds: 1);
      
      // Notify tick
      onTick?.call(_elapsed);
      
      // Check minimum duration reached
      if (!_minimumReached && _elapsed >= minDuration) {
        _minimumReached = true;
        onMinimumReached?.call();
      }
      
      // Check warning before maximum
      if (!_warningShown && _elapsed >= (maxDuration - warningBeforeEnd)) {
        _warningShown = true;
        onWarningBeforeMax?.call();
      }
      
      // Check maximum duration reached
      if (_elapsed >= maxDuration) {
        stop();
        onMaximumReached?.call();
      }
    });
  }

  void pause() {
    _isRunning = false;
    _timer?.cancel();
  }

  void resume() {
    if (!_isRunning && !hasReachedMaximum) {
      start();
    }
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
  }

  void reset() {
    stop();
    _elapsed = Duration.zero;
    _minimumReached = false;
    _warningShown = false;
  }

  void dispose() {
    stop();
  }

  // Validation methods
  String? validateEndConsultation() {
    if (_elapsed < minDuration) {
      final remaining = minDuration - _elapsed;
      final minutes = remaining.inMinutes;
      final seconds = remaining.inSeconds % 60;
      return 'Consultation must be at least 15 minutes long. ${minutes}m ${seconds}s remaining.';
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'elapsed': _elapsed.inSeconds,
      'isRunning': _isRunning,
      'canEnd': canEnd,
      'hasReachedMaximum': hasReachedMaximum,
    };
  }

  factory ConsultationTimer.fromJson(Map<String, dynamic> json) {
    final timer = ConsultationTimer();
    timer._elapsed = Duration(seconds: json['elapsed'] ?? 0);
    timer._isRunning = json['isRunning'] ?? false;
    timer._minimumReached = timer._elapsed >= minDuration;
    return timer;
  }
}

// Consultation Timer Status
enum ConsultationTimerStatus {
  notStarted,
  belowMinimum,
  withinRange,
  nearMaximum,
  reachedMaximum,
}

extension ConsultationTimerStatusExtension on ConsultationTimer {
  ConsultationTimerStatus get status {
    if (_elapsed == Duration.zero) {
      return ConsultationTimerStatus.notStarted;
    } else if (_elapsed < ConsultationTimer.minDuration) {
      return ConsultationTimerStatus.belowMinimum;
    } else if (_elapsed >= ConsultationTimer.maxDuration) {
      return ConsultationTimerStatus.reachedMaximum;
    } else if (_elapsed >= (ConsultationTimer.maxDuration - ConsultationTimer.warningBeforeEnd)) {
      return ConsultationTimerStatus.nearMaximum;
    } else {
      return ConsultationTimerStatus.withinRange;
    }
  }

  String get statusMessage {
    switch (status) {
      case ConsultationTimerStatus.notStarted:
        return 'Consultation not started';
      case ConsultationTimerStatus.belowMinimum:
        return 'Minimum 10 minutes required';
      case ConsultationTimerStatus.withinRange:
        return 'Consultation in progress';
      case ConsultationTimerStatus.nearMaximum:
        return 'Consultation ending soon';
      case ConsultationTimerStatus.reachedMaximum:
        return 'Maximum duration reached';
    }
  }
}
