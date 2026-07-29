import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import 'metronome_screen.dart';
import 'settings_screen.dart';
import 'tuner_screen.dart';

/// Top-level tabbed screen (Tuner, Metronome) with a settings action,
/// mirroring the original app's activity_main layout (TabLayout + pager +
/// settings gear).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Semitone Web'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'TUNER'),
              Tab(text: 'METRONOME'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(settings: settings),
                  ),
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            TunerScreen(settings: settings),
            const MetronomeScreen(),
          ],
        ),
      ),
    );
  }
}
