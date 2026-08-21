enum OvulationTestResult { positive, negative }

extension OvulationTestResultCopy on OvulationTestResult {
  String get label => switch (this) {
    OvulationTestResult.positive => 'Positive ovulation test',
    OvulationTestResult.negative => 'Negative ovulation test',
  };

  String get storageValue => switch (this) {
    OvulationTestResult.positive => 'positive',
    OvulationTestResult.negative => 'negative',
  };
}

OvulationTestResult ovulationTestResultFromStorage(String storageValue) =>
    switch (storageValue) {
      'positive' => OvulationTestResult.positive,
      'negative' => OvulationTestResult.negative,
      _ => throw FormatException(
        'Unknown ovulation test result: $storageValue',
      ),
    };

/// One recorded ovulation test result for a single day.
///
/// Test results are kept as a reference next to the calendar estimates; they
/// never feed back into the cycle calculation.
class OvulationTestEntry {
  const OvulationTestEntry({required this.date, required this.result});

  final DateTime date;
  final OvulationTestResult result;
}
