enum ProtectionStatus { protected, unprotected }

extension ProtectionStatusCopy on ProtectionStatus {
  String get label => switch (this) {
    ProtectionStatus.protected => 'Protected sex',
    ProtectionStatus.unprotected => 'Unprotected sex',
  };

  String get storageValue => switch (this) {
    ProtectionStatus.protected => 'protected',
    ProtectionStatus.unprotected => 'unprotected',
  };
}

ProtectionStatus protectionStatusFromStorage(String storageValue) =>
    switch (storageValue) {
      'protected' => ProtectionStatus.protected,
      'unprotected' => ProtectionStatus.unprotected,
      _ => throw FormatException(
        'Unknown intercourse protection status: $storageValue',
      ),
    };

class IntercourseEntry {
  const IntercourseEntry({required this.date, required this.protectionStatus});

  final DateTime date;
  final ProtectionStatus protectionStatus;
}
