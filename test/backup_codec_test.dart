import 'dart:convert';

import 'package:cycle_compass/services/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = BackupCodec();
  final exportedAt = DateTime(2026, 8, 19, 9, 30);
  final payload = BackupPayload(
    exportedAt: exportedAt,
    data: const BackupData(
      profile: {
        'id': 1,
        'name': 'Nadia Rahman',
        'date_of_birth': '1997-04-16',
        'avatar_path': null,
        'last_period_start': '2026-08-01',
        'cycle_length': 28,
        'period_length': 5,
        'is_pregnant': 0,
        'pregnancy_started_on': null,
        'due_date': null,
        'next_period_due_date': '2026-08-29',
        'postpartum_started_on': null,
        'postpartum_ended_on': null,
        'notifications_enabled': 1,
      },
      periodEntries: [
        {
          'id': 1,
          'start_date': '2026-07-04',
          'end_date': null,
          'source': 'user',
        },
        {
          'id': 2,
          'start_date': '2026-08-01',
          'end_date': '2026-08-05',
          'source': 'user',
        },
      ],
      dailyLogs: [
        {
          'log_date': '2026-08-03',
          'flow': 2,
          'pain': 1,
          'mood': 3,
          'energy': 2,
          'note': 'Slept well',
          'intercourse_protection': 'protected',
        },
      ],
      lifeStageEntries: [
        {
          'id': 1,
          'stage_type': 'pregnancy',
          'start_date': '2023-01-10',
          'end_date': '2023-10-12',
        },
      ],
    ),
  );

  group('plain backups', () {
    test('round-trips every table', () async {
      final envelope = codec.readEnvelope(codec.encode(payload));
      expect(envelope.isEncrypted, isFalse);
      expect(envelope.exportedAt, exportedAt);

      final restored = await codec.open(envelope);
      expect(restored.exportedAt, exportedAt);
      expect(restored.data.profile, payload.data.profile);
      expect(restored.data.periodEntries, payload.data.periodEntries);
      expect(restored.data.dailyLogs, payload.data.dailyLogs);
      expect(restored.data.lifeStageEntries, payload.data.lifeStageEntries);
    });

    test('writes the documented envelope header', () {
      final envelope =
          jsonDecode(codec.encode(payload)) as Map<String, Object?>;
      expect(envelope['format'], 'cycle-compass-backup');
      expect(envelope['version'], 1);
      expect(envelope['encrypted'], isFalse);
      expect(envelope['exportedAt'], exportedAt.toIso8601String());
      expect(envelope['data'], isA<Map<String, Object?>>());
    });
  });

  group('encrypted backups', () {
    test('round-trips with the right passphrase', () async {
      final file = await codec.encodeEncrypted(
        payload,
        passphrase: 'correct horse',
      );
      final fields = jsonDecode(file) as Map<String, Object?>;
      expect(fields['encrypted'], isTrue);
      expect(fields['data'], isNull);
      expect((fields['kdf']! as Map)['iterations'], backupKdfIterations);
      expect((fields['kdf']! as Map)['algorithm'], 'pbkdf2-hmac-sha256');
      expect((fields['cipher']! as Map)['algorithm'], 'aes-256-gcm');
      expect(base64Decode(fields['mac']! as String), hasLength(16));

      final envelope = codec.readEnvelope(file);
      expect(envelope.isEncrypted, isTrue);
      final restored = await codec.open(envelope, passphrase: 'correct horse');
      expect(restored.data.profile, payload.data.profile);
      expect(restored.data.periodEntries, payload.data.periodEntries);
      expect(restored.data.dailyLogs, payload.data.dailyLogs);
      expect(restored.data.lifeStageEntries, payload.data.lifeStageEntries);
    });

    test('salt and nonce differ between exports', () async {
      final first =
          jsonDecode(await codec.encodeEncrypted(payload, passphrase: 'secret'))
              as Map<String, Object?>;
      final second =
          jsonDecode(await codec.encodeEncrypted(payload, passphrase: 'secret'))
              as Map<String, Object?>;
      expect(
        (first['kdf']! as Map)['salt'],
        isNot((second['kdf']! as Map)['salt']),
      );
      expect(
        (first['cipher']! as Map)['nonce'],
        isNot((second['cipher']! as Map)['nonce']),
      );
    });

    test('a wrong passphrase fails without exposing data', () async {
      final envelope = codec.readEnvelope(
        await codec.encodeEncrypted(payload, passphrase: 'secret one'),
      );

      await expectLater(
        codec.open(envelope, passphrase: 'secret two'),
        throwsA(isA<BackupPassphraseException>()),
      );
    });

    test('a missing passphrase is reported, not guessed', () async {
      final envelope = codec.readEnvelope(
        await codec.encodeEncrypted(payload, passphrase: 'secret one'),
      );

      await expectLater(
        codec.open(envelope),
        throwsA(isA<BackupPassphraseException>()),
      );
    });

    test('tampered ciphertext is rejected', () async {
      final fields =
          jsonDecode(await codec.encodeEncrypted(payload, passphrase: 'secret'))
              as Map<String, Object?>;
      final cipherText = base64Decode(fields['ciphertext']! as String);
      cipherText[0] ^= 0xFF;
      fields['ciphertext'] = base64Encode(cipherText);

      await expectLater(
        codec.open(
          codec.readEnvelope(jsonEncode(fields)),
          passphrase: 'secret',
        ),
        throwsA(isA<BackupPassphraseException>()),
      );
    });
  });

  group('invalid files', () {
    test('malformed JSON is rejected', () {
      expect(
        () => codec.readEnvelope('not json at all'),
        throwsA(
          isA<BackupFormatException>().having(
            (error) => error.message,
            'message',
            contains('not a Cycle Compass backup'),
          ),
        ),
      );
    });

    test('another app\'s JSON file is rejected', () {
      expect(
        () => codec.readEnvelope('{"format":"other-app","version":1}'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('a newer envelope version is rejected with an update hint', () {
      final fields = jsonDecode(codec.encode(payload)) as Map<String, Object?>;
      fields['version'] = backupFormatVersion + 1;

      expect(
        () => codec.readEnvelope(jsonEncode(fields)),
        throwsA(
          isA<BackupFormatException>().having(
            (error) => error.message,
            'message',
            contains('newer app version'),
          ),
        ),
      );
    });

    test('a structurally invalid data object is rejected', () async {
      final fields = jsonDecode(codec.encode(payload)) as Map<String, Object?>;
      (fields['data']! as Map<String, Object?>)['periodEntries'] = [
        {'start_date': 'not-a-date'},
      ];

      await expectLater(
        codec.open(codec.readEnvelope(jsonEncode(fields))),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('unknown enum values are rejected', () async {
      final fields = jsonDecode(codec.encode(payload)) as Map<String, Object?>;
      (fields['data']! as Map<String, Object?>)['dailyLogs'] = [
        {'log_date': '2026-08-03', 'intercourse_protection': 'unknown'},
      ];

      await expectLater(
        codec.open(codec.readEnvelope(jsonEncode(fields))),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('missing tables are rejected', () async {
      final fields = jsonDecode(codec.encode(payload)) as Map<String, Object?>;
      (fields['data']! as Map<String, Object?>).remove('dailyLogs');

      await expectLater(
        codec.open(codec.readEnvelope(jsonEncode(fields))),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('duplicate period start dates are rejected', () async {
      final fields = jsonDecode(codec.encode(payload)) as Map<String, Object?>;
      (fields['data']! as Map<String, Object?>)['periodEntries'] = [
        {'start_date': '2026-08-01'},
        {'start_date': '2026-08-01'},
      ];

      await expectLater(
        codec.open(codec.readEnvelope(jsonEncode(fields))),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('unknown columns are dropped instead of restored', () async {
      final fields = jsonDecode(codec.encode(payload)) as Map<String, Object?>;
      (fields['data']! as Map<String, Object?>)['periodEntries'] = [
        {'start_date': '2026-08-01', 'sneaky_column': 'drop me'},
      ];

      final restored = await codec.open(codec.readEnvelope(jsonEncode(fields)));
      expect(
        restored.data.periodEntries.single.containsKey('sneaky_column'),
        isFalse,
      );
      expect(restored.data.periodEntries.single['source'], 'user');
    });
  });
}
