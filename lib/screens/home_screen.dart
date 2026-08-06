import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/metronome_engine.dart';
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
///
/// Owns the [MetronomeEngine] itself (rather than [MetronomeScreen]
/// creating and disposing its own) so it survives switching tabs — the
/// TabBarView's PageView disposes off-screen tab content, which used to
/// tear down the engine's Timer the moment you left the Metronome tab,
/// regardless of [SettingsService.keepTick]. That setting now does what
/// it says: switching away from the Metronome tab stops the engine only
/// when it's off; when it's on, the engine (owned up here) just keeps
/// running underneath whichever tab is showing.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _metronomeTabIndex = 1;

  late final TabController _tabController;
  final _metronomeEngine = MetronomeEngine();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.index == _metronomeTabIndex) return;
    if (widget.settings.keepTick) return;
    _metronomeEngine.stop();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _metronomeEngine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: _ScaleTitleDropdown(settings: widget.settings),
        bottom: TabBar(
          controller: _tabController,
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
                  builder: (_) => SettingsScreen(settings: widget.settings),
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TunerScreen(settings: widget.settings),
          MetronomeScreen(engine: _metronomeEngine),
        ],
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
