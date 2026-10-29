import 'package:flutter/material.dart';

import '../../core/models/output_file_name.dart';
import '../../core/services/app_preferences.dart';
import '../../l10n/app_localizations.dart';
import 'section.dart';

class PreferencesPanel extends StatelessWidget {
  const PreferencesPanel({
    required this.themeMode,
    required this.localeMode,
    required this.onThemeModeChanged,
    required this.onLocaleModeChanged,
    required this.defaultOutputPath,
    required this.onChooseDefaultOutput,
    required this.onResetDefaultOutput,
    required this.fileNameParts,
    required this.fileNamePreview,
    required this.onFileNamePartsChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final AppLocaleMode localeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppLocaleMode> onLocaleModeChanged;
  final String? defaultOutputPath;
  final VoidCallback onChooseDefaultOutput;
  final VoidCallback onResetDefaultOutput;
  final Set<FileNamePart> fileNameParts;

  /// The setup.exe name the current parts give for the current project.
  final String fileNamePreview;
  final ValueChanged<Set<FileNamePart>> onFileNamePartsChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Section(
      title: l10n.preferences,
      icon: Icons.tune_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreferenceRow(
            label: l10n.themeChoice,
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_outlined),
                  label: Text(l10n.themeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined),
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: Text(l10n.themeDark),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) =>
                  onThemeModeChanged(selection.single),
            ),
          ),
          const SizedBox(height: 14),
          _PreferenceRow(
            label: l10n.languageChoice,
            child: SegmentedButton<AppLocaleMode>(
              segments: [
                ButtonSegment(
                  value: AppLocaleMode.system,
                  icon: const Icon(Icons.language_outlined),
                  label: Text(l10n.languageSystem),
                ),
                ButtonSegment(
                  value: AppLocaleMode.english,
                  icon: const Text('EN'),
                  label: Text(l10n.languageEnglish),
                ),
                ButtonSegment(
                  value: AppLocaleMode.russian,
                  icon: const Text('RU'),
                  label: Text(l10n.languageRussian),
                ),
              ],
              selected: {localeMode},
              onSelectionChanged: (selection) =>
                  onLocaleModeChanged(selection.single),
            ),
          ),
          const SizedBox(height: 14),
          _PreferenceRow(
            label: l10n.defaultOutputFolder,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onChooseDefaultOutput,
                  icon: const Icon(Icons.folder_special_outlined),
                  label: Text(l10n.chooseFolder),
                ),
                if (defaultOutputPath != null)
                  TextButton.icon(
                    onPressed: onResetDefaultOutput,
                    icon: const Icon(Icons.restart_alt_outlined),
                    label: Text(l10n.resetToBuiltIn),
                  ),
                Text(defaultOutputPath ?? l10n.builtInOutputHint),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _PreferenceRow(
            label: l10n.outputFileName,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final part in FileNamePart.values)
                  FilterChip(
                    label: Text(l10n.fileNamePart(part)),
                    selected: fileNameParts.contains(part),
                    onSelected: (selected) => onFileNamePartsChanged(
                      selected
                          ? {...fileNameParts, part}
                          : ({...fileNameParts}..remove(part)),
                    ),
                  ),
                Text(
                  fileNamePreview,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        child,
      ],
    );
  }
}
