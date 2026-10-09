import 'movement_detector.dart';

class GestureRule {
  final String shape;
  final MovementType movement;
  final List<String> signs;
  const GestureRule(this.shape, this.movement, this.signs);
}

class GestureDictionary {
  static const _rules = [
    GestureRule('Kamusta', MovementType.wave, ['Paalam']),
    GestureRule('Kamusta', MovementType.forward, ['Salamat']),
    GestureRule('Kamusta', MovementType.circular, ['Pakiusap']),
  ];

  List<String> lookup(String shapeLabel, MovementType movement) {
    if (movement == MovementType.still || movement == MovementType.unknown) {
      return [];
    }

    return _rules
        .where((r) => r.shape == shapeLabel && r.movement == movement)
        .expand((r) => r.signs)
        .toList();
  }
}
