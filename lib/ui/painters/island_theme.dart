import 'package:flutter/material.dart';

/// Palette and scenery style for one island. The island painter draws the
/// same restorable elements on every island; the theme gives each its own
/// look (meadow, volcano, lagoon, crystal peaks, shadow sky).
class IslandTheme {
  const IslandTheme({
    required this.sky,
    required this.glow,
    required this.rock,
    required this.lip,
    required this.groundRuined,
    required this.groundHealthy,
    required this.rimRuined,
    required this.rimHealthy,
    required this.bank,
    required this.river,
    required this.leafRuined,
    required this.leafHealthy,
    required this.trunk,
    required this.treeStyle,
    required this.crystals,
    required this.overlay,
    required this.overlayStyle,
    required this.ambient,
    required this.roofs,
    required this.flowers,
    required this.path,
    this.lavaRiver = false,
  });

  /// Tint behind the island (top, bottom); transparent keeps the app sky.
  final List<Color> sky;
  final Color glow;

  /// Underside gradient, top to bottom.
  final List<Color> rock;
  final List<Color> lip;

  /// Top surface gradient (top, bottom) when ruined and when restored.
  final List<Color> groundRuined;
  final List<Color> groundHealthy;
  final Color rimRuined;
  final Color rimHealthy;
  final Color bank;
  final List<Color> river;

  /// Foliage (light, dark) when ruined and restored.
  final List<Color> leafRuined;
  final List<Color> leafHealthy;
  final Color trunk;

  /// round, palm, ember, crystal, shadow.
  final String treeStyle;
  final List<Color> crystals;

  /// Color of the "ruined" overlay removed by the first task.
  final Color overlay;

  /// vines, lava, kelp, ice, brambles.
  final String overlayStyle;

  /// fireflies, embers, bubbles, snow, stars.
  final String ambient;

  /// Roof colors for tower, well and shed.
  final List<Color> roofs;
  final List<Color> flowers;
  final Color path;

  /// The river is molten lava (glows, no glints).
  final bool lavaRiver;

  static IslandTheme of(String id) => switch (id) {
    'volcano' => volcano,
    'lagoon' => lagoon,
    'crystal' => crystal,
    'shadow' => shadow,
    _ => meadow,
  };

  static const meadow = IslandTheme(
    sky: [Color(0x00000000), Color(0x00000000)],
    glow: Color(0xFFFFF6D6),
    rock: [Color(0xFFB88E68), Color(0xFF7D5C45), Color(0xFF4B3830)],
    lip: [Color(0xFFA57B55), Color(0xFF7E5B40)],
    groundRuined: [Color(0xFFCFD08F), Color(0xFF9FA162)],
    groundHealthy: [Color(0xFFB4EA86), Color(0xFF6EC15A)],
    rimRuined: Color(0xFF8C8A55),
    rimHealthy: Color(0xFF55A845),
    bank: Color(0xFFD9C49A),
    river: [Color(0xFF5BB8EE), Color(0xFF86D8FA)],
    leafRuined: [Color(0xFFB5A77A), Color(0xFF7F7450)],
    leafHealthy: [Color(0xFF8EDB6A), Color(0xFF3F9A4B)],
    trunk: Color(0xFF7A5234),
    treeStyle: 'round',
    crystals: [Color(0xFF8FE3FF), Color(0xFFD7A6FF), Color(0xFF9DF5C4)],
    overlay: Color(0xFF4E5F2E),
    overlayStyle: 'vines',
    ambient: 'fireflies',
    roofs: [Color(0xFF5C7CFA), Color(0xFFE57373), Color(0xFFD9534F)],
    flowers: [
      Color(0xFFFF7EB6),
      Color(0xFFFFE066),
      Colors.white,
      Color(0xFFB39DFF),
    ],
    path: Color(0xFFE8DCC6),
  );

  static const volcano = IslandTheme(
    sky: [Color(0x55FF9A5C), Color(0x22FF5C5C)],
    glow: Color(0xFFFFC08A),
    rock: [Color(0xFF6B4A44), Color(0xFF402A2A), Color(0xFF1F1414)],
    lip: [Color(0xFF5A3C36), Color(0xFF3A2622)],
    groundRuined: [Color(0xFF7A6660), Color(0xFF55443F)],
    groundHealthy: [Color(0xFFB9C77A), Color(0xFF7C9A4F)],
    rimRuined: Color(0xFF4A3834),
    rimHealthy: Color(0xFF6E8A45),
    bank: Color(0xFF3A2A28),
    river: [Color(0xFFFF6A1A), Color(0xFFFFC23D)],
    leafRuined: [Color(0xFF6B5B55), Color(0xFF3F3330)],
    leafHealthy: [Color(0xFFFFA24D), Color(0xFFD9482B)],
    trunk: Color(0xFF3A2622),
    treeStyle: 'ember',
    crystals: [Color(0xFFFF8A3D), Color(0xFFFFD166), Color(0xFFFF5C5C)],
    overlay: Color(0xFFFF6A1A),
    overlayStyle: 'lava',
    ambient: 'embers',
    roofs: [Color(0xFFC0392B), Color(0xFF8E3B2E), Color(0xFFB0413E)],
    flowers: [
      Color(0xFFFF8A3D),
      Color(0xFFFFD166),
      Color(0xFFFF5C5C),
      Color(0xFFFFF1C1),
    ],
    path: Color(0xFF8C7A76),
    lavaRiver: true,
  );

