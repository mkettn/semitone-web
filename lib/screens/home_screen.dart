import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/settings_service.dart';
import '../theme/semitone_theme.dart';
import 'metronome_screen.dart';
import 'settings_screen.dart';
import 'tuner_screen.dart';

/// Top-level tabbed screen (Tuner, Metronome) with a settings action,
/// mirroring the original app's activity_main layout (TabLayout + pager +
/// settings gear). The title is a live dropdown for switching the tuner's
/// active scale; creating/editing/deleting/exporting/importing scales
/// lives under Settings -> My scales.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: _ScaleTitleDropdown(settings: settings),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.tabTuner),
              Tab(text: l10n.tabMetronome),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: l10n.settingsTooltip,
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

/// Replaces the static "Semitone Web" app title with a dropdown for
/// switching the tuner's active scale.
class _ScaleTitleDropdown extends StatelessWidget {
  const _ScaleTitleDropdown({required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final scales = settings.scales;
        final active = settings.activeScale;
        final value = (active != null && scales.any((s) => s.id == active.id))
            ? active.id
            : null;

        final appTitle = AppLocalizations.of(context)!.appTitle;
        if (scales.isEmpty) {
          return Text(appTitle);
        }

        return DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            hint: Text(active?.name ?? appTitle),
            dropdownColor: SemitoneColors.grey2,
            iconEnabledColor: SemitoneColors.white,
            style: const TextStyle(
              color: SemitoneColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
            items: [
              for (final scale in scales)
                DropdownMenuItem(value: scale.id, child: Text(scale.name)),
            ],
            onChanged: (id) {
              if (id != null) settings.activeScaleId = id;
            },
          ),
        );
      },
    );
  }
}
