/// Spoken navigation commands for voice entry (English + Hindi/Hinglish).
/// Pure Dart.
library;

enum VoiceCommand { next, back, skip, repeat, stop, clear }

/// Lowercase words separated by single spaces: punctuation and symbols
/// become spaces, subscript digits become digits ("O₂" → "o2"). Devanagari
/// is kept with nukta and chandrabindu variants unified, since recognisers
/// spell "बढ़ो"/"हाँ" either way.
String normalizeUtterance(String text) {
  var t = text.toLowerCase();
  const subscripts = '₀₁₂₃₄₅₆₇₈₉';
  for (var i = 0; i < subscripts.length; i++) {
    t = t.replaceAll(subscripts[i], '$i');
  }
  // Precomposed nukta letters (क़ … य़) → base letter; drop nukta; ँ → ं.
  t = t.replaceAllMapped(
    RegExp(r'[क़-य़]', unicode: true),
    (m) => String.fromCharCode(const [
      0x915,
      0x916,
      0x917,
      0x91C,
      0x921,
      0x922,
      0x92B,
      0x92F
    ][m[0]!.codeUnitAt(0) - 0x958]),
  );
  t = t
      .replaceAll(String.fromCharCode(0x093C), '')
      .replaceAll(String.fromCharCode(0x0901), String.fromCharCode(0x0902));
  t = t.replaceAll(RegExp(r'[^\p{L}\p{M}\d]+', unicode: true), ' ');
  return t.trim();
}

/// Courtesy words ignored around a command ("next please", "ok stop").
const _filler = {
  'please',
  'ok',
  'okay',
  'now',
  'kripya',
  'kripaya',
  'ab',
  'कृपया',
  'अब',
};

final _commands = {
  for (final e in _commandPhrases.entries)
    e.key: {for (final p in e.value) normalizeUtterance(p)},
};

const _commandPhrases = <VoiceCommand, Set<String>>{
  VoiceCommand.next: {
    'next',
    'next page',
    'continue',
    'go ahead',
    'proceed',
    'aage',
    'aage badho',
    'aage chalo',
    'agla',
    'agla page',
    'आगे',
    'आगे बढ़ो',
    'आगे बढ़ें',
    'अगला',
    'अगला पेज',
  },
  VoiceCommand.back: {
    'back',
    'go back',
    'previous',
    'previous page',
    'peeche',
    'piche',
    'peeche jao',
    'pichla',
    'पीछे',
    'पीछे जाओ',
    'पिछला',
  },
  VoiceCommand.skip: {
    'skip',
    'skip this',
    'skip it',
    'chhodo',
    'chodo',
    'chhod do',
    'chod do',
    'छोड़ो',
    'छोड़ दो',
    'छोडो',
  },
  VoiceCommand.repeat: {
    'repeat',
    'repeat question',
    'repeat the question',
    'say again',
    'say that again',
    'again',
    'pardon',
    'what',
    'dobara',
    'phir se',
    'fir se',
    'dobara bolo',
    'दोबारा',
    'फिर से',
    'दोबारा बोलो',
  },
  VoiceCommand.stop: {
    'stop',
    'stop voice',
    'stop listening',
    'cancel',
    'exit',
    'band karo',
    'band',
    'ruko',
    'bas',
    'बंद करो',
    'बंद',
    'रुको',
    'बस',
  },
  VoiceCommand.clear: {
    'clear',
    'clear it',
    'clear this',
    'delete',
    'erase',
    'hatao',
    'mitao',
    'हटाओ',
    'मिटाओ',
  },
};

/// The command [transcript] consists of, or null when it is an answer.
/// Only whole utterances count, so an answer containing "back" is not
/// mistaken for a command.
VoiceCommand? matchVoiceCommand(String transcript) {
  final words = normalizeUtterance(transcript)
      .split(' ')
      .where((w) => w.isNotEmpty && !_filler.contains(w))
      .join(' ');
  if (words.isEmpty) return null;
  for (final e in _commands.entries) {
    if (e.value.contains(words)) return e.key;
  }
  return null;
}
