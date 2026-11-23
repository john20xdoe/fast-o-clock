class MetabolicStage {
  final String id;
  final int startHour;
  final int? endHour;
  final String title;
  final String summary;

  const MetabolicStage({
    required this.id,
    required this.startHour,
    this.endHour,
    required this.title,
    required this.summary,
  });

  String get hourRangeLabel =>
      endHour != null ? '${startHour}h – ${endHour}h' : '${startHour}h+';

  static const List<MetabolicStage> stages = [
    MetabolicStage(
      id: 'blood_sugar_rise',
      startHour: 0,
      endHour: 2,
      title: 'Blood Sugar Rises',
      summary:
          'Post-meal digestion; blood glucose and insulin rise as food is absorbed.',
    ),
    MetabolicStage(
      id: 'blood_sugar_fall',
      startHour: 2,
      endHour: 4,
      title: 'Blood Sugar Falls',
      summary:
          'Insulin clears glucose into cells; blood sugar and insulin drop toward baseline.',
    ),
    MetabolicStage(
      id: 'post_absorptive',
      startHour: 4,
      endHour: 8,
      title: 'Glycogen Burn',
      summary:
          'Digestion finishes and insulin drops low; body taps liver glycogen for energy.',
    ),
    MetabolicStage(
      id: 'fat_burning',
      startHour: 8,
      endHour: 12,
      title: 'Fat Burning',
      summary:
          'Liver glycogen depletes; body shifts toward lipolysis to burn fat for fuel.',
    ),
    MetabolicStage(
      id: 'ketosis',
      startHour: 12,
      endHour: 18,
      title: 'Ketosis',
      summary:
          'Fat breakdown accelerates; liver produces ketones as a primary fuel source.',
    ),
    MetabolicStage(
      id: 'autophagy',
      startHour: 18,
      endHour: null,
      title: 'Deep Ketosis & Autophagy',
      summary:
          'Ketone levels rise further while cellular cleanup and recycling ramp up.',
    ),
  ];

  static MetabolicStage forElapsedDuration(Duration elapsed) {
    final hours = elapsed.inSeconds / 3600.0;
    if (hours < 2) return stages[0];
    if (hours < 4) return stages[1];
    if (hours < 8) return stages[2];
    if (hours < 12) return stages[3];
    if (hours < 18) return stages[4];
    return stages[5];
  }
}
