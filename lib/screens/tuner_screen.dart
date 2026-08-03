import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/tuning_scale.dart';
import '../services/settings_service.dart';
import '../services/tuner_engine.dart';
import '../theme/semitone_theme.dart';
import '../widgets/cent_error_bar.dart';

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  final _engine = TunerEngine();
  ScaleMatch? _match;
  bool _hasPermission = true;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    _engine.calibrationOffsetHz = widget.settings.micOffsetHz;
    widget.settings.addListener(_onSettingsChanged);
    _init();
  }

  Future<void> _init() async {
    _hasPermission = await _engine.hasPermission();
    if (_hasPermission) {
      _engine.readings.listen(_onReading);
      await _engine.start();
    }
    if (mounted) setState(() {});
  }

  void _onSettingsChanged() {
    _engine.calibrationOffsetHz = widget.settings.micOffsetHz;
  }

  void _onReading(PitchReading reading) {
    final scale = widget.settings.activeScale ?? TuningScale.empty();
    final match = scale.matchFrequency(reading.frequency);
    if (mounted) setState(() => _match = match);
  }

  Future<void> _requestPermission() async {
    setState(() => _requested = true);
    await _engine.start();
    _hasPermission = await _engine.hasPermission();
    if (_hasPermission) {
      _engine.readings.listen(_onReading);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!_hasPermission) {
      return Center(
        child: TextButton(
          onPressed: _requested ? null : _requestPermission,
          child: Text(
            l10n.micPermissionPrompt,
            style: const TextStyle(color: SemitoneColors.grey4, fontSize: 14),
          ),
        ),
      );
    }

    if (_engine.captureFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.noAudioDevice,
            textAlign: TextAlign.center,
            style: const TextStyle(color: SemitoneColors.grey4, fontSize: 14),
          ),
        ),
      );
    }

    final match = _match;
    return Column(
      children: [
        CentErrorBar(errorCents: match?.errorCents ?? 0),
        Expanded(
          child: Center(
            child: Text(
              match == null ? '--' : '${match.degreeName}${match.octave}',
              style: const TextStyle(
                color: SemitoneColors.white,
                fontSize: 96,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
