import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
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
    // initState() can't be async; _init() reports its own results via
    // setState() once it resolves.
    // ignore: discarded_futures
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
          AppLocalizations.of(
            context,
          )!.offsetSetMessage((raw - reference).toStringAsFixed(2)),
        ),
      ),
    );
  }

  void _resetOffset() {
    widget.settings.micOffsetHz = 0.0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.offsetResetMessage)),
    );
  }

  @override
  void dispose() {
    _referenceController.dispose();
    // dispose() can't be async; TunerEngine.dispose() is best-effort
    // cleanup with nothing here that needs to observe it finishing.
    // ignore: discarded_futures
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.calibrationTitle)),
      body: AnimatedBuilder(
        animation: widget.settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.calibrationDescription,
                style: const TextStyle(
                  color: SemitoneColors.grey4,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _referenceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.referenceToneLabel),
              ),
              const SizedBox(height: 24),
              if (!_hasPermission)
                Text(
                  l10n.micPermissionRequired,
                  style: const TextStyle(color: SemitoneColors.red),
                )
              else if (_engine.captureFailed)
                Text(
                  l10n.noAudioDevice,
                  style: const TextStyle(color: SemitoneColors.red),
                )
              else
                Center(
                  child: Text(
                    _rawFrequency == null
                        ? l10n.listeningLabel
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
                child: Text(l10n.setOffsetButton),
              ),
              const SizedBox(height: 32),
              Text(
                l10n.currentOffsetLabel(
                  widget.settings.micOffsetHz.toStringAsFixed(2),
                ),
                style: const TextStyle(color: SemitoneColors.grey4),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: widget.settings.micOffsetHz == 0.0
                    ? null
                    : _resetOffset,
                child: Text(l10n.resetOffsetButton),
              ),
            ],
          );
        },
      ),
    );
  }
}
