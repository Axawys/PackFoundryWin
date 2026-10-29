import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/models/build_configuration.dart';
import '../../core/models/build_target.dart';
import '../../core/models/chip_tone.dart';
import '../../core/models/config_preset.dart';
import '../../core/models/developer_defaults.dart';
import '../../core/services/package_file_names.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'license_field.dart';
import 'status_chip.dart';
import 'version_field.dart';
import 'workspace_card.dart';

class ProjectCheck {
  const ProjectCheck({required this.label, required this.tone});

  final String label;
  final ChipTone tone;
}

/// The Project workspace: an app card that sums up what gets built, three
/// numbered setting cards under it and a build bar pinned to the bottom.
class ProjectWorkspace extends StatelessWidget {
  const ProjectWorkspace({
    required this.projectPath,
    required this.pathController,
    required this.checks,
    required this.presets,
    required this.activeConfigPath,
    required this.iconPath,
    required this.outputPath,
    required this.defaultOutputPath,
    required this.appNameController,
    required this.releaseTagController,
    required this.descriptionController,
    required this.publisherNameController,
    required this.developerEmailController,
    required this.homepageUrlController,
    required this.licenseController,
    required this.widthController,
    required this.heightController,
    required this.defaultFields,
    required this.defaults,
    required this.targets,
    required this.configuration,
    required this.isBuilding,
    required this.progress,
    required this.isRunning,
    required this.canRun,
    required this.canSendToDevice,
    required this.isSendingToDevice,
    required this.sendToDeviceStatus,
    required this.onChooseProject,
    required this.onPathSubmitted,
    required this.onAddConfig,
    required this.onSaveCurrentConfig,
    required this.onApplyPreset,
    required this.onRemovePreset,
    required this.onChooseIcon,
    required this.onChooseOutput,
    required this.onUseDefaultChanged,
    required this.onTargetChanged,
    required this.onBuild,
    required this.onOpenBuild,
    required this.onRun,
    required this.onStop,
    required this.onSendToDevice,
    required this.onCancelSendToDevice,
    super.key,
  });

  final String? projectPath;
  final TextEditingController pathController;
  final List<ProjectCheck> checks;
  final List<ConfigPreset> presets;
  final String? activeConfigPath;
  final String? iconPath;
  final String? outputPath;
  final String? defaultOutputPath;
  final TextEditingController appNameController;
  final TextEditingController releaseTagController;
  final TextEditingController descriptionController;
  final TextEditingController publisherNameController;
  final TextEditingController developerEmailController;
  final TextEditingController homepageUrlController;
  final TextEditingController licenseController;
  final TextEditingController widthController;
  final TextEditingController heightController;

  /// Fields filled from [defaults] and locked for editing.
  final Set<DeveloperField> defaultFields;
  final DeveloperDefaults defaults;
  final List<BuildTarget> targets;

  /// Null while no project is selected.
  final BuildConfiguration? configuration;
  final bool isBuilding;
  final int progress;
  final bool isRunning;
  final bool canRun;

  /// Set when the APK target is selected: only then can anything be sent to an
  /// Android device.
  final bool canSendToDevice;
  final bool isSendingToDevice;

