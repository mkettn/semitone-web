import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/models/scale_degree.dart';
import 'package:semitone_web/models/tuning_scale.dart';
import 'package:semitone_web/services/scale_io.dart';

import 'support/scale_harness.dart';

/// Importing and exporting a scale, from both ends: the `scale_io`
/// functions the feature is built from, and the Settings screen buttons
/// that drive them.
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

      await exportScale(sampleScale(), io: io);

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

      io.willPickLastSaved();
      final imported = (await importScale(io: io))!;

      expect(imported.name, original.name);
      expect(imported.rootIndex, original.rootIndex);
      expect(imported.rootOctave, original.rootOctave);
      expect(imported.baseFrequency, original.baseFrequency);
      expect(degreeSignature(imported), degreeSignature(original));
    });

    test(
      'the imported scale gets a fresh id, never the exported one',
      () async {
        final io = FakeScaleFileIo();
        final original = sampleScale();
        await exportScale(original, io: io);
        io.willPickLastSaved();

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
    io.willPickLastSaved();
    final imported = (await importScale(io: io))!;

    // Compares the serialized form rather than field by field, so a field
    // added to toJson() but forgotten in parsing shows up here.
    Map<String, dynamic> withoutId(TuningScale s) =>
        jsonDecode(utf8.decode(encodeScaleJson(s))) as Map<String, dynamic>
          ..remove('id'); // deliberately regenerated on import

    expect(withoutId(imported), withoutId(original));
  });

  group('from the settings screen', () {
    testWidgets('importing a scale file adds it and says so', (tester) async {
      final settings = await seededSettings();
      final before = settings.scales.length;

      final io = FakeScaleFileIo()
        ..willPickText(
          '{"name":"Imported scale","degrees":['
          '{"name":"C","cents":0},{"name":"G","cents":700}],'
          '"rootIndex":1,"rootOctave":3,"baseFrequency":432}',
        );

      await pumpSettings(tester, settings, fileIo: io);
      await tester.tap(find.byTooltip('Import a scale from file'));
      await tester.pumpAndSettle();

      expect(settings.scales, hasLength(before + 1));
      final imported = settings.scales.last;
      expect(imported.name, 'Imported scale');
      expect(imported.degrees, hasLength(2));
      expect(imported.rootIndex, 1);
      expect(imported.rootOctave, 3);
      expect(imported.baseFrequency, 432);
      expect(find.text('Imported "Imported scale".'), findsOneWidget);
      // Importing makes the new scale the active one.
      expect(settings.activeScaleId, imported.id);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      final settings = await seededSettings();
      final before = settings.scales.length;
      final io = FakeScaleFileIo()..pickResult = null;

      await pumpSettings(tester, settings, fileIo: io);
      await tester.tap(find.byTooltip('Import a scale from file'));
      await tester.pumpAndSettle();

      expect(io.pickCount, 1);
      expect(settings.scales, hasLength(before));
      // Cancelling is not a failure, so it says nothing at all.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a file that is not a scale is reported, not saved', (
      tester,
    ) async {
      final settings = await seededSettings();
      final before = settings.scales.length;
      final io = FakeScaleFileIo()..willPickText('nonsense, not a scale');

      await pumpSettings(tester, settings, fileIo: io);
      await tester.tap(find.byTooltip('Import a scale from file'));
      await tester.pumpAndSettle();

      expect(settings.scales, hasLength(before));
      expect(find.text('That file is not a valid scale.'), findsOneWidget);
    });

    testWidgets('exporting a scale writes it under its own name', (
      tester,
    ) async {
      final settings = await seededSettings();
      final scale = settings.scales.first; // seeded Chromatic preset
      final io = FakeScaleFileIo();

      await pumpSettings(tester, settings, fileIo: io);
      await tester.tap(find.byTooltip('Export scale').first);
      await tester.pumpAndSettle();

      expect(io.saveCount, 1);
      expect(io.savedName, scale.name);
      final written =
          jsonDecode(utf8.decode(io.savedBytes!)) as Map<String, dynamic>;
      expect(written['name'], scale.name);
      expect(written['degrees'], hasLength(scale.degrees.length));
    });

    testWidgets('a failed export is reported rather than swallowed', (
      tester,
    ) async {
      final settings = await seededSettings();
      final io = FakeScaleFileIo()..throwOnSave = true;

      await pumpSettings(tester, settings, fileIo: io);
      await tester.tap(find.byTooltip('Export scale').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not export:'), findsOneWidget);
    });

    testWidgets('a scale exported then imported comes back intact', (
      tester,
    ) async {
      final settings = await seededSettings();
      final original = settings.scales.first;
      final io = FakeScaleFileIo();

      await pumpSettings(tester, settings, fileIo: io);
      await tester.tap(find.byTooltip('Export scale').first);
      await tester.pumpAndSettle();

      // Feed what was just written back through the picker.
      io.willPickLastSaved();
      await tester.tap(find.byTooltip('Import a scale from file'));
      await tester.pumpAndSettle();

      final reimported = settings.scales.last;
      expect(reimported.id, isNot(original.id));
      expect(reimported.name, original.name);
      expect(degreeSignature(reimported), degreeSignature(original));
      expect(reimported.rootIndex, original.rootIndex);
      expect(reimported.baseFrequency, original.baseFrequency);
      // Both copies coexist: importing never overwrites its source.
      expect(
        settings.scales.where((s) => s.name == original.name),
        hasLength(2),
      );
    });
  });
}
