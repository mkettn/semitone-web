import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../theme/semitone_theme.dart';
import 'scale_list_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            children: [
              const _SectionHeader('Scales'),
              ListTile(
                title: const Text('My scales'),
                subtitle: Text('${settings.scales.length} saved'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScaleListScreen(settings: settings),
                    ),
                  );
                },
              ),
              const _SectionHeader('Metronome'),
              SwitchListTile(
                title: const Text('Keep tick'),
                subtitle: const Text('Keep the metronome running between tabs'),
                value: settings.keepTick,
                onChanged: (v) => settings.keepTick = v,
              ),
              const _SectionHeader('About'),
              const ListTile(
                title: Text('Semitone Web'),
                subtitle: Text(
                  'A Flutter tuner & metronome, in the spirit of the '
                  'original Semitone app.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: SemitoneColors.blue,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
