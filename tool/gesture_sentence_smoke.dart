// Headless check for gesture sentence output:
//  - normal signing gaps -> spaces only, one final period
//  - a >=3s full stop     -> '. ' sentence break
//  - removeLast()          -> no stale break indexes
import 'dart:io';

import 'package:isign/ai/gesture_sequence.dart';
import 'package:isign/ai/classification_result.dart';

void check(bool ok, String msg) {
  stdout.writeln('${ok ? 'PASS' : 'FAIL'}: $msg');
  if (!ok) failures++;
}

int failures = 0;

GestureSequence seq() => GestureSequence();

ClassificationResult word(String label) =>
    ClassificationResult(label: label, confidence: 0.95);

// Feed a word as the screen does: hold long enough to commit, then the
// cooldown expires before the next word.
void feed(GestureSequence g, String label, {Duration after = const Duration(milliseconds: 900)}) {
  // Hold phase: same label reported past the 300ms hold.
  final t0 = DateTime.now();
  while (DateTime.now().difference(t0) < const Duration(milliseconds: 350)) {
    g.update(word(label), velocity: 0.0);
  }
  // Wait out the phrase window without recognizing (unrecognized frames
  // clear the stable state but keep the sequence).
  final waitUntil = DateTime.now().add(after);
  while (DateTime.now().isBefore(waitUntil)) {
    g.update(const ClassificationResult(label: '', confidence: 0.0));
  }
}

void main() {
  // 1) Ordinary signing: words flow with spaces, single final period.
  var g = seq();
  feed(g, 'Hello');
  feed(g, 'World', after: const Duration(milliseconds: 900));
  feed(g, 'Friends', after: const Duration(milliseconds: 900));
  check(g.translatedText == 'Hello World Friends.',
      'fast signing -> flowing words: got "${g.translatedText}"');

  // 2) A 3.5s full stop between words creates exactly one sentence break.
  //    (The `after` delay of a feed() is the pause AFTER that word.)
  g = seq();
  feed(g, 'Thank');
  feed(g, 'You', after: const Duration(milliseconds: 3500));
  feed(g, 'Bye', after: const Duration(milliseconds: 900));
  check(g.translatedText == 'Thank You. Bye.',
      'long pause -> sentence break: got "${g.translatedText}"');

  // 3) Two long pauses -> two breaks.
  g = seq();
  feed(g, 'One', after: const Duration(milliseconds: 3500));
  feed(g, 'Two', after: const Duration(milliseconds: 3500));
  feed(g, 'Three');
  check(g.translatedText == 'One. Two. Three.',
      'two long pauses -> two breaks: got "${g.translatedText}"');

  // 4) A 2s pause (old 800ms trigger) must NOT break the sentence.
  g = seq();
  feed(g, 'Slow');
  feed(g, 'But', after: const Duration(milliseconds: 2000));
  feed(g, 'Continuous', after: const Duration(milliseconds: 2000));
  check(g.translatedText == 'Slow But Continuous.',
      '2s pauses stay within one sentence: got "${g.translatedText}"');

  // 5) removeLast() must not leave a stale break behind. "First" is
  //    followed by a 3.5s pause (break recorded before "Second"); after
  //    removing "Second" that break index must be pruned, so "Third"
  //    joins with a space — a stale index would render "First. Third.".
  g = seq();
  feed(g, 'First', after: const Duration(milliseconds: 3500));
  feed(g, 'Second');
  final removed = g.removeLast();
  check(removed == 'Second', 'removeLast returns the removed word');
  feed(g, 'Third', after: const Duration(milliseconds: 900));
  check(g.translatedText == 'First Third.',
      'no stale period after removeLast: got "${g.translatedText}"');

  // 6) Empty sequence renders empty (no stray '.').
  g = seq();
  check(g.translatedText == '', 'empty sequence -> empty text');

  stdout.writeln(failures == 0 ? '\nALL PASSED' : '\n$failures FAILED');
  if (failures > 0) throw Exception('$failures checks failed');
}
