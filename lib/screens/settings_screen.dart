import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../theme/semitone_theme.dart';
import 'custom_scale_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _concertAController;

  @override
  void initState() {
    super.initState();
    _concertAController =
        TextEditingController(text: widget.settings.concertA.toString());
  }

  @override
  void dispose() {
    _concertAController.dispose();
    super.dispose();
  }

  void _submitConcertA(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) {
      widget.settings.concertA = parsed;
    } else {
      _concertAController.text = widget.settings.concertA.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            children: [
              const _SectionHeader('Global'),
              ListTile(
                title: const Text('Concert pitch (A4)'),
                subtitle: const Text('Reference frequency used by the tuner'),
                trailing: SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _concertAController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    onSubmitted: _submitConcertA,
                    onEditingComplete: () =>
                        _submitConcertA(_concertAController.text),
                    decoration: const InputDecoration(
                      suffixText: 'Hz',
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const _SectionHeader('Metronome'),
              SwitchListTile(
                title: const Text('Keep tick'),
                subtitle: const Text('Keep the metronome running between tabs'),
                value: widget.settings.keepTick,
                onChanged: (v) => widget.settings.keepTick = v,
              ),
              const _SectionHeader('Tuning'),
              SwitchListTile(
                title: const Text('Use custom scale boundaries'),
                subtitle: const Text(
                  'Match detected pitches against your own tone heights '
                  'instead of standard 12-tone equal temperament',
                ),
                value: widget.settings.useCustomScale,
                onChanged: (v) => widget.settings.useCustomScale = v,
              ),
              ListTile(
                title: const Text('Custom scale boundaries'),
                subtitle: Text(
                  '${widget.settings.customScale.degrees.length} tone heights defined',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CustomScaleScreen(settings: widget.settings),
                    ),
                  );
                  setState(() {});
                },
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
