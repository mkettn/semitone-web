import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'theme/semitone_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsService.create();
  runApp(SemitoneWebApp(settings: settings));
}

class SemitoneWebApp extends StatelessWidget {
  const SemitoneWebApp({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Semitone Web',
      debugShowCheckedModeBanner: false,
      theme: buildSemitoneTheme(),
      home: HomeScreen(settings: settings),
    );
  }
}
