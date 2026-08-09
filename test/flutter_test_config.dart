import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-test isolation applied to every suite in `test/`.
///
/// ## Saved preferences
///
/// `SharedPreferences`' mock store is process-wide and survives a test
/// ending, so anything one test writes is visible to the next one that
/// asks for an instance. `setMockInitialValues` resets the store, but only
/// for tests that remember to call it — a test that forgets silently
/// inherits its predecessor's scales, `keepTick` and mic offset, and then
/// passes or fails depending on the order tests happen to run in.
///
/// Clearing it in `setUp` makes every test start from empty storage
/// whether or not it says so. Tests that need particular contents still
/// call `setMockInitialValues` themselves (see
/// `test/support/scale_harness.dart`); this only guarantees the floor.
///
/// ## Assets
///
/// `loadPresetScales()` reads `assets/scales/*.json` through the shared
/// `rootBundle` singleton, whose `CachingAssetBundle` caches loaded data
/// for the lifetime of the process. In `flutter test`, several tests
/// (potentially across different files) run in the same isolate, and a
/// cached asset Future created under one test's zone can leave a pending
/// completion that the next test's clock never observes — hanging that
/// test indefinitely instead of resolving. Evicting the cache after each
/// test avoids reusing a Future across test zones.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Both helpers below reach for binding-backed singletons; ensuring the
  // binding here means plain `test()` bodies don't each have to.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    rootBundle.clear();
  });

  await testMain();
}
