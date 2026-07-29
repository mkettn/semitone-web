import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';

import '../models/tuning_scale.dart';

/// Thrown when a scale file can't be read or isn't valid scale JSON.
/// Cancelling the file picker is not an error — that returns null instead.
class ScaleIoException implements Exception {
  ScaleIoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Saves [scale] as a JSON file the user downloads (web) or picks a
/// destination for (desktop/mobile).
Future<void> exportScale(TuningScale scale) async {
  final bytes = Uint8List.fromList(utf8.encode(scale.toJsonString()));
  await FileSaver.instance.saveFile(
    name: _sanitizeFileName(scale.name),
    bytes: bytes,
    fileExtension: 'json',
    mimeType: MimeType.json,
  );
}

/// Lets the user pick a `.json` file and parses it as a [TuningScale].
/// Returns null if the user cancels the picker. The result always has a
/// freshly generated id, so importing never collides with (or silently
/// overwrites) an existing saved scale — including re-importing a scale
/// exported from this same app.
Future<TuningScale?> importScale() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final bytes = result.files.single.bytes;
  if (bytes == null) {
    throw ScaleIoException('Could not read the selected file.');
  }

  try {
    final parsed = TuningScale.fromJsonString(utf8.decode(bytes));
    return TuningScale(
      name: parsed.name,
      degrees: parsed.degrees,
      rootIndex: parsed.rootIndex,
      rootOctave: parsed.rootOctave,
      baseFrequency: parsed.baseFrequency,
    );
  } catch (_) {
    throw ScaleIoException('That file is not a valid scale.');
  }
}

String _sanitizeFileName(String name) {
  final cleaned = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');
  return cleaned.isEmpty ? 'scale' : cleaned;
}
