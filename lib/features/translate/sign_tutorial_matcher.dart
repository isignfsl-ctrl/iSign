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

/// One segment of a spoken sentence in reading order: either a dictionary
/// sign (possibly spanning several words, e.g. "How are you?") or a single
/// word the dictionary does not know ([signId] == null).
///
/// The tutorial strip renders a card per segment, so every word of the
/// sentence is accounted for instead of only the matched signs.
class SignSegment {
  /// Surface text for display: the raw word for unmatched words, the raw
  /// words of the phrase joined for matches.
  final String display;

  /// Matched catalog sign id, or null when no sign exists for this word.
  final int? signId;

  /// Normalized tokens consumed (phrase length, or 1 for a single word).
  final int tokenCount;

  const SignSegment({
    required this.display,
    this.signId,
    required this.tokenCount,
  });

  bool get isSign => signId != null;
}

class _Phrase {
  final List<String> words;
  final int signId;
  const _Phrase(this.words, this.signId);
}

/// Splits [sentence] into (normalized, display) token pairs.
///
/// Normalization runs per whitespace-delimited raw word so the display
/// keeps the speaker's surface form ("I'm" instead of "im"); a raw word
/// that normalizes to several tokens ("thank,you") falls back to the
/// normalized pieces. Tokenizing the whole string and splitting per word
/// produce the same normalized stream — punctuation becomes spaces either
/// way — so phrase matching behaves identically.
List<(String, String)> _tokenize(String sentence) {
  final out = <(String, String)>[];
  for (final raw in sentence.split(RegExp(r'\s+'))) {
    if (raw.isEmpty) continue;
    final norm = normalizeSignText(raw);
    if (norm.isEmpty) continue;
    final pieces =
        norm.split(' ').where((w) => w.isNotEmpty).toList(growable: false);
    for (final p in pieces) {
      out.add((p, pieces.length == 1 ? raw : p));
    }
  }
  return out;
}

/// Matches [sentence] against [catalog] entries of
/// `(signId, signName, englishName)` and returns ONE segment per word of
/// the sentence, in reading order:
///
///  * dictionary hits become a single segment spanning all their tokens
///    (multi-word signs like "How are you?" collapse to one segment),
///  * every other word becomes its own segment with `signId == null`, so
///    the UI can tell the user the word is not a registered sign yet.
///
/// Greedy longest-phrase-first: at every token position the longest
/// catalog phrase that matches wins, so multi-word signs beat their
/// component words.
List<SignSegment> matchSignSegments(
    String sentence, List<(int, String, String?)> catalog) {
  final tokens = _tokenize(sentence);
  if (tokens.isEmpty) return const [];
  final normTokens = [for (final t in tokens) t.$1];
  final dispTokens = [for (final t in tokens) t.$2];

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

  // Greedy scan: at each position take the longest phrase that matches;
  // otherwise emit the word as an unmatched segment.
  final segments = <SignSegment>[];
  var i = 0;
  while (i < normTokens.length) {
    _Phrase? hit;
    for (final p in phrases) {
      if (p.words.length > normTokens.length - i) continue;
      var ok = true;
      for (var k = 0; k < p.words.length; k++) {
        if (normTokens[i + k] != p.words[k]) {
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
      segments.add(SignSegment(
        display: dispTokens.sublist(i, i + hit.words.length).join(' '),
        signId: hit.signId,
        tokenCount: hit.words.length,
      ));
      i += hit.words.length;
    } else {
      segments.add(SignSegment(display: dispTokens[i], tokenCount: 1));
      i++;
    }
  }
  return segments;
}

/// Matches [sentence] against [catalog] and returns the matched sign ids
/// in reading order, each at most once — unmatched words are skipped.
///
/// Thin dedupe wrapper over [matchSignSegments]; the tutorial strip uses
/// the segments directly so it can also render unmatched words.
List<int> matchSignIds(String sentence, List<(int, String, String?)> catalog) {
  final ids = <int>[];
  for (final seg in matchSignSegments(sentence, catalog)) {
    if (seg.signId != null && !ids.contains(seg.signId)) {
      ids.add(seg.signId!);
    }
  }
  return ids;
}
