import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/models/scale_degree.dart';
import 'package:semitone_web/models/tuning_scale.dart';
import 'package:semitone_web/services/scale_io.dart';

/// Stands in for the file picker and file saver, so import/export can be
/// driven without a real dialog. Holds the last save, and hands out
/// whatever [pickResult] is set to.
class FakeScaleFileIo implements ScaleFileIo {
  /// What the picker returns. Null means the user cancelled.
  PickedScaleFile? pickResult;

  /// Makes [save] fail, standing in for a write the platform rejects.
  bool throwOnSave = false;

  String? savedName;
  Uint8List? savedBytes;
  int saveCount = 0;
  int pickCount = 0;

  /// Arms the picker with a file containing [text].
  void willPickText(String text) =>
      pickResult = PickedScaleFile(Uint8List.fromList(utf8.encode(text)));

  @override
  Future<void> save({required String name, required Uint8List bytes}) async {
    saveCount++;
    if (throwOnSave) throw StateError('destination not writable');
    savedName = name;
    savedBytes = bytes;
  }

  @override
  Future<PickedScaleFile?> pickJson() async {
    pickCount++;
    return pickResult;
  }
}

TuningScale sampleScale({String name = 'Byzantine test'}) => TuningScale(
  name: name,
  degrees: const [
    ScaleDegree(name: 'Νη', cents: 0),
    ScaleDegree(name: 'Πα', cents: 200),
    ScaleDegree(name: 'Βου', cents: 366.6666666666667),
  ],
  rootIndex: 1,
  rootOctave: 3,
  baseFrequency: 432,
);

void main() {
  group('export', () {
    test('writes the scale as JSON under its own name', () async {
      final io = FakeScaleFileIo();
      final scale = sampleScale();

      await exportScale(scale, io: io);

      expect(io.saveCount, 1);
      expect(io.savedName, 'Byzantine test');

      final written = jsonDecode(utf8.decode(io.savedBytes!));
      expect(written['name'], 'Byzantine test');
      expect(written['rootIndex'], 1);
      expect(written['rootOctave'], 3);
      expect(written['baseFrequency'], 432);
      expect(written['degrees'], hasLength(3));
    });

    test('a failing save surfaces to the caller', () async {
      final io = FakeScaleFileIo()..throwOnSave = true;

      // SettingsScreen catches this to show "Could not export: ...".
      await expectLater(exportScale(sampleScale(), io: io), throwsStateError);
    });

    group('filenames', () {
      test('path separators and reserved characters become underscores', () {
        expect(sanitizeFileName('a/b\\c'), 'a_b_c');
        expect(sanitizeFileName('what? "this" <>|:*'), 'what_ _this_ _____');
      });

      test('surrounding whitespace is trimmed', () {
        expect(sanitizeFileName('  Chromatic  '), 'Chromatic');
      });

      test('a name with nothing usable in it falls back', () {
        expect(sanitizeFileName(''), 'scale');
        expect(sanitizeFileName('   '), 'scale');
        // Not empty, but every character had to be replaced.
        expect(sanitizeFileName('///'), '___');
      });

      test('export uses the sanitized name', () async {
        final io = FakeScaleFileIo();
        await exportScale(sampleScale(name: 'my/scale'), io: io);
        expect(io.savedName, 'my_scale');
      });
    });
  });

  group('import', () {
    test('reads back a scale this app exported', () async {
      final io = FakeScaleFileIo();
      final original = sampleScale();
      await exportScale(original, io: io);

      io.pickResult = PickedScaleFile(io.savedBytes);
      final imported = (await importScale(io: io))!;

      expect(imported.name, original.name);
      expect(imported.rootIndex, original.rootIndex);
      expect(imported.rootOctave, original.rootOctave);
      expect(imported.baseFrequency, original.baseFrequency);
      expect(
        imported.degrees.map((d) => '${d.name}@${d.cents}'),
        original.degrees.map((d) => '${d.name}@${d.cents}'),
      );
    });

    test(
      'the imported scale gets a fresh id, never the exported one',
      () async {
        final io = FakeScaleFileIo();
        final original = sampleScale();
        await exportScale(original, io: io);
        io.pickResult = PickedScaleFile(io.savedBytes);

        final first = (await importScale(io: io))!;
        final second = (await importScale(io: io))!;

        // Re-importing the same file twice must not overwrite the first
        // copy, nor collide with the scale it came from.
        expect(first.id, isNot(original.id));
        expect(second.id, isNot(original.id));
        expect(first.id, isNot(second.id));
      },
    );

    test('cancelling the picker is not an error', () async {
      final io = FakeScaleFileIo()..pickResult = null;

      expect(await importScale(io: io), isNull);
      expect(io.pickCount, 1);
    });

    test('a file the platform could not read is reported', () async {
      final io = FakeScaleFileIo()..pickResult = const PickedScaleFile(null);

      await expectLater(
        importScale(io: io),
        throwsA(
          isA<ScaleIoException>().having(
            (e) => e.message,
            'message',
            'Could not read the selected file.',
          ),
        ),
      );
    });

    group('rejects a file that is not a scale', () {
      Future<void> expectRejected(String contents) async {
        final io = FakeScaleFileIo()..willPickText(contents);
        await expectLater(
          importScale(io: io),
          throwsA(
            isA<ScaleIoException>().having(
              (e) => e.message,
              'message',
              'That file is not a valid scale.',
            ),
          ),
        );
      }

      test('not JSON at all', () => expectRejected('this is not json'));
      test('empty', () => expectRejected(''));
      test('JSON, but not an object', () => expectRejected('[1, 2, 3]'));
      test(
        'an object without degrees',
        () => expectRejected('{"name": "Nope"}'),
      );
      test(
        'degrees of the wrong shape',
        () => expectRejected('{"name": "Nope", "degrees": [{"nope": 1}]}'),
      );
    });

    test('tolerates a scale file missing its optional fields', () async {
      // Only name and degrees; everything else should fall back rather
      // than being treated as a corrupt file.
      final io = FakeScaleFileIo()
        ..willPickText('{"name":"Minimal","degrees":[{"name":"C","cents":0}]}');

      final imported = (await importScale(io: io))!;

      expect(imported.name, 'Minimal');
      expect(imported.degrees, hasLength(1));
      expect(imported.rootIndex, 0);
      expect(imported.rootOctave, 4);
      expect(imported.baseFrequency, 440);
    });

    test('a root index past the end of the degree list is clamped', () async {
      final io = FakeScaleFileIo()
        ..willPickText(
          '{"name":"Odd","degrees":[{"name":"C","cents":0}],"rootIndex":7}',
        );

      final imported = (await importScale(io: io))!;

      // Otherwise frequencyForDegree/match would index out of range.
      expect(imported.rootIndex, 0);
    });
  });

  test('a scale survives a full export/import round trip unchanged', () async {
    final io = FakeScaleFileIo();
    final original = sampleScale(name: 'Round trip');

    await exportScale(original, io: io);
    io.pickResult = PickedScaleFile(io.savedBytes);
    final imported = (await importScale(io: io))!;

    // Compares the serialized form rather than field by field, so a field
    // added to toJson() but forgotten in parsing shows up here.
    Map<String, dynamic> withoutId(TuningScale s) =>
        jsonDecode(utf8.decode(encodeScaleJson(s))) as Map<String, dynamic>
          ..remove('id'); // deliberately regenerated on import

    expect(withoutId(imported), withoutId(original));
  });
}
