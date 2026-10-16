/// Device-local screening history; contains no patient details or answers.
class ScreeningTiming {
  const ScreeningTiming({
    required this.id,
    required this.diseaseCode,
    required this.startedAt,
    this.completedAt,
    this.abandonedAt,
  });

  final String id;
  final String diseaseCode;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? abandonedAt;

  bool get isRunning => completedAt == null && abandonedAt == null;
  bool get isCompleted => completedAt != null;
  Duration? get duration => completedAt?.difference(startedAt);

  Duration elapsedAt(DateTime now) {
    final elapsed = (completedAt ?? abandonedAt ?? now).difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  ScreeningTiming finish(DateTime at, {bool abandoned = false}) {
    if (!isRunning) return this;
    final end = at.isBefore(startedAt) ? startedAt : at;
    return ScreeningTiming(
      id: id,
      diseaseCode: diseaseCode,
      startedAt: startedAt,
      completedAt: abandoned ? null : end,
      abandonedAt: abandoned ? end : null,
    );
  }

  factory ScreeningTiming.fromJson(Map<String, dynamic> json) =>
      ScreeningTiming(
        id: json['id'] as String,
        diseaseCode: json['diseaseCode'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
        abandonedAt: DateTime.tryParse(json['abandonedAt'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'diseaseCode': diseaseCode,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'completedAt': completedAt?.toUtc().toIso8601String(),
        'abandonedAt': abandonedAt?.toUtc().toIso8601String(),
        'durationMs': duration?.inMilliseconds,
      };
}

String formatScreeningDuration(Duration duration) {
  final seconds = duration.isNegative ? 0 : duration.inSeconds;
  String two(int value) => value.toString().padLeft(2, '0');
  final minutesAndSeconds = '${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
  return seconds < 3600
      ? minutesAndSeconds
      : '${two(seconds ~/ 3600)}:$minutesAndSeconds';
}
