import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Marker written into every backup envelope so foreign files are rejected.
const backupFormatId = 'cycle-compass-backup';

/// Envelope version this app writes, and the newest one it can read.
const backupFormatVersion = 1;

/// Iterations used when deriving a key from a passphrase.
const backupKdfIterations = 210000;

const _kdfAlgorithm = 'pbkdf2-hmac-sha256';
const _cipherAlgorithm = 'aes-256-gcm';
const _saltLength = 16;
const _nonceLength = 12;
const _maxKdfIterations = 2000000;
const _protectionValues = {'protected', 'unprotected'};
const _ovulationTestValues = {'positive', 'negative'};
const _lifeStageValues = {'pregnancy', 'postpartum', 'breastfeeding'};
const _themeModeValues = {'system', 'light', 'dark'};

const _notABackup = 'This file is not a Cycle Compass backup.';
const _damaged =
    'This backup file is incomplete or damaged, so nothing was changed.';
const _tooNew =
    'This backup was created by a newer app version. Update Cycle Compass '
    'and try again.';

/// Everything stored on the device, as raw table rows.
///
/// Rows mirror the SQLite column names so they can be written back without
/// another translation step.
class BackupData {
  const BackupData({
    this.profile,
    this.periodEntries = const [],
    this.dailyLogs = const [],
    this.lifeStageEntries = const [],
  });

  final Map<String, Object?>? profile;
  final List<Map<String, Object?>> periodEntries;
  final List<Map<String, Object?>> dailyLogs;
  final List<Map<String, Object?>> lifeStageEntries;

  Map<String, Object?> toJson() => {
    'profile': profile,
    'periodEntries': periodEntries,
    'dailyLogs': dailyLogs,
    'lifeStageEntries': lifeStageEntries,
  };
}

/// A validated backup: when it was written, plus the data it carries.
class BackupPayload {
  const BackupPayload({required this.exportedAt, required this.data});

  final DateTime exportedAt;
  final BackupData data;
}

/// The readable part of a backup file, before any decryption happens.
///
/// Reading the envelope tells the app whether a passphrase is needed and which
/// date to show in the restore confirmation.
class BackupEnvelope {
  const BackupEnvelope._(
    this._fields, {
    required this.exportedAt,
    required this.isEncrypted,
  });

  final DateTime exportedAt;
  final bool isEncrypted;
  final Map<String, Object?> _fields;
}

/// Base class for backup problems that carry a message meant for the user.
sealed class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The file is not a backup, is damaged, or comes from a newer app version.
class BackupFormatException extends BackupException {
  const BackupFormatException(super.message);
}

/// The passphrase did not open the backup, or the file was altered.
///
/// AES-GCM cannot tell those two cases apart, so they share one message.
class BackupPassphraseException extends BackupException {
  const BackupPassphraseException([
    super.message =
        'That passphrase did not open the backup. Check it and try again.',
  ]);
}

/// Reads and writes the `.ccbackup` envelope. Pure Dart, so it is unit-testable.
class BackupCodec {
  const BackupCodec();

  /// Encodes [payload] without encryption.
  String encode(BackupPayload payload) => jsonEncode({
    ..._header(payload, encrypted: false),
    'data': payload.data.toJson(),
  });

