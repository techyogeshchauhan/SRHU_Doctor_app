import '../models/stw_chunk.dart';
import '../understanding/query_analyzer.dart';

enum AnswerKind {
  /// Verbatim lines from one STW box.
  answer,

  /// Not sure which box (or a value is missing): ask back.
  clarify,

  /// Not in the approved STWs.
  notCovered,
}

/// Values taken from the question and the STW pathway they lead to.
class CaseSummary {
  const CaseSummary({required this.inputs, this.reviewNote});

  /// Echo of the values read from the question, e.g. "BG 30 mg/dL · no
  /// symptoms". Not clinical advice: lets the clinician check what was read.
  final String inputs;

  /// Set when the STW reading needs clinician sign-off (CLINICAL_REVIEW.md).
  final String? reviewNote;
}

class StwAnswer {
  const StwAnswer._({
    required this.kind,
    required this.analysis,
    this.region,
    this.lines = const [],
    this.options = const [],
    this.prompt,
    this.caseSummary,
    this.confidence = 0,
  });

  const StwAnswer.answer({
    required QueryAnalysis analysis,
    required StwChunk region,
    required List<StwSegment> lines,
    CaseSummary? caseSummary,
    double confidence = 1,
  }) : this._(
          kind: AnswerKind.answer,
          analysis: analysis,
          region: region,
          lines: lines,
          caseSummary: caseSummary,
          confidence: confidence,
        );

  const StwAnswer.clarify({
    required QueryAnalysis analysis,
    required String prompt,
    required List<StwChunk> options,
    double confidence = 0,
  }) : this._(
          kind: AnswerKind.clarify,
          analysis: analysis,
          prompt: prompt,
          options: options,
          confidence: confidence,
        );

  const StwAnswer.notCovered(QueryAnalysis analysis)
      : this._(kind: AnswerKind.notCovered, analysis: analysis);

  final AnswerKind kind;
  final QueryAnalysis analysis;

  /// The STW box the answer comes from.
  final StwChunk? region;

  /// Verbatim segments of [region] that answer the question.
  final List<StwSegment> lines;

  /// Boxes offered when asking back.
  final List<StwChunk> options;

  /// Question asked back (app text, e.g. "Which of these do you mean?").
  final String? prompt;
  final CaseSummary? caseSummary;
  final double confidence;
}
