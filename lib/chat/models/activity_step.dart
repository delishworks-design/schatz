enum ActivityStepStatus {
  pending,
  inProgress,
  completed,
  error,
}

class ActivityStep {
  final String name;
  final ActivityStepStatus status;
  final DateTime timestamp;
  final Duration? duration;
  final String? details;

  ActivityStep({
    required this.name,
    this.status = ActivityStepStatus.pending,
    DateTime? timestamp,
    this.duration,
    this.details,
  }) : timestamp = timestamp ?? DateTime.now();

  ActivityStep copyWith({
    ActivityStepStatus? status,
    Duration? duration,
    String? details,
  }) {
    return ActivityStep(
      name: name,
      status: status ?? this.status,
      timestamp: timestamp,
      duration: duration ?? this.duration,
      details: details ?? this.details,
    );
  }

  String get statusIcon {
    switch (status) {
      case ActivityStepStatus.pending:
        return '○';
      case ActivityStepStatus.inProgress:
        return '◉';
      case ActivityStepStatus.completed:
        return '✓';
      case ActivityStepStatus.error:
        return '✗';
    }
  }

  String get durationText {
    if (duration == null) return '';
    if (duration!.inMilliseconds < 1000) {
      return '${duration!.inMilliseconds}ms';
    }
    return '${(duration!.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }
}
