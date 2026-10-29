import 'package:flutter/material.dart';

import '../../core/models/build_target.dart';
import '../../core/services/project_platforms.dart';
import '../../l10n/app_localizations.dart';
import 'section.dart';

class InstallerSettingsPanel extends StatelessWidget {
  const InstallerSettingsPanel({
    required this.appNameController,
    required this.outputPath,
    required this.defaultOutputPath,
    required this.targets,
    required this.onChooseOutput,
    required this.onChanged,
    super.key,
  });

  final TextEditingController appNameController;
  final String? outputPath;
  final String? defaultOutputPath;
  final List<BuildTarget> targets;
  final VoidCallback onChooseOutput;
  final void Function(BuildTarget target, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Section(
      title: l10n.installers,
      icon: Icons.checklist_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: appNameController,
            decoration: InputDecoration(labelText: l10n.applicationName),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onChooseOutput,
                icon: const Icon(Icons.folder_special_outlined),
                label: Text(l10n.chooseExportFolder),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  outputPath ??
                      (defaultOutputPath == null
                          ? l10n.defaultOutput
                          : l10n.defaultOutputAt(defaultOutputPath!)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              // Tiles share the row while they are narrow and stop growing at
              // maxTileWidth, so wide windows leave space at the end instead.
              const spacing = 10.0;
              const minTileWidth = 280.0;
              const maxTileWidth = 380.0;
              final columns =
                  ((constraints.maxWidth + spacing) / (minTileWidth + spacing))
                      .floor()
                      .clamp(1, targets.isEmpty ? 1 : targets.length);
              final itemWidth =
                  ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                      .clamp(0.0, maxTileWidth);

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final target in targets)
                    SizedBox(
                      width: itemWidth,
                      child: _InstallerTargetTile(
                        target: target,
                        icon: _targetIcon(target),
                        title: target.displayLabel,
                        subtitle: target.status == TargetStatus.missingPlatform
                            ? l10n.targetMissingPlatform(
                                ProjectPlatforms.folderFor(target.platform) ??
                                    target.platform.toLowerCase(),
                              )
                            : target.artifact == BuildTarget.buildScript
                            ? l10n.buildScriptTargetHint
                            : target.artifact == BuildTarget.portable &&
                                  target.status == TargetStatus.ready
                            ? l10n.portableTargetHint
                            : l10n.targetStatusLabel(target.status.name),
                        onChanged: (selected) => onChanged(target, selected),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _targetIcon(BuildTarget target) {
    return switch (target.artifact) {
      BuildTarget.apk => Icons.android_outlined,
      BuildTarget.buildScript => Icons.terminal_outlined,
      BuildTarget.portable => Icons.usb_outlined,
      _ => Icons.install_desktop_outlined,
    };
  }
}

class _InstallerTargetTile extends StatelessWidget {
  const _InstallerTargetTile({
    required this.target,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final BuildTarget target;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = target.canSelect;

    return Material(
      color: target.selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: target.selected
              ? colorScheme.primary.withValues(alpha: 0.65)
              : colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () => onChanged(!target.selected) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: target.selected,
                onChanged: enabled
                    ? (value) => onChanged(value ?? false)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
