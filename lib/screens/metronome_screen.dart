import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/metronome_engine.dart';
import '../theme/semitone_theme.dart';

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  final _engine = MetronomeEngine();

  @override
  void initState() {
    super.initState();
    _engine.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _engine.removeListener(_refresh);
    _engine.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_engine.running) {
      _engine.stop();
    } else {
      _engine.start();
    }
  }

  void _changeBpm(int delta) => _engine.bpm = _engine.bpm + delta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BpmButton(icon: Icons.remove, onTap: () => _changeBpm(-1)),
              SizedBox(
                width: 140,
                child: Text(
                  '${_engine.bpm}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: SemitoneColors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              _BpmButton(icon: Icons.add, onTap: () => _changeBpm(1)),
            ],
          ),
          Text(
            AppLocalizations.of(context)!.bpmLabel,
            style: const TextStyle(color: SemitoneColors.grey4),
          ),
          const SizedBox(height: 24),
          Slider(
            value: _engine.bpm.toDouble(),
            min: MetronomeEngine.minBpm.toDouble(),
            max: MetronomeEngine.maxBpm.toDouble(),
            activeColor: SemitoneColors.blue,
            inactiveColor: SemitoneColors.grey2,
            onChanged: (v) => setState(() => _engine.bpm = v.round()),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_engine.beatsPerBar, (i) {
              final active = _engine.running && _engine.currentBeat == i;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? SemitoneColors.blue : SemitoneColors.grey2,
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          IconButton(
            iconSize: 72,
            color: SemitoneColors.blue,
            icon: Icon(
              _engine.running
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
            ),
            onPressed: _toggle,
          ),
        ],
      ),
    );
  }
}

class _BpmButton extends StatelessWidget {
  const _BpmButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: SemitoneColors.grey4,
      iconSize: 32,
      onPressed: onTap,
    );
  }
}
