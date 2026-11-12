// Headless smoke test for the speech-mode sign tutorial matcher.
//
// Loads the real seed dictionary as the catalog and checks the matching
// rules (case/punctuation normalization, English names, greedy longest
// phrase, dedupe) without needing a device. Run with plain `dart` (not
// `dart run`) so the project's native build hooks stay out of the way:
//
//   dart tool/sign_tutorial_smoke.dart

import 'dart:convert';
import 'dart:io';

import 'package:isign/features/translate/sign_tutorial_matcher.dart';

int _failures = 0;

void check(String label, List<int> got, List<String> wantNames,
    Map<int, String> nameById) {
  final gotNames = [for (final id in got) nameById[id] ?? '?'];
  final ok = gotNames.join(' | ') == wantNames.join(' | ');
  if (!ok) _failures++;
  stdout.writeln(
      '${ok ? 'PASS' : 'FAIL'}  $label\n      got: [${gotNames.join(' | ')}]  want: [${wantNames.join(' | ')}]');
}

void main() {
  final dict = jsonDecode(
          File('assets/seed/fsl_dictionary.json').readAsStringSync())
      as Map<String, dynamic>;

  final catalog = <(int, String, String?)>[];
  final nameById = <int, String>{};
  var id = 0;
  for (final cat in dict['categories'] as List<dynamic>) {
    for (final sign in (cat as Map<String, dynamic>)['signs'] as List<dynamic>) {
      final s = sign as Map<String, dynamic>;
      id++;
      final signName = (s['sign_name'] as String? ?? '').trim();
      final englishName = (s['sign_name_en'] as String? ?? '').trim();
      catalog.add((id, signName, englishName));
      nameById[id] = signName.isNotEmpty ? signName : englishName;
    }
  }
  stdout.writeln('catalog: ${catalog.length} signs\n');

  // Normalization basics.
  final norm = normalizeSignText('Kumusta, ka?');
  final normOk = norm == 'kumusta ka';
  if (!normOk) _failures++;
  stdout.writeln('${normOk ? 'PASS' : 'FAIL'}  normalize strips punctuation'
      '  -> "$norm"');

  // Filipino phrases, with case + punctuation noise.
  check('Magandang umaga!',
      matchSignIds('Magandang umaga!', catalog), ['Magandang Umaga'], nameById);
  check('Salamat po (unmatched word skipped)',
      matchSignIds('Salamat po', catalog), ['Salamat'], nameById);
  check('numbers in Filipino',
      matchSignIds('apat lima anim', catalog), ['Apat', 'Lima', 'Anim'], nameById);

  // English speech matches via english_name.
  check('How are you? (english)',
      matchSignIds('How are you?', catalog), ['Kumusta ka?'], nameById);
  check('Thank you very much (english, tail ignored)',
      matchSignIds('Thank you very much', catalog), ['Salamat'], nameById);
  check('Please help me (english, two signs)',
      matchSignIds('Please help me', catalog), ['Pakiusap', 'Tulong'], nameById);
  check('three four five (english numbers)',
      matchSignIds('three four five', catalog),
      ['Tatlo', 'Apat', 'Lima'], nameById);

  // Greedy longest phrase beats the single-letter alphabet sign "I".
  check('I love you (3-word phrase wins over letter I)',
      matchSignIds('I love you', catalog), ['Mahal Kita'], nameById);

  // Contractions keep their apostrophes glued: "I'm" -> "im".
  check("I'm fine (contraction)",
      matchSignIds("I'm fine", catalog), ['Mabuti naman'], nameById);

  // Dedupe: a sign referenced twice appears once.
  check('dedupe (Salamat twice)',
      matchSignIds('Thank you, thank you!', catalog), ['Salamat'], nameById);

  // No match at all.
  check('no match',
      matchSignIds('The quick brown fox jumps', catalog), [], nameById);

  // Empty / whitespace input.
  check('empty input', matchSignIds('   ', catalog), [], nameById);

  // --- Segments: one card per word of the sentence. -------------------
  String segLabel(List<SignSegment> segs) => [
        for (final s in segs)
          s.isSign ? '${s.display}=>${nameById[s.signId]}' : '${s.display}=>-'
      ].join(' | ');

  void checkSeg(String label, String sentence, String want) {
    final got = segLabel(matchSignSegments(sentence, catalog));
    final ok = got == want;
    if (!ok) _failures++;
    stdout.writeln(
        '${ok ? 'PASS' : 'FAIL'}  segments: $label\n      got: [$got]  want: [$want]');
  }

  // Matched phrase collapses to one segment; unknown words each get one.
  checkSeg('How are you? collapses', 'How are you?',
      'How are you?=>Kumusta ka?');
  checkSeg('unknown words kept', 'The quick brown fox jumps',
      'The=>- | quick=>- | brown=>- | fox=>- | jumps=>-');
  checkSeg('mixed match + unknown', 'Thank you very much',
      'Thank you=>Salamat | very=>- | much=>-');
  checkSeg('every word of "Salamat po"', 'Salamat po',
      'Salamat=>Salamat | po=>-');
  // Reading order + token accounting: segments cover every token exactly.
  final segs = matchSignSegments('Please help me today', catalog);
  final totalTokens =
      segs.fold<int>(0, (sum, s) => sum + s.tokenCount);
  final tokenCount =
      normalizeSignText('Please help me today').split(' ').length;
  final coverOk = totalTokens == tokenCount;
  if (!coverOk) _failures++;
  stdout.writeln(
      '${coverOk ? 'PASS' : 'FAIL'}  segments cover every token'
      '  ($totalTokens vs $tokenCount)');

  stdout.writeln('');
  if (_failures > 0) {
    stderr.writeln('$_failures failure(s)');
    exit(1);
  }
  stdout.writeln('ALL PASSED');
}