  /// Encodes [payload] with an AES-256-GCM key derived from [passphrase].
  ///
  /// The GCM authentication tag is stored base64 in a separate `mac` field, so
  /// `ciphertext` holds the encrypted bytes only.
  Future<String> encodeEncrypted(
    BackupPayload payload, {
    required String passphrase,
  }) async {
    if (passphrase.isEmpty) {
      throw ArgumentError.value(
        passphrase,
        'passphrase',
        'A passphrase is required to encrypt a backup.',
      );
    }
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final secretKey = await _deriveKey(
      passphrase: passphrase,
      salt: salt,
      iterations: backupKdfIterations,
    );
    final secretBox = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(payload.data.toJson())),
      secretKey: secretKey,
      nonce: nonce,
    );
    return jsonEncode({
      ..._header(payload, encrypted: true),
      'kdf': {
        'algorithm': _kdfAlgorithm,
        'iterations': backupKdfIterations,
        'salt': base64Encode(salt),
      },
      'cipher': {'algorithm': _cipherAlgorithm, 'nonce': base64Encode(nonce)},
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
  }

  /// Validates the envelope of [source] without touching its data.
  ///
  /// Throws [BackupFormatException] when the file is not a readable backup.
  BackupEnvelope readEnvelope(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const BackupFormatException(_notABackup);
    }
    if (decoded is! Map<String, Object?> ||
        decoded['format'] != backupFormatId) {
      throw const BackupFormatException(_notABackup);
    }
    final version = decoded['version'];
    if (version is! int) throw const BackupFormatException(_damaged);
    if (version > backupFormatVersion) {
      throw const BackupFormatException(_tooNew);
    }
    final encrypted = decoded['encrypted'];
    if (encrypted is! bool) throw const BackupFormatException(_damaged);
    final exportedAt = DateTime.tryParse(
      decoded['exportedAt'] is String ? decoded['exportedAt']! as String : '',
    );
    if (exportedAt == null) throw const BackupFormatException(_damaged);
    return BackupEnvelope._(
      decoded,
      exportedAt: exportedAt,
      isEncrypted: encrypted,
    );
  }

  /// Fully validates [envelope] and returns the data it carries.
  ///
  /// [passphrase] is required when [BackupEnvelope.isEncrypted] is true. No
  /// data is returned unless every row passed validation, so callers can write
  /// the result without risking a half-finished restore.
  Future<BackupPayload> open(
    BackupEnvelope envelope, {
    String? passphrase,
  }) async {
    if (!envelope.isEncrypted) {
      return BackupPayload(
        exportedAt: envelope.exportedAt,
        data: _readData(envelope._fields['data']),
      );
    }
    if (passphrase == null || passphrase.isEmpty) {
      throw const BackupPassphraseException(
        'This backup is encrypted. Enter its passphrase to continue.',
      );
    }
    final kdf = _readMap(envelope._fields['kdf'], _damaged);
    final cipher = _readMap(envelope._fields['cipher'], _damaged);
    if (kdf['algorithm'] != _kdfAlgorithm ||
        cipher['algorithm'] != _cipherAlgorithm) {
      throw const BackupFormatException(
        'This backup uses an encryption method Cycle Compass cannot read.',
      );
    }
    final iterations = kdf['iterations'];
    if (iterations is! int ||
        iterations < 1 ||
        iterations > _maxKdfIterations) {
      throw const BackupFormatException(_damaged);
    }
    final salt = _readBytes(kdf['salt']);
    final nonce = _readBytes(cipher['nonce']);
    final cipherText = _readBytes(envelope._fields['ciphertext']);
    final mac = _readBytes(envelope._fields['mac']);
    final secretKey = await _deriveKey(
      passphrase: passphrase,
      salt: salt,
      iterations: iterations,
    );
    final List<int> clearText;
    try {
      clearText = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
      );
    } on SecretBoxAuthenticationError {
      throw const BackupPassphraseException();
    } on ArgumentError {
      throw const BackupFormatException(_damaged);
    }
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(clearText));
    } on FormatException {
      throw const BackupFormatException(_damaged);
    }
    return BackupPayload(
      exportedAt: envelope.exportedAt,
      data: _readData(data),
    );
  }

  Map<String, Object?> _header(
    BackupPayload payload, {
    required bool encrypted,
  }) => {
    'format': backupFormatId,
    'version': backupFormatVersion,
    'encrypted': encrypted,
    'exportedAt': payload.exportedAt.toIso8601String(),
  };

  Future<SecretKey> _deriveKey({
    required String passphrase,
    required List<int> salt,
    required int iterations,
  }) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: passphrase, nonce: salt);
}

final _random = Random.secure();

Uint8List _randomBytes(int length) => Uint8List.fromList(
  List<int>.generate(length, (_) => _random.nextInt(256), growable: false),
);

BackupData _readData(Object? value) {
  final data = _readMap(value, _damaged);
  final profile = data['profile'];
  final periodEntries = _readRows(data['periodEntries'], _readPeriodRow);
  final dailyLogs = _readRows(data['dailyLogs'], _readDailyLogRow);
  final lifeStageEntries = _readRows(
    data['lifeStageEntries'],
    _readLifeStageRow,
  );
  _requireUnique(periodEntries, 'start_date');
  _requireUnique(periodEntries, 'id');
  _requireUnique(dailyLogs, 'log_date');
  _requireUnique(lifeStageEntries, 'id');
  return BackupData(
    profile: profile == null ? null : _readProfileRow(profile),
    periodEntries: periodEntries,
    dailyLogs: dailyLogs,
    lifeStageEntries: lifeStageEntries,
  );
}

