import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_codec.dart';
import 'clock.dart';

/// File and platform-channel side of backups.
///
/// Everything that talks to Android lives here so [BackupCodec] stays a plain
/// Dart unit that tests can exercise without a device.
class BackupService {
  const BackupService();

  /// Name used for exported files, for example `cycle-compass-2026-08-19`.
  String fileNameFor([DateTime? date]) =>
      'cycle-compass-${_dateOnly(date ?? appNow())}.ccbackup';

  /// Writes [contents] to a temporary file and hands it to the share sheet.
  Future<void> shareBackup(String contents) async {
    final directory = await getTemporaryDirectory();
    final fileName = fileNameFor();
    final file = File(p.join(directory.path, fileName));
    await file.writeAsString(contents, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, name: fileName, mimeType: 'application/json')],
        fileNameOverrides: [fileName],
        subject: 'Cycle Compass backup',
      ),
    );
  }

  /// Opens the system file picker and returns the picked file as text.
  ///
  /// Returns null when the picker is dismissed. Android's document picker
  /// often cannot filter a custom extension, so any file can be chosen and the
  /// codec decides whether it is a backup.
  Future<String?> readPickedBackup() async {
    final picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const BackupFormatException(
        'This file is not a Cycle Compass backup.',
      );
    }
  }
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
