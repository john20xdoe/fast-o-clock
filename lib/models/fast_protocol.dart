class FastProtocol {
  final String id;
  final String label;
  final int targetDurationMin;
  final String description;

  const FastProtocol({
    required this.id,
    required this.label,
    required this.targetDurationMin,
    required this.description,
  });

  static const List<FastProtocol> presets = [
    FastProtocol(
      id: '14_10',
      label: '14:10',
      targetDurationMin: 14 * 60,
      description: '14h fast, 10h eating window — gentle daily rhythm.',
    ),
    FastProtocol(
      id: '16_8',
      label: '16:8',
      targetDurationMin: 16 * 60,
      description: '16h fast, 8h eating window — classic Leangains default.',
    ),
    FastProtocol(
      id: '18_6',
      label: '18:6',
      targetDurationMin: 18 * 60,
      description: '18h fast, 6h eating window — deeper fat burning.',
    ),
    FastProtocol(
      id: '20_4',
      label: '20:4',
      targetDurationMin: 20 * 60,
      description: '20h fast, 4h eating window — Warrior style.',
    ),
    FastProtocol(
      id: '23_1',
      label: '23:1 (OMAD)',
      targetDurationMin: 23 * 60,
      description: 'One Meal a Day — 23h fast, 1h meal window.',
    ),
    FastProtocol(
      id: '36_0',
      label: '36h (Monk)',
      targetDurationMin: 36 * 60,
      description: 'Extended 36-hour fast for deep autophagy.',
    ),
  ];

  static FastProtocol custom(int durationMinutes) {
    final clamped = durationMinutes.clamp(60, 10080);
    final hours = clamped ~/ 60;
    final mins = clamped % 60;
    final durLabel = mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
    return FastProtocol(
      id: 'custom',
      label: 'Custom ($durLabel)',
      targetDurationMin: clamped,
      description: 'Custom fasting target of $durLabel.',
    );
  }

  static FastProtocol resolve(String id, {int customDurationMin = 960}) {
    if (id == 'custom') {
      return custom(customDurationMin);
    }
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return presets[1]; // 16_8 default
  }
}
