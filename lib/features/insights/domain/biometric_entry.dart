import 'package:freezed_annotation/freezed_annotation.dart';

part 'biometric_entry.freezed.dart';
part 'biometric_entry.g.dart';

/// Daily biometric / weight measurement.
@freezed
class WeightEntry with _$WeightEntry {
  const factory WeightEntry({
    required String id,
    required DateTime recordedAt,
    required double weightKg,
    @Default(0.0) double bodyFatPct,
    @Default(0.0) double muscleKg,
    String? notes,
  }) = _WeightEntry;

  factory WeightEntry.fromJson(Map<String, dynamic> json) =>
      _$WeightEntryFromJson(json);
}

/// Adherence correlator insight — surfaced in Insights tab.
@freezed
class AdherenceInsight with _$AdherenceInsight {
  const factory AdherenceInsight({
    required String id,
    required String title,
    required String body,
    required InsightSeverity severity,
    required DateTime generatedAt,
    @Default(<String>[]) List<String> tags,
  }) = _AdherenceInsight;

  factory AdherenceInsight.fromJson(Map<String, dynamic> json) =>
      _$AdherenceInsightFromJson(json);
}

enum InsightSeverity {
  info,
  positive,
  warning,
  critical,
}

extension InsightSeverityX on InsightSeverity {
  String get label {
    switch (this) {
      case InsightSeverity.info:
        return 'Info';
      case InsightSeverity.positive:
        return 'Doing Great';
      case InsightSeverity.warning:
        return 'Heads Up';
      case InsightSeverity.critical:
        return 'Action Needed';
    }
  }
}