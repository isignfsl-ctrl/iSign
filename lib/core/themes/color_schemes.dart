import 'package:flutter/material.dart';

class ColorSchemePreset {
  final String id;
  final String name;
  final String category;
  final Color seedColor;
  final Color? complementaryColor;
  final String description;

  const ColorSchemePreset({
    required this.id,
    required this.name,
    required this.category,
    required this.seedColor,
    this.complementaryColor,
    required this.description,
  });

  ColorScheme generateScheme(Brightness brightness) {
    if (complementaryColor != null) {
      return ColorScheme.fromSeed(
        seedColor: seedColor,
        secondary: complementaryColor,
        brightness: brightness,
      );
    }
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
  }
}

class ColorSchemes {
  ColorSchemes._();

  static const List<ColorSchemePreset> presets = [
    // Complementary — each uses explicit secondary color for true contrast
    ColorSchemePreset(
      id: 'blue_orange',
      name: 'Blue & Orange',
      category: 'Complementary',
      seedColor: Color(0xFF1565C0),
      complementaryColor: Color(0xFFE65100),
      description: 'Cool blue primary with warm orange accent',
    ),
    ColorSchemePreset(
      id: 'red_green',
      name: 'Red & Green',
      category: 'Complementary',
      seedColor: Color(0xFFC62828),
      complementaryColor: Color(0xFF2E7D32),
      description: 'Bold red primary with crisp green accent',
    ),
    ColorSchemePreset(
      id: 'purple_yellow',
      name: 'Purple & Yellow',
      category: 'Complementary',
      seedColor: Color(0xFF6A1B9A),
      complementaryColor: Color(0xFFF9A825),
      description: 'Rich purple primary with bright yellow accent',
    ),
    ColorSchemePreset(
      id: 'teal_coral',
      name: 'Teal & Coral',
      category: 'Complementary',
      seedColor: Color(0xFF00695C),
      complementaryColor: Color(0xFFE64A19),
      description: 'Deep teal primary with vibrant coral accent',
    ),
    ColorSchemePreset(
      id: 'navy_amber',
      name: 'Navy & Amber',
      category: 'Complementary',
      seedColor: Color(0xFF1A237E),
      complementaryColor: Color(0xFFFF8F00),
      description: 'Dark navy primary with warm amber accent',
    ),

    // Analogous — harmonious neighboring hues
    ColorSchemePreset(
      id: 'ocean_breeze',
      name: 'Ocean Breeze',
      category: 'Analogous',
      seedColor: Color(0xFF0277BD),
      description: 'Cool, calming blues from sky to sea',
    ),
    ColorSchemePreset(
      id: 'sunset_warmth',
      name: 'Sunset Warmth',
      category: 'Analogous',
      seedColor: Color(0xFFD84315),
      description: 'Warm oranges and reds like a setting sun',
    ),
    ColorSchemePreset(
      id: 'forest_fresh',
      name: 'Forest Fresh',
      category: 'Analogous',
      seedColor: Color(0xFF2E7D32),
      description: 'Fresh greens from leaf to moss',
    ),
    ColorSchemePreset(
      id: 'lavender_garden',
      name: 'Lavender Garden',
      category: 'Analogous',
      seedColor: Color(0xFF7B1FA2),
      description: 'Soft purples from lavender to violet',
    ),

    // Triadic — three evenly spaced hues
    ColorSchemePreset(
      id: 'primary_bold',
      name: 'Primary Bold',
      category: 'Triadic',
      seedColor: Color(0xFF1565C0),
      description: 'Balanced red, yellow, and blue triad',
    ),
    ColorSchemePreset(
      id: 'secondary_vibrant',
      name: 'Secondary Vibrant',
      category: 'Triadic',
      seedColor: Color(0xFF6A1B9A),
      description: 'Purple, green, and orange variety',
    ),
    ColorSchemePreset(
      id: 'spring_triad',
      name: 'Spring Triad',
      category: 'Triadic',
      seedColor: Color(0xFF2E7D32),
      description: 'Green, orange, and violet spring palette',
    ),

    // Monochromatic — single hue depth
    ColorSchemePreset(
      id: 'indigo_depth',
      name: 'Indigo Depth',
      category: 'Monochromatic',
      seedColor: Color(0xFF1A237E),
      description: 'Elegant indigo shades from deep to light',
    ),
    ColorSchemePreset(
      id: 'teal_calm',
      name: 'Teal Calm',
      category: 'Monochromatic',
      seedColor: Color(0xFF00695C),
      description: 'Sophisticated teal tones',
    ),
    ColorSchemePreset(
      id: 'purple_royal',
      name: 'Purple Royal',
      category: 'Monochromatic',
      seedColor: Color(0xFF4527A0),
      description: 'Rich purple palette',
    ),
  ];

  static ColorSchemePreset getById(String id) {
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets.firstWhere((p) => p.id == 'indigo_depth'),
    );
  }

  static List<ColorSchemePreset> getByCategory(String category) {
    return presets.where((p) => p.category == category).toList();
  }

  static const List<String> categories = [
    'Complementary',
    'Analogous',
    'Triadic',
    'Monochromatic',
  ];
}
