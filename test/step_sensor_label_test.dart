import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/models/metric.dart';
import 'package:openstrap_edge/ui2/screens/home_screen.dart';

void main() {
  test('labels phone and strap provenance without guessing', () {
    expect(
      stepSensorLabel(const Metric(inputsUsed: ['phone_pedometer'])),
      'Phone',
    );
    expect(
      stepSensorLabel(const Metric(inputsUsed: ['band_step_counter'])),
      'Strap',
    );
    expect(
      stepSensorLabel(
        const Metric(inputsUsed: ['phone_pedometer', 'band_pedometer_100hz']),
      ),
      'Strap + phone',
    );
    expect(stepSensorLabel(const Metric()), isNull);
  });
}