  static const lagoon = IslandTheme(
    sky: [Color(0x4460E0E8), Color(0x224FC3F7)],
    glow: Color(0xFFD6FFF8),
    rock: [Color(0xFFE39A8A), Color(0xFFB0675C), Color(0xFF6B3F3A)],
    lip: [Color(0xFFE7C98F), Color(0xFFC7A36A)],
    groundRuined: [Color(0xFFD9CFA6), Color(0xFFBDB083)],
    groundHealthy: [Color(0xFFFFEFB8), Color(0xFFF1D58B)],
    rimRuined: Color(0xFFA89A70),
    rimHealthy: Color(0xFF4FC3A9),
    bank: Color(0xFFFFF4D6),
    river: [Color(0xFF26C6DA), Color(0xFF80DEEA)],
    leafRuined: [Color(0xFFA9A77A), Color(0xFF7C7A55)],
    leafHealthy: [Color(0xFF7EE08A), Color(0xFF2E9E6B)],
    trunk: Color(0xFFA4784F),
    treeStyle: 'palm',
    crystals: [Color(0xFFFF8FAB), Color(0xFF80DEEA), Color(0xFFFFFFFF)],
    overlay: Color(0xFF3F6B3A),
    overlayStyle: 'kelp',
    ambient: 'bubbles',
    roofs: [Color(0xFFEF5350), Color(0xFF26A69A), Color(0xFF42A5F5)],
    flowers: [
      Color(0xFFFF8FAB),
      Color(0xFFFFB74D),
      Color(0xFF80DEEA),
      Colors.white,
    ],
    path: Color(0xFFFFF8E7),
  );

  static const crystal = IslandTheme(
    sky: [Color(0x44B39DFF), Color(0x2280DEEA)],
    glow: Color(0xFFE8F4FF),
    rock: [Color(0xFFA9A3C9), Color(0xFF7C75A8), Color(0xFF4A4570)],
    lip: [Color(0xFF9E98C4), Color(0xFF6E6899)],
    groundRuined: [Color(0xFFB9C4D6), Color(0xFF94A0B8)],
    groundHealthy: [Color(0xFFF2F8FF), Color(0xFFCFE0F5)],
    rimRuined: Color(0xFF8A95AD),
    rimHealthy: Color(0xFFA7C8F0),
    bank: Color(0xFFE3ECF8),
    river: [Color(0xFF7FC8FF), Color(0xFFD6F0FF)],
    leafRuined: [Color(0xFFA0A8BC), Color(0xFF7A8298)],
    leafHealthy: [Color(0xFFB7F0FF), Color(0xFFB39DFF)],
    trunk: Color(0xFF8C8FB5),
    treeStyle: 'crystal',
    crystals: [Color(0xFF80DEEA), Color(0xFFD7A6FF), Color(0xFFFFFFFF)],
    overlay: Color(0xFFE8F4FF),
    overlayStyle: 'ice',
    ambient: 'snow',
    roofs: [Color(0xFF7E57C2), Color(0xFF5C6BC0), Color(0xFF26C6DA)],
    flowers: [
      Color(0xFF80DEEA),
      Colors.white,
      Color(0xFFD7A6FF),
      Color(0xFFB3E5FC),
    ],
    path: Color(0xFFFFFFFF),
  );

  static const shadow = IslandTheme(
    sky: [Color(0x88231A45), Color(0x444A3B7A)],
    glow: Color(0xFFB39DFF),
    rock: [Color(0xFF3A2E5C), Color(0xFF251C40), Color(0xFF120C24)],
    lip: [Color(0xFF2E2450), Color(0xFF1C1535)],
    groundRuined: [Color(0xFF4A4263), Color(0xFF322B48)],
    groundHealthy: [Color(0xFF7C6CC4), Color(0xFF4E3F96)],
    rimRuined: Color(0xFF2A2340),
    rimHealthy: Color(0xFF6E5CC8),
    bank: Color(0xFF2A2145),
    river: [Color(0xFF3F51B5), Color(0xFF9FA8DA)],
    leafRuined: [Color(0xFF4E4666), Color(0xFF302A42)],
    leafHealthy: [Color(0xFF80F5E0), Color(0xFFB388FF)],
    trunk: Color(0xFF2A2145),
    treeStyle: 'shadow',
    crystals: [Color(0xFFB388FF), Color(0xFF80F5E0), Color(0xFFFF8AD8)],
    overlay: Color(0xFF1A1030),
    overlayStyle: 'brambles',
    ambient: 'stars',
    roofs: [Color(0xFF4A3B7A), Color(0xFF6A4FB0), Color(0xFF3949AB)],
    flowers: [
      Color(0xFF80F5E0),
      Color(0xFFFF8AD8),
      Color(0xFFB388FF),
      Color(0xFFFFF59D),
    ],
    path: Color(0xFF8C82B8),
  );
}
