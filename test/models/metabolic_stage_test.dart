import 'package:fast_oclock/models/metabolic_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MetabolicStage', () {
    test('maps elapsed hours to expected stage boundaries', () {
      expect(
        MetabolicStage.forElapsedDuration(const Duration(hours: 0)).id,
        'blood_sugar_rise',
      );
      expect(
        MetabolicStage.forElapsedDuration(const Duration(hours: 1, minutes: 59))
            .id,
        'blood_sugar_rise',
      );
      expect(
        MetabolicStage.forElapsedDuration(const Duration(hours: 2)).id,
        'blood_sugar_fall',
      );
      expect(
        MetabolicStage.forElapsedDuration(const Duration(hours: 3, minutes: 59))
            .id,
        'blood_sugar_fall',
      );
      expect(
        MetabolicStage.forElapsedDuration(const Duration(hours: 4)).id,
        'post_absorptive',
      );
      expect(
        MetabolicStage.forElapsedDuration(const Duration(hours: 8)).id,
        'fat_burning',
      );
      expect(
        MetabolicStage.forElapsedDuration(const Duration(hours: 12)).id,
        'ketosis',
      );
      expect(
        MetabolicStage.forElapsedDuration(const Duration(hours: 18)).id,
        'autophagy',
      );
      expect(
        MetabolicStage.forElapsedDuration(const Duration(hours: 36)).id,
        'autophagy',
      );
    });
  });
}
