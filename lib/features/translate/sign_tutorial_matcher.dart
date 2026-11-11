// Pure text matching for the speech-mode sign tutorial.
//
// Kept free of Flutter and database dependencies so the algorithm can be
// smoke-tested headless against the seed dictionary (plain `dart`, not
// `dart run`, to avoid the project's native build hooks):
//   dart tool/sign_tutorial_smoke.dart

/// Lowercases and strips punctuation, keeping letters, digits and the
/// backtick used by some FSL alphabet names ("A`").
///
/// Apostrophes are removed (not spaced) so contractions glue together:
/// speech output varies between "I'm fine" and "im fine", and both must
/// tokenize identically. Everything else collapses to spaces so
/// "Kumusta, ka?" and "kumusta ka" tokenize identically.
String normalizeSignText(String s) {
  final buf = StringBuffer();
  for (final code in s.toLowerCase().runes) {
    final isLetter = code >= 0x61 && code <= 0x7A; // a-z
    final isDigit = code >= 0x30 && code <= 0x39; // 0-9
    final isBacktick = code == 0x60;
    final isApostrophe = code == 0x27 || code == 0x2019; // ' '
    if (isLetter || isDigit || isBacktick) {
      buf.write(String.fromCharCode(code));
    } else if (!isApostrophe) {
      buf.write(' ');
    }
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _Phrase {
  final List<String> words;
  final int signId;
  const _Phrase(this.words, this.signId);
}

/// Matches [sentence] against [catalog] entries of
/// `(signId, signName, englishName)` and returns the matched sign ids in
/// reading order, each at most once.
///
/// Greedy longest-phrase-first: at every token position the longest catalog
/// phrase that matches wins, so multi-word signs ("Mga Karaniwang Parirala")
/// beat their component words. Unmatched words are skipped silently.
List<int> matchSignIds(String sentence, List<(int, String, String?)> catalog) {
  final tokenList = normalizeSignText(sentence)
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();
  if (tokenList.isEmpty) return const [];

  // Build the phrase list from both name variants (Filipino sign name and
  // English name), longest first so multi-word signs match before their
  // component words.
  final phrases = <_Phrase>[];
  for (final entry in catalog) {
    final (signId, signName, englishName) = entry;
    for (final name in <String?>[signName, englishName]) {
      if (name == null || name.trim().isEmpty) continue;
      final words = normalizeSignText(name)
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toList();
      if (words.isEmpty) continue;
      phrases.add(_Phrase(words, signId));
    }
  }
  phrases.sort((a, b) => b.words.length.compareTo(a.words.length));

  // Greedy scan: at each position take the longest phrase that matches.
  final matchedIds = <int>[];
  var i = 0;
  while (i < tokenList.length) {
    _Phrase? hit;
    for (final p in phrases) {
      if (p.words.length > tokenList.length - i) continue;
      var ok = true;
      for (var k = 0; k < p.words.length; k++) {
        if (tokenList[i + k] != p.words[k]) {
          ok = false;
          break;
        }
      }
      if (ok) {
        hit = p;
        break;
      }
    }
    if (hit != null) {
      if (!matchedIds.contains(hit.signId)) matchedIds.add(hit.signId);
      i += hit.words.length;
    } else {
      i++;
    }
  }
  return matchedIds;
}
