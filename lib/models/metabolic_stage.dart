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
      id: 'fed',
      startHour: 0,
      endHour: 4,
      title: 'Blood Sugar Rise & Fall',
      summary: 'Body digests last meal; insulin levels begin to drop.',
    ),
    MetabolicStage(
      id: 'post_absorptive',
      startHour: 4,
      endHour: 8,
      title: 'Blood Sugar Drop',
      summary: 'Blood glucose normalizes; glycogen reserves begin mobilizing.',
    ),
    MetabolicStage(
      id: 'fat_burning',
      startHour: 8,
      endHour: 12,
      title: 'Fat Burning',
      summary: 'Liver glycogen depletes; body shifts toward lipolysis for energy.',
    ),
    MetabolicStage(
      id: 'ketosis',
      startHour: 12,
      endHour: 18,
      title: 'Ketosis',
      summary: 'Ketone production increases as fat becomes primary fuel source.',
    ),
    MetabolicStage(
      id: 'autophagy',
      startHour: 18,
      endHour: null,
      title: 'Deep Ketosis & Autophagy',
      summary: 'Cellular cleanup and recycling processes accelerate.',
    ),
  ];

  static MetabolicStage forElapsedDuration(Duration elapsed) {
    final hours = elapsed.inSeconds / 3600.0;
    if (hours < 4) return stages[0];
    if (hours < 8) return stages[1];
    if (hours < 12) return stages[2];
    if (hours < 18) return stages[3];
    return stages[4];
  }
}
