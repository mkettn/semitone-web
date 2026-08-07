import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:semitone_web/l10n/app_localizations.dart';
import 'package:semitone_web/models/scale_degree.dart';
import 'package:semitone_web/models/tuning_scale.dart';
import 'package:semitone_web/screens/custom_scale_screen.dart';
import 'package:semitone_web/screens/settings_screen.dart';
import 'package:semitone_web/services/scale_io.dart';
import 'package:semitone_web/services/settings_service.dart';

import 'scale_io_test.dart' show FakeScaleFileIo;

/// Mounts [SettingsScreen] on its own rather than through the app shell,
/// whose tuner tab wants a microphone.
Future<void> pumpSettings(
  WidgetTester tester,
  SettingsService settings, {
  ScaleFileIo? fileIo,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(
        settings: settings,
        fileIo: fileIo ?? defaultScaleFileIo,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'renders with many scales without overflowing — the whole page just scrolls',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
      // Seeded scales plus a large number of user scales, to make sure the
      // embedded scale list doesn't blow past a bounded height.
      for (var i = 0; i < 50; i++) {
        settings.addScale(TuningScale(name: 'Scale $i', degrees: const []));
      }

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(settings: settings),
        ),
      );
      await tester.pump();

      // No RenderFlex/overflow (or any other) exception from laying out 55
      // scale rows plus the rest of the settings content.
      expect(tester.takeException(), isNull);

      // The whole page is one scrollable ListView, not a fixed-height list
      // nested in another scrollable.
      final listFinder = find.byType(ListView);
      expect(listFinder, findsOneWidget);
      final scrollableFinder = find.byType(Scrollable);
      expect(scrollableFinder, findsOneWidget);

      // The metronome/about sections and the "New scale" button (replacing
      // the old FAB) live below the (long) scale list — scrolling the one
      // ListView all the way down reaches them without throwing, proving
      // the page scrolls instead of overflowing or clipping content it
      // couldn't fit.
      await tester.scrollUntilVisible(
        find.text('Scale 49'),
        300,
        scrollable: scrollableFinder,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Scale 49'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('New scale'),
        300,
        scrollable: scrollableFinder,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('New scale'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Keep tick'),
        300,
        scrollable: scrollableFinder,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Keep tick'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Reset settings to defaults'),
        300,
        scrollable: scrollableFinder,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Reset settings to defaults'), findsOneWidget);
    },
  );

  testWidgets('picking a language from the dropdown updates settings.locale', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();
    expect(settings.locale, isNull); // starts on "System default".

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(settings: settings),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byType(DropdownButton<String?>),
      300,
      scrollable: find.byType(Scrollable),
    );

    // Invoke the dropdown's onChanged directly rather than opening its
    // overlay menu: the same production code either way triggers, and
    // it avoids driving the menu route's overlay animation in a test.
    final dropdown = tester.widget<DropdownButton<String?>>(
      find.byType(DropdownButton<String?>),
    );
    dropdown.onChanged!('de');
    await tester.pump();

    expect(settings.locale, const Locale('de'));
  });

  group('scale management', () {
    testWidgets('"New scale" creates a scale and opens it in the editor', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
      final before = settings.scales.length;

      await pumpSettings(tester, settings);
      await tester.scrollUntilVisible(
        find.text('New scale'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('New scale'));
      await tester.pumpAndSettle();

      expect(settings.scales, hasLength(before + 1));
      final created = settings.scales.last;
      // Named for its position in the list, and made active on creation.
      expect(created.name, 'New scale ${before + 1}');
      expect(settings.activeScaleId, created.id);

      // Seeded from the bundled Chromatic preset rather than starting
      // empty, so there's something on the cake to edit straight away.
      final chromatic = settings.scales.firstWhere(
        (s) => s.name == 'Chromatic',
      );
      expect(
        created.degrees.map((d) => '${d.name}@${d.cents}'),
        chromatic.degrees.map((d) => '${d.name}@${d.cents}'),
      );
      expect(created.id, isNot(chromatic.id));

      // ...and the editor for it is what's now on screen.
      final editor = tester.widget<CustomScaleScreen>(
        find.byType(CustomScaleScreen),
      );
      expect(editor.scaleId, created.id);
    });

    testWidgets(
      'copying a scale opens the editor on the copy, not the original',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final settings = await SettingsService.create();
        final original = settings.scales.first;

        await pumpSettings(tester, settings);
        await tester.tap(find.byTooltip('Copy scale').first);
        await tester.pumpAndSettle();

        final copy = settings.scales.last;
        expect(copy.name, '${original.name} (copy)');
        expect(copy.id, isNot(original.id));
        // A full copy, not a renamed shell.
        expect(
          copy.degrees.map((d) => '${d.name}@${d.cents}'),
          original.degrees.map((d) => '${d.name}@${d.cents}'),
        );
        expect(copy.rootIndex, original.rootIndex);
        expect(copy.rootOctave, original.rootOctave);
        expect(copy.baseFrequency, original.baseFrequency);

        // The original survives untouched, and the copy becomes active.
        final keptOriginal = settings.scales.firstWhere(
          (s) => s.id == original.id,
        );
        expect(keptOriginal.name, original.name);
        expect(settings.activeScaleId, copy.id);

        // Editing lands on the copy, so a stray edit can't damage the
        // scale that was duplicated.
        final editor = tester.widget<CustomScaleScreen>(
          find.byType(CustomScaleScreen),
        );
        expect(editor.scaleId, copy.id);
      },
    );

    testWidgets('deleting a scale removes it and says so', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
      final doomed = settings.scales.first;
      final before = settings.scales.length;

      await pumpSettings(tester, settings);
      await tester.tap(find.byTooltip('Delete scale').first);
      await tester.pump();

      expect(settings.scales, hasLength(before - 1));
      expect(settings.scales.any((s) => s.id == doomed.id), isFalse);
      expect(find.text('Deleted "${doomed.name}".'), findsOneWidget);
    });

    testWidgets('refuses to delete the last remaining scale', (tester) async {
      // Seeding a single scale directly, rather than deleting the presets
      // down to one: SettingsService only seeds when nothing is stored.
      final only = TuningScale(
        name: 'Only one',
        degrees: const [ScaleDegree(name: 'C', cents: 0)],
      );
      SharedPreferences.setMockInitialValues({
        'custom_scales': [only.toJsonString()],
      });
      final settings = await SettingsService.create();
      expect(settings.scales, hasLength(1));

      await pumpSettings(tester, settings);
      await tester.tap(find.byTooltip('Delete scale').first);
      await tester.pump();

      // The tuner always needs something to match against.
      expect(settings.scales, hasLength(1));
      expect(find.text("Can't delete the last scale."), findsOneWidget);
    });
  });

  group('import and export', () {
    testWidgets('importing a scale file adds it and says so', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
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
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
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
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
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
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
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
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
      final io = FakeScaleFileIo()..throwOnSave = true;

      await pumpSettings(tester, settings, fileIo: io);
      await tester.tap(find.byTooltip('Export scale').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not export:'), findsOneWidget);
    });

    testWidgets('a scale exported then imported comes back intact', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
      final original = settings.scales.first;
      final io = FakeScaleFileIo();

      await pumpSettings(tester, settings, fileIo: io);
      await tester.tap(find.byTooltip('Export scale').first);
      await tester.pumpAndSettle();

      // Feed what was just written back through the picker.
      io.pickResult = PickedScaleFile(io.savedBytes);
      await tester.tap(find.byTooltip('Import a scale from file'));
      await tester.pumpAndSettle();

      final reimported = settings.scales.last;
      expect(reimported.id, isNot(original.id));
      expect(reimported.name, original.name);
      expect(
        reimported.degrees.map((d) => '${d.name}@${d.cents}'),
        original.degrees.map((d) => '${d.name}@${d.cents}'),
      );
      expect(reimported.rootIndex, original.rootIndex);
      expect(reimported.baseFrequency, original.baseFrequency);
      // Both copies coexist: importing never overwrites its source.
      expect(
        settings.scales.where((s) => s.name == original.name),
        hasLength(2),
      );
    });
  });

  group('reset to defaults', () {
    Future<void> openResetDialog(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Reset settings to defaults'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Reset settings to defaults'));
      await tester.pumpAndSettle();
      expect(find.text('Reset settings?'), findsOneWidget);
    }

    testWidgets('cancelling keeps the user\'s scales', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
      settings.addScale(TuningScale(name: 'Mine', degrees: const []));

      await pumpSettings(tester, settings);
      await openResetDialog(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(settings.scales.any((s) => s.name == 'Mine'), isTrue);
      expect(find.text('Settings reset to defaults.'), findsNothing);
    });

    testWidgets('confirming discards them and reloads the presets', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
      final presetCount = settings.scales.length;
      settings.addScale(TuningScale(name: 'Mine', degrees: const []));

      await pumpSettings(tester, settings);
      await openResetDialog(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await tester.pumpAndSettle();

      expect(settings.scales.any((s) => s.name == 'Mine'), isFalse);
      expect(settings.scales, hasLength(presetCount));
      expect(settings.activeScale!.name, 'Chromatic');
      expect(find.text('Settings reset to defaults.'), findsOneWidget);
    });
  });

  testWidgets('the keep-tick switch toggles the stored setting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();
    expect(settings.keepTick, isFalse);

    await pumpSettings(tester, settings);
    await tester.scrollUntilVisible(
      find.byType(SwitchListTile),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(settings.keepTick, isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(settings.keepTick, isFalse);
  });
}
