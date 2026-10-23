/// Only the thresholds explicitly printed in the supplied Post Asphyxia STW.
library;

/// Missing values are not negative observations. Blood gas criteria apply
/// only to a cord sample or a sample obtained within one hour.
bool hasPostAsphyxiaHighRisk(
        {num? apgar10,
        bool? ppv10,
        String? sampleTiming,
        num? ph,
        num? baseDeficit}) =>
    (apgar10 != null && apgar10 <= 5) ||
    ppv10 == true ||
    ((sampleTiming == 'cord' || sampleTiming == 'within1h') &&
        ((ph != null && ph <= 7.1) ||
            (baseDeficit != null && baseDeficit >= 12)));

/// This identifies a potential referral candidate, never final TH eligibility.
/// The poster requires confirmation of strict NNF criteria at the referral NICU.
bool isPotentialCoolingCandidate(
        {num? gaWeeks, String? stage, String? acuteHypoxia}) =>
    gaWeeks != null &&
    gaWeeks >= 36 &&
    (stage == 'moderate' || stage == 'severe') &&
    acuteHypoxia == 'yes';
