/// Only the classification criteria printed in Sepsis_STW_Final_15-10-26.pdf.
library;

enum SepsisClassification {
  highProbability,
  observe,
  overlap,
  incomplete,
  noListedCriterion
}

SepsisClassification classifySepsis({
  required int redFlags,
  required int yellowFlags,
  num? gestationWeeks,
  num? birthWeightG,
}) {
  if (redFlags > 0 || yellowFlags >= 2) {
    return SepsisClassification.highProbability;
  }
  if (yellowFlags == 0) return SepsisClassification.noListedCriterion;
  final high = (gestationWeeks != null && gestationWeeks <= 32) ||
      (birthWeightG != null && birthWeightG < 1500);
  final observe = gestationWeeks != null && gestationWeeks > 32;
  // Both boxes explicitly match this combination. Do not invent precedence.
  if (high && observe) return SepsisClassification.overlap;
  if (high) return SepsisClassification.highProbability;
  if (observe && birthWeightG != null) return SepsisClassification.observe;
  return SepsisClassification.incomplete;
}

enum SepsisDurationCondition {
  pneumonia,
  suspectedSterileNormalCsf,
  positiveAsymptomaticDay5NoMeningitis,
  positiveSymptomaticAfterDay5NoMeningitis,
  csfSuggestiveMeningitis,
}

const sepsisDurationDays = <SepsisDurationCondition, String>{
  SepsisDurationCondition.pneumonia: '5–7 DAYS',
  SepsisDurationCondition.suspectedSterileNormalCsf: '5–7 DAYS',
  SepsisDurationCondition.positiveAsymptomaticDay5NoMeningitis: '7–10 DAYS',
  SepsisDurationCondition.positiveSymptomaticAfterDay5NoMeningitis:
      '10–14 DAYS',
  SepsisDurationCondition.csfSuggestiveMeningitis: '21 DAYS',
};