/// Keeps only known columns, in the order the tables declare them, so an
/// altered file cannot smuggle unexpected fields into the database.
Map<String, Object?> _readProfileRow(Object? value) {
  final row = _readMap(value, _damaged);
  return {
    'id': 1,
    'name': _requiredString(row, 'name'),
    'date_of_birth': _requiredDate(row, 'date_of_birth'),
    'avatar_path': _optionalString(row, 'avatar_path'),
    'last_period_start': _requiredDate(row, 'last_period_start'),
    'cycle_length': _requiredInt(row, 'cycle_length'),
    'period_length': _requiredInt(row, 'period_length'),
    'is_pregnant': _flag(row, 'is_pregnant'),
    'pregnancy_started_on': _optionalDate(row, 'pregnancy_started_on'),
    'due_date': _optionalDate(row, 'due_date'),
    // Kept so backups written before the manual due date was removed still
    // restore. The column is no longer read by the app.
    'next_period_due_date': _optionalDate(row, 'next_period_due_date'),
    'baby_born_on': _optionalDate(row, 'baby_born_on'),
    'postpartum_started_on': _optionalDate(row, 'postpartum_started_on'),
    'postpartum_ended_on': _optionalDate(row, 'postpartum_ended_on'),
    'breastfeeding_started_on': _optionalDate(row, 'breastfeeding_started_on'),
    'notifications_enabled': _flag(row, 'notifications_enabled', fallback: 1),
    'theme_mode':
        _optionalChoice(row, 'theme_mode', _themeModeValues) ?? 'system',
  };
}

Map<String, Object?> _readPeriodRow(Map<String, Object?> row) => {
  if (row['id'] != null) 'id': _requiredInt(row, 'id'),
  'start_date': _requiredDate(row, 'start_date'),
  'end_date': _optionalDate(row, 'end_date'),
  'source': _optionalString(row, 'source') ?? 'user',
};

Map<String, Object?> _readDailyLogRow(Map<String, Object?> row) => {
  'log_date': _requiredDate(row, 'log_date'),
  'flow': _optionalInt(row, 'flow'),
  'pain': _optionalInt(row, 'pain'),
  'mood': _optionalInt(row, 'mood'),
  'energy': _optionalInt(row, 'energy'),
  'note': _optionalString(row, 'note'),
  'intercourse_protection': _optionalChoice(
    row,
    'intercourse_protection',
    _protectionValues,
  ),
  'ovulation_test': _optionalChoice(
    row,
    'ovulation_test',
    _ovulationTestValues,
  ),
};

Map<String, Object?> _readLifeStageRow(Map<String, Object?> row) => {
  if (row['id'] != null) 'id': _requiredInt(row, 'id'),
  'stage_type': _requiredChoice(row, 'stage_type', _lifeStageValues),
  'start_date': _requiredDate(row, 'start_date'),
  'end_date': _requiredDate(row, 'end_date'),
};

List<Map<String, Object?>> _readRows(
  Object? value,
  Map<String, Object?> Function(Map<String, Object?> row) read,
) {
  if (value is! List) throw const BackupFormatException(_damaged);
  return value
      .map((row) => read(_readMap(row, _damaged)))
      .toList(growable: false);
}

Map<String, Object?> _readMap(Object? value, String message) =>
    value is Map<String, Object?>
    ? value
    : throw BackupFormatException(message);

Uint8List _readBytes(Object? value) {
  if (value is! String) throw const BackupFormatException(_damaged);
  try {
    return base64Decode(value);
  } on FormatException {
    throw const BackupFormatException(_damaged);
  }
}

String _requiredString(Map<String, Object?> row, String column) =>
    row[column] is String
    ? row[column]! as String
    : throw const BackupFormatException(_damaged);

String? _optionalString(Map<String, Object?> row, String column) =>
    row[column] == null ? null : _requiredString(row, column);

int _requiredInt(Map<String, Object?> row, String column) => row[column] is int
    ? row[column]! as int
    : throw const BackupFormatException(_damaged);

int? _optionalInt(Map<String, Object?> row, String column) =>
    row[column] == null ? null : _requiredInt(row, column);

String _requiredDate(Map<String, Object?> row, String column) {
  final value = _requiredString(row, column);
  if (DateTime.tryParse(value) == null) {
    throw const BackupFormatException(_damaged);
  }
  return value;
}

String? _optionalDate(Map<String, Object?> row, String column) =>
    row[column] == null ? null : _requiredDate(row, column);

String _requiredChoice(
  Map<String, Object?> row,
  String column,
  Set<String> allowed,
) {
  final value = _requiredString(row, column);
  if (!allowed.contains(value)) {
    throw const BackupFormatException(_damaged);
  }
  return value;
}

String? _optionalChoice(
  Map<String, Object?> row,
  String column,
  Set<String> allowed,
) => row[column] == null ? null : _requiredChoice(row, column, allowed);

int _flag(Map<String, Object?> row, String column, {int fallback = 0}) =>
    switch (row[column]) {
      null => fallback,
      final bool value => value ? 1 : 0,
      0 => 0,
      1 => 1,
      _ => throw const BackupFormatException(_damaged),
    };

void _requireUnique(List<Map<String, Object?>> rows, String column) {
  final seen = <Object?>{};
  for (final row in rows) {
    final value = row[column];
    if (value == null) continue;
    if (!seen.add(value)) throw const BackupFormatException(_damaged);
  }
}
