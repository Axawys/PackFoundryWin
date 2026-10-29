import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/developer_defaults.dart';
import '../../core/models/output_file_name.dart';
import '../../core/models/tool_status.dart';
import '../../core/services/app_preferences.dart';
import '../../l10n/app_localizations.dart';
import 'license_field.dart';
import 'toolchain_panel.dart';
import 'workspace_card.dart';

/// The Settings workspace: a developer card that sums up the defaults, the
/// defaults, interface and output file cards, and the toolchain.
class SettingsWorkspace extends StatelessWidget {
  const SettingsWorkspace({
    required this.publisherNameController,
    required this.developerEmailController,
    required this.githubProfileController,
    required this.licenseController,
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
    required this.toolGroups,
    required this.installingToolTarget,
    required this.onInstallTools,
    required this.onRefreshTools,
    required this.onCancelInstall,
    super.key,
  });

  final TextEditingController publisherNameController;
  final TextEditingController developerEmailController;
  final TextEditingController githubProfileController;
  final TextEditingController licenseController;
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
  final List<ToolchainGroup> toolGroups;
  final ToolchainInstallTarget? installingToolTarget;
  final ValueChanged<ToolchainInstallTarget> onInstallTools;
  final VoidCallback onRefreshTools;
  final VoidCallback onCancelInstall;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return WorkspacePage(
      children: [
        _DeveloperCard(workspace: this),
        const SizedBox(height: 16),
        WorkspaceCardRow(
          minRowWidth: 1100,
          cards: [
            WorkspaceCard(
              title: l10n.developerDefaults,
              icon: Icons.badge_outlined,
              child: _DefaultsForm(workspace: this),
            ),
            WorkspaceCard(
              title: l10n.interfaceSection,
              icon: Icons.palette_outlined,
              child: _InterfaceForm(workspace: this),
            ),
            WorkspaceCard(
              title: l10n.outputFilesSection,
              icon: Icons.inventory_2_outlined,
              child: _OutputFilesForm(workspace: this),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ToolchainPanel(
          groups: toolGroups,
          installingTarget: installingToolTarget,
          onInstallTools: onInstallTools,
          onRefresh: onRefreshTools,
          onCancelInstall: onCancelInstall,
        ),
      ],
    );
  }
}

/// Shows what the Project workspace takes from the settings, the way the app
/// card there shows the project. Tool status stays in the toolchain section.
class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({required this.workspace});

  final SettingsWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final w = workspace;

    return WorkspaceCard(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          w.publisherNameController,
          w.developerEmailController,
          w.githubProfileController,
          w.licenseController,
        ]),
        builder: (context, _) {
          final name = w.publisherNameController.text.trim();
          final email = w.developerEmailController.text.trim();
          final license = w.licenseController.text.trim();
          final defaults = DeveloperDefaults(
            githubProfile: w.githubProfileController.text,
          );
          final profile = defaults.profileUrl;

          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      name.isEmpty ? l10n.developerNotSet : name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: name.isEmpty ? colors.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                  if (license.isNotEmpty) SummaryChip(label: license),
                ],
              ),
              const SizedBox(height: 4),
              if (email.isNotEmpty) Text(email, style: muted),
              Text(profile ?? l10n.githubProfileNotSet, style: muted),
              const SizedBox(height: 10),
              Text(
                l10n.developerDefaultsHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(name: name, imageUrl: defaults.avatarUrl()),
              const SizedBox(width: 22),
              Expanded(child: summary),
            ],
          );
        },
      ),
    );
  }
}

/// The GitHub avatar of the profile, or the initials of [name] while it
/// loads, when there is no GitHub profile or no connection.
class _Avatar extends StatefulWidget {
  const _Avatar({required this.name, required this.imageUrl});

  static const size = 96.0;

  final String name;
  final String? imageUrl;

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> {
  /// Follows [_Avatar.imageUrl] with a delay, so typing a profile name does
  /// not request an image for every letter.
  String? _shownUrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _shownUrl = widget.imageUrl;
  }

  @override
  void didUpdateWidget(_Avatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl == oldWidget.imageUrl) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _shownUrl = widget.imageUrl);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = widget.name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first.toUpperCase())
        .join();
    final placeholder = Container(
      width: _Avatar.size,
      height: _Avatar.size,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: initials.isEmpty
          ? Icon(
              Icons.person_outline,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : Text(
              initials,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
    );
    final url = _shownUrl;

    return ClipOval(
      child: url == null
          ? placeholder
          : Image.network(
              url,
              key: ValueKey(url),
              width: _Avatar.size,
              height: _Avatar.size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                  frame == null ? placeholder : child,
              errorBuilder: (context, error, stackTrace) => placeholder,
            ),
    );
  }
}

class _DefaultsForm extends StatelessWidget {
  const _DefaultsForm({required this.workspace});

  final SettingsWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final w = workspace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: w.publisherNameController,
          decoration: InputDecoration(labelText: l10n.publisherName),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: w.developerEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: l10n.developerEmail),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: w.githubProfileController,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l10n.githubProfile,
            hintText: 'https://github.com/user',
          ),
        ),
        const SizedBox(height: 14),
        LicenseField(controller: w.licenseController, label: l10n.license),
      ],
    );
  }
}

class _InterfaceForm extends StatelessWidget {
  const _InterfaceForm({required this.workspace});

  final SettingsWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final w = workspace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(l10n.themeChoice),
        SegmentedButton<ThemeMode>(
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
          selected: {w.themeMode},
          onSelectionChanged: (selection) =>
              w.onThemeModeChanged(selection.single),
        ),
        const SizedBox(height: 20),
        _FieldLabel(l10n.languageChoice),
        SegmentedButton<AppLocaleMode>(
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
          selected: {w.localeMode},
          onSelectionChanged: (selection) =>
              w.onLocaleModeChanged(selection.single),
        ),
      ],
    );
  }
}

class _OutputFilesForm extends StatelessWidget {
  const _OutputFilesForm({required this.workspace});

  final SettingsWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final w = workspace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(l10n.defaultOutputFolder),
        Tooltip(
          message: w.defaultOutputPath ?? '',
          child: Text(
            w.defaultOutputPath ?? l10n.builtInOutputHint,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: w.onChooseDefaultOutput,
              icon: const Icon(Icons.folder_special_outlined),
              label: Text(l10n.chooseFolder),
            ),
            if (w.defaultOutputPath != null)
              TextButton.icon(
                onPressed: w.onResetDefaultOutput,
                icon: const Icon(Icons.restart_alt_outlined),
                label: Text(l10n.resetToBuiltIn),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _FieldLabel(l10n.outputFileName),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final part in FileNamePart.values)
              FilterChip(
                label: Text(l10n.fileNamePart(part)),
                selected: w.fileNameParts.contains(part),
                onSelected: (selected) => w.onFileNamePartsChanged(
                  selected
                      ? {...w.fileNameParts, part}
                      : ({...w.fileNameParts}..remove(part)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            w.fileNamePreview,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
