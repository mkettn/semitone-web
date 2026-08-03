import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../services/tuner_engine.dart';
import '../theme/semitone_theme.dart';

/// Expert-only screen for correcting a microphone's ADC bias: play a known
/// reference tone, measure what the mic reports for it, and save the
/// difference as a fixed Hz offset. From then on [TunerEngine] subtracts
/// that offset from every raw reading before any note-matching happens, so
/// the correction lives upstream of scales rather than per-scale.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final _engine = TunerEngine();
  final _referenceController = TextEditingController(text: '440');
  double? _rawFrequency;
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _hasPermission = await _engine.hasPermission();
    if (_hasPermission) {
      _engine.readings.listen((reading) {
        if (mounted) setState(() => _rawFrequency = reading.frequency);
      });
      await _engine.start();
    }
    if (mounted) setState(() {});
  }

  double? get _referenceHz => double.tryParse(_referenceController.text);

  void _setOffsetFromCurrentReading() {
    final raw = _rawFrequency;
    final reference = _referenceHz;
    if (raw == null || reference == null || reference <= 0) return;
    widget.settings.micOffsetHz = raw - reference;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Offset set to ${(raw - reference).toStringAsFixed(2)} Hz.',
        ),
      ),
    );
  }

  void _resetOffset() {
    widget.settings.micOffsetHz = 0.0;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Offset reset to 0 Hz.')));
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Microphone calibration')),
      body: AnimatedBuilder(
        animation: widget.settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'For expert users. Every microphone\'s ADC can report a '
                'frequency that\'s slightly sharp or flat. To correct for '
                'it, play a steady reference tone near the microphone — a '
                'tuning fork or a tone generator — enter the frequency '
                'you\'re playing below, and set the offset from what\'s '
                'measured. That offset is then subtracted from every '
                'reading before it\'s matched to a note.',
                style: TextStyle(color: SemitoneColors.grey4, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _referenceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Reference tone (Hz)',
                ),
              ),
              const SizedBox(height: 24),
              if (!_hasPermission)
                const Text(
                  'Microphone permission is required to calibrate.',
                  style: TextStyle(color: SemitoneColors.red),
                )
              else if (_engine.captureFailed)
                const Text(
                  'No audio input device is available on this system.',
                  style: TextStyle(color: SemitoneColors.red),
                )
              else
                Center(
                  child: Text(
                    _rawFrequency == null
                        ? 'Listening…'
                        : '${_rawFrequency!.toStringAsFixed(2)} Hz',
                    style: const TextStyle(
                      color: SemitoneColors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _rawFrequency == null || _referenceHz == null
                    ? null
                    : _setOffsetFromCurrentReading,
                child: const Text('Set offset from current reading'),
              ),
              const SizedBox(height: 32),
              Text(
                'Current offset: ${widget.settings.micOffsetHz.toStringAsFixed(2)} Hz',
                style: const TextStyle(color: SemitoneColors.grey4),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: widget.settings.micOffsetHz == 0.0
                    ? null
                    : _resetOffset,
                child: const Text('Reset to 0 Hz'),
              ),
            ],
          );
        },
      ),
    );
  }
}
