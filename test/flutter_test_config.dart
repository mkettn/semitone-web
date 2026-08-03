import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clears `rootBundle`'s asset cache after every test.
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
  tearDown(() {
    rootBundle.clear();
  });
  await testMain();
}
