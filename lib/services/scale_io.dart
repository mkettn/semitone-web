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

/// A file the user chose, reduced to the part importing cares about.
/// [bytes] is null when the platform couldn't read the file's contents.
class PickedScaleFile {
  const PickedScaleFile(this.bytes);
  final Uint8List? bytes;
}

/// The file-picking and file-saving surface import/export needs.
///
/// Same reasoning as the audio seams: `FilePicker` and `FileSaver` are
/// static entry points into platform plugins that `flutter test` doesn't
/// register, so while they were called directly there was no way to test
/// importing or exporting — including the parts that are pure logic, like
/// rejecting a file that isn't a scale.
abstract class ScaleFileIo {
  /// Writes [bytes] as `<name>.json`, which the user downloads (web) or
  /// picks a destination for (desktop/mobile).
  Future<void> save({required String name, required Uint8List bytes});

  /// Lets the user pick a `.json` file. Returns null if they cancel.
  Future<PickedScaleFile?> pickJson();
}

/// The real implementation, backed by `file_saver` and `file_picker`.
class PlatformScaleFileIo implements ScaleFileIo {
  const PlatformScaleFileIo();

  @override
  Future<void> save({required String name, required Uint8List bytes}) {
    return FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      fileExtension: 'json',
      mimeType: MimeType.json,
    );
  }

  @override
  Future<PickedScaleFile?> pickJson() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return PickedScaleFile(result.files.single.bytes);
  }
}

const defaultScaleFileIo = PlatformScaleFileIo();

/// Serializes [scale] as the contents of a scale `.json` file.
Uint8List encodeScaleJson(TuningScale scale) =>
    Uint8List.fromList(utf8.encode(scale.toJsonString()));

/// Parses the contents of a scale `.json` file, throwing
/// [ScaleIoException] if it isn't one.
///
/// The result always has a freshly generated id, so importing never
/// collides with (or silently overwrites) an existing saved scale —
/// including re-importing a scale exported from this same app.
TuningScale parseScaleJson(Uint8List bytes) {
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

/// Makes [name] safe to use as a filename, falling back to `scale` when
/// nothing usable is left.
String sanitizeFileName(String name) {
  final cleaned = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');
  return cleaned.isEmpty ? 'scale' : cleaned;
}

/// Saves [scale] as a JSON file the user downloads (web) or picks a
/// destination for (desktop/mobile).
Future<void> exportScale(
  TuningScale scale, {
  ScaleFileIo io = defaultScaleFileIo,
}) {
  return io.save(
    name: sanitizeFileName(scale.name),
    bytes: encodeScaleJson(scale),
  );
}

/// Lets the user pick a `.json` file and parses it as a [TuningScale].
/// Returns null if the user cancels the picker.
Future<TuningScale?> importScale({ScaleFileIo io = defaultScaleFileIo}) async {
  final picked = await io.pickJson();
  if (picked == null) return null; // user cancelled the picker

  final bytes = picked.bytes;
  if (bytes == null) {
    throw ScaleIoException('Could not read the selected file.');
  }
  return parseScaleJson(bytes);
}