  /// Progress line for the send action, since its log lives on the Build tab.
  final String? sendToDeviceStatus;
  final VoidCallback onChooseProject;
  final VoidCallback onPathSubmitted;
  final VoidCallback onAddConfig;
  final VoidCallback onSaveCurrentConfig;
  final ValueChanged<ConfigPreset> onApplyPreset;
  final ValueChanged<ConfigPreset> onRemovePreset;
  final VoidCallback onChooseIcon;
  final VoidCallback onChooseOutput;
  final void Function(DeveloperField field, bool useDefault)
  onUseDefaultChanged;
  final void Function(BuildTarget target, bool selected) onTargetChanged;
  final VoidCallback onBuild;
  final VoidCallback onOpenBuild;
  final VoidCallback onRun;
  final VoidCallback onStop;
  final VoidCallback onSendToDevice;
  final VoidCallback onCancelSendToDevice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return WorkspacePage(
      bottomBar: _BuildBar(workspace: this),
      children: [
        _AppCard(workspace: this),
        const SizedBox(height: 16),
        WorkspaceCardRow(
          cards: [
            WorkspaceCard(
              step: 1,
              title: l10n.aboutApp,
              child: _AboutStep(workspace: this),
            ),
            WorkspaceCard(
              step: 2,
              title: l10n.developerStep,
              child: _DeveloperStep(workspace: this),
            ),
            WorkspaceCard(
              step: 3,
              title: l10n.outputStep,
              child: _OutputStep(workspace: this),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ app card

class _AppCard extends StatelessWidget {
  const _AppCard({required this.workspace});

  final ProjectWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final w = workspace;

    final summary = ListenableBuilder(
      listenable: Listenable.merge([
        w.appNameController,
        w.releaseTagController,
        w.licenseController,
        w.publisherNameController,
        w.developerEmailController,
        w.homepageUrlController,
      ]),
      builder: (context, _) {
        final name = w.appNameController.text.trim();
        final tag = w.releaseTagController.text.trim();
        final license = w.licenseController.text.trim();
        final developer = [
          w.publisherNameController.text.trim(),
          w.developerEmailController.text.trim(),
        ].where((part) => part.isNotEmpty).join(' · ');
        final homepage = w.homepageUrlController.text.trim();
        return Column(
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
                    name.isEmpty ? l10n.applicationName : name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (tag.isNotEmpty) SummaryChip(label: tag),
                if (license.isNotEmpty) SummaryChip(label: license),
              ],
            ),
            const SizedBox(height: 4),
            if (developer.isNotEmpty) Text(developer, style: muted),
            if (homepage.isNotEmpty)
              Text(homepage, style: muted, overflow: TextOverflow.ellipsis),
          ],
        );
      },
    );

    final projectRow = Row(
      children: [
        Expanded(
          child: Focus(
            // Typing a path only counts once the field is left or Enter is
            // pressed, so half-typed paths are not applied.
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                w.onPathSubmitted();
              }
            },
            child: TextField(
              controller: w.pathController,
              decoration: InputDecoration(
                isDense: true,
                labelText: l10n.projectPath,
                hintText: l10n.noProjectSelected,
                prefixIcon: const Icon(Icons.folder_outlined),
              ),
              onSubmitted: (_) => w.onPathSubmitted(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: w.onChooseProject,
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(l10n.chooseFolder),
        ),
      ],
    );

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ConfigMenu(workspace: w),
        if (w.checks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final check in w.checks)
                StatusChip(label: check.label, tone: check.tone),
            ],
          ),
        ],
      ],
    );

    return WorkspaceCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final main = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: l10n.changeIcon,
                child: InkWell(
                  onTap: w.onChooseIcon,
                  borderRadius: BorderRadius.circular(20),
                  child: AppIconPreview(path: w.iconPath, size: 96),
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [summary, const SizedBox(height: 14), projectRow],
                ),
              ),
            ],
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [main, const SizedBox(height: 16), side],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              const SizedBox(width: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: side,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Picks one of the pinned configs; adding and saving configs live in the
/// same menu.
class _ConfigMenu extends StatefulWidget {
  const _ConfigMenu({required this.workspace});

  final ProjectWorkspace workspace;

  @override
  State<_ConfigMenu> createState() => _ConfigMenuState();
}

class _ConfigMenuState extends State<_ConfigMenu> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final w = widget.workspace;
    ConfigPreset? active;
    for (final preset in w.presets) {
      if (preset.path == w.activeConfigPath) {
        active = preset;
      }
    }

    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        for (final preset in w.presets)
          Tooltip(
            message: preset.path,
            waitDuration: const Duration(milliseconds: 600),
            child: MenuItemButton(
              onPressed: w.isBuilding ? null : () => w.onApplyPreset(preset),
              leadingIcon: _ConfigPresetIcon(
                preset: preset,
                isActive: preset.path == w.activeConfigPath,
              ),
              trailingIcon: IconButton(
                onPressed: w.isBuilding
                    ? null
                    : () {
                        _menu.close();
                        w.onRemovePreset(preset);
                      },
                icon: const Icon(Icons.close),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                tooltip: l10n.removeConfigPreset,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(preset.name, overflow: TextOverflow.ellipsis),
                    Text(
                      preset.isBroken
                          ? l10n.configPresetBroken
                          : preset.packageTypes.join(', '),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (w.presets.isNotEmpty) const Divider(height: 8),
        MenuItemButton(
          onPressed: w.isBuilding ? null : w.onAddConfig,
          leadingIcon: const Icon(Icons.playlist_add_outlined),
          child: Text(l10n.addConfig),
        ),
        MenuItemButton(
          onPressed: w.isBuilding ? null : w.onSaveCurrentConfig,
          leadingIcon: const Icon(Icons.save_alt_outlined),
          child: Text(l10n.saveCurrentConfig),
        ),
      ],
      builder: (context, controller, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n.configPresets,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (active == null)
                    const Icon(Icons.bookmarks_outlined, size: 18)
                  else
                    _ConfigPresetIcon(preset: active, isActive: true),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      active?.name ?? l10n.noActiveConfig,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shows the application icon declared by the config. Configs without a usable
/// icon file fall back to a state icon, so every entry keeps a leading glyph.
class _ConfigPresetIcon extends StatelessWidget {
  const _ConfigPresetIcon({required this.preset, required this.isActive});

  static const _size = 22.0;

  final ConfigPreset preset;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final iconPath = preset.isBroken ? null : preset.bitmapIconPath;
    final fallback = SizedBox(
      width: _size,
      height: _size,
      child: Center(child: _fallbackIcon(context)),
    );
    if (iconPath == null) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.file(
        File(iconPath),
        width: _size,
        height: _size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }

  Widget _fallbackIcon(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Icon(
      preset.isBroken
          ? Icons.error_outline
          : isActive
          ? Icons.check_circle_outline
          : Icons.description_outlined,
      size: 18,
      color: preset.isBroken ? colors.error : colors.onSurfaceVariant,
    );
  }
}

// ---------------------------------------------------------------- step cards

class _AboutStep extends StatelessWidget {
  const _AboutStep({required this.workspace});

  final ProjectWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final w = workspace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: w.appNameController,
          decoration: InputDecoration(labelText: l10n.applicationName),
        ),
        const SizedBox(height: 14),
        VersionField(controller: w.releaseTagController),
        const SizedBox(height: 14),
        TextField(
          controller: w.descriptionController,
          minLines: 3,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.packageDescription,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            AppIconPreview(path: w.iconPath, size: 48),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: w.onChooseIcon,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(l10n.changeIcon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Tooltip(
                message: w.iconPath ?? '',
                child: Text(
                  w.iconPath == null
                      ? l10n.noIconSelected
                      : _fileName(w.iconPath!),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeveloperStep extends StatelessWidget {
  const _DeveloperStep({required this.workspace});

  final ProjectWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final w = workspace;
    _LockableField field(
      DeveloperField kind,
      TextEditingController controller,
      String label,
      bool hasDefault, {
      TextInputType? keyboardType,
    }) {
      return _LockableField(
        controller: controller,
        label: label,
        locked: w.defaultFields.contains(kind),
        hasDefault: hasDefault,
        keyboardType: keyboardType,
        onLockedChanged: (locked) => w.onUseDefaultChanged(kind, locked),
      );
    }

    final licenseLocked = w.defaultFields.contains(DeveloperField.license);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(
          DeveloperField.publisher,
          w.publisherNameController,
          l10n.publisherName,
          w.defaults.publisherName.trim().isNotEmpty,
        ),
        const SizedBox(height: 14),
        field(
          DeveloperField.email,
          w.developerEmailController,
          l10n.developerEmail,
          w.defaults.developerEmail.trim().isNotEmpty,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        field(
          DeveloperField.homepage,
          w.homepageUrlController,
          l10n.homepageUrl,
          w.defaults.profileUrl != null,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: LicenseField(
                controller: w.licenseController,
                label: l10n.license,
                enabled: !licenseLocked,
              ),
            ),
            const SizedBox(width: 4),
            _LockButton(
              locked: licenseLocked,
              onPressed: () =>
                  w.onUseDefaultChanged(DeveloperField.license, !licenseLocked),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          l10n.lockHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A field that shows the value from the settings while [locked]; the lock
/// button switches it to a value of its own.
class _LockableField extends StatelessWidget {
  const _LockableField({
    required this.controller,
    required this.label,
    required this.locked,
    required this.hasDefault,
    required this.onLockedChanged,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final bool locked;
  final bool hasDefault;
  final ValueChanged<bool> onLockedChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final showNotSet = locked && !hasDefault;
    return TextField(
      controller: controller,
      readOnly: locked,
      keyboardType: keyboardType,
      style: locked ? TextStyle(color: colors.onSurfaceVariant) : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: showNotSet ? l10n.defaultNotSet : null,
        floatingLabelBehavior: showNotSet ? FloatingLabelBehavior.always : null,
        suffixIcon: _LockButton(
          locked: locked,
          onPressed: () => onLockedChanged(!locked),
        ),
      ),
    );
  }
}

class _LockButton extends StatelessWidget {
  const _LockButton({required this.locked, required this.onPressed});

  final bool locked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: locked ? l10n.lockedFieldHint : l10n.customFieldHint,
      icon: Icon(
        locked ? Icons.lock_outline : Icons.edit_outlined,
        size: 18,
        color: locked ? colors.onSurfaceVariant : colors.onSurface,
      ),
    );
  }
}

class _OutputStep extends StatelessWidget {
  const _OutputStep({required this.workspace});

  final ProjectWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final w = workspace;
    // Targets of platforms the project lacks are not offered at all.
    final targets = [
      for (final target in w.targets)
        if (target.status != TargetStatus.missingPlatform) target,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (targets.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.noProjectPlatforms,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final target in targets) ...[
          _TargetTile(
            target: target,
            onChanged: (selected) => w.onTargetChanged(target, selected),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: w.widthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.windowWidth,
                  suffixText: 'px',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: w.heightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.windowHeight,
                  suffixText: 'px',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: w.onChooseOutput,
              icon: const Icon(Icons.folder_special_outlined),
              label: Text(l10n.exportFolder),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Tooltip(
                message: w.outputPath ?? w.defaultOutputPath ?? '',
                child: Text(
                  w.outputPath ??
                      (w.defaultOutputPath == null
                          ? l10n.defaultOutput
                          : l10n.defaultOutputAt(w.defaultOutputPath!)),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.target, required this.onChanged});

  final BuildTarget target;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = target.canSelect;
    final subtitle = target.artifact == BuildTarget.buildScript
        ? l10n.buildScriptTargetHint
        : target.artifact == BuildTarget.portable &&
              target.status == TargetStatus.ready
        ? l10n.portableTargetHint
        : l10n.targetStatusLabel(target.status.name);
    final muted = enabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurface.withValues(alpha: 0.38);

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
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(
            children: [
              Icon(_targetIcon(target), color: muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.displayLabel,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: muted),
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

  static IconData _targetIcon(BuildTarget target) {
    return switch (target.artifact) {
      BuildTarget.apk => Icons.android_outlined,
      BuildTarget.buildScript => Icons.terminal_outlined,
      BuildTarget.portable => Icons.usb_outlined,
      _ => Icons.install_desktop_outlined,
    };
  }
}

// ----------------------------------------------------------------- build bar

/// Pinned to the bottom of the workspace: what will be built, and the run,
/// send and build actions, so a build starts without switching tabs.
class _BuildBar extends StatelessWidget {
  const _BuildBar({required this.workspace});

  final ProjectWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final w = workspace;
    final selected = [
      for (final target in w.targets)
        if (target.selected) target,
    ];
    final configuration = w.configuration;

    final Widget status;
    if (w.isBuilding) {
      status = _BarStatus(
        leading: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: l10n.buildingProgress(w.progress),
      );
    } else if (w.sendToDeviceStatus != null) {
      status = _BarStatus(
        leading: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: w.sendToDeviceStatus!,
      );
    } else if (configuration == null) {
      status = _BarStatus(
        leading: Icon(Icons.info_outline, color: colors.onSurfaceVariant),
        title: l10n.chooseProjectToBuild,
      );
    } else if (selected.isEmpty) {
      status = _BarStatus(
        leading: Icon(Icons.info_outline, color: colors.onSurfaceVariant),
        title: l10n.selectTargetToBuild,
      );
    } else {
      status = _BarStatus(
        leading: Icon(
          Icons.check_circle_outline,
          color: context.status.success,
        ),
        title: l10n.readyToBuild,
        detail:
            '${selected.map((target) => target.displayLabel).join(' + ')}'
            '  →  ${packageFileNames(configuration, selected).join(', ')}',
      );
    }

    final canBuild =
        configuration != null &&
        selected.isNotEmpty &&
        !w.isRunning &&
        !w.isSendingToDevice;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: workspaceMaxWidth),
            child: Row(
              children: [
                Expanded(child: status),
                const SizedBox(width: 12),
                if (w.canSendToDevice) ...[
                  Tooltip(
                    message: l10n.sendToDeviceHint,
                    child: OutlinedButton.icon(
                      onPressed: w.isBuilding || w.isRunning
                          ? null
                          : (w.isSendingToDevice
                                ? w.onCancelSendToDevice
                                : w.onSendToDevice),
                      icon: Icon(
                        w.isSendingToDevice
                            ? Icons.stop_circle_outlined
                            : Icons.smartphone_outlined,
                      ),
                      label: Text(
                        w.isSendingToDevice
                            ? l10n.cancelSendToDevice
                            : l10n.sendToDevice,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (w.canRun) ...[
                  OutlinedButton.icon(
                    onPressed: w.isBuilding || w.isSendingToDevice
                        ? null
                        : (w.isRunning ? w.onStop : w.onRun),
                    icon: Icon(
                      w.isRunning
                          ? Icons.stop_circle_outlined
                          : Icons.play_arrow_outlined,
                    ),
                    label: Text(
                      w.isRunning ? l10n.stopRunningApp : l10n.runWithoutBuild,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (w.isBuilding)
                  FilledButton.icon(
                    onPressed: w.onOpenBuild,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.openBuild),
                  )
                else
                  FilledButton.icon(
                    onPressed: canBuild ? w.onBuild : null,
                    icon: const Icon(Icons.rocket_launch_outlined),
                    label: Text(l10n.buildInstallers),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarStatus extends StatelessWidget {
  const _BarStatus({required this.leading, required this.title, this.detail});

  final Widget leading;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        leading,
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (detail != null) ...[
          const SizedBox(width: 14),
          Expanded(
            child: Tooltip(
              message: detail!,
              child: Text(
                detail!,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// -------------------------------------------------------------------- shared

String _fileName(String path) {
  final separator = path.lastIndexOf(RegExp(r'[\\/]'));
  return separator == -1 ? path : path.substring(separator + 1);
}
