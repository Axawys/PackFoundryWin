import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/models/developer_defaults.dart';
import '../../l10n/app_localizations.dart';
import 'license_field.dart';
import 'section.dart';

class AppSettingsPanel extends StatelessWidget {
  const AppSettingsPanel({
    required this.widthController,
    required this.heightController,
    required this.releaseTagController,
    required this.developerEmailController,
    required this.publisherNameController,
    required this.homepageUrlController,
    required this.licenseController,
    required this.descriptionController,
    required this.defaultFields,
    required this.defaults,
    required this.onUseDefaultChanged,
    required this.iconPath,
    required this.onChooseIcon,
    super.key,
  });

  final TextEditingController widthController;
  final TextEditingController heightController;
  final TextEditingController releaseTagController;
  final TextEditingController developerEmailController;
  final TextEditingController publisherNameController;
  final TextEditingController homepageUrlController;
  final TextEditingController licenseController;
  final TextEditingController descriptionController;

  /// Fields filled from [defaults] and locked for editing.
  final Set<DeveloperField> defaultFields;
  final DeveloperDefaults defaults;
  final void Function(DeveloperField field, bool useDefault)
  onUseDefaultChanged;
  final String? iconPath;
  final VoidCallback onChooseIcon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Section(
      title: l10n.applicationSettings,
      icon: Icons.tune_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 150,
                child: TextField(
                  controller: widthController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.windowWidth),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: heightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.windowHeight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.releaseMetadata,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: releaseTagController,
                  decoration: InputDecoration(
                    labelText: l10n.releaseTag,
                    hintText: 'v1.0.0',
                  ),
                ),
              ),
              _DefaultableField(
                width: 220,
                controller: publisherNameController,
                label: l10n.publisherName,
                useDefault: defaultFields.contains(DeveloperField.publisher),
                hasDefault: defaults.publisherName.trim().isNotEmpty,
                onUseDefaultChanged: (value) =>
                    onUseDefaultChanged(DeveloperField.publisher, value),
              ),
              _DefaultableField(
                width: 240,
                controller: developerEmailController,
                label: l10n.developerEmail,
                keyboardType: TextInputType.emailAddress,
                useDefault: defaultFields.contains(DeveloperField.email),
                hasDefault: defaults.developerEmail.trim().isNotEmpty,
                onUseDefaultChanged: (value) =>
                    onUseDefaultChanged(DeveloperField.email, value),
              ),
              _DefaultableField(
                width: 300,
                controller: homepageUrlController,
                label: l10n.homepageUrl,
                keyboardType: TextInputType.url,
                useDefault: defaultFields.contains(DeveloperField.homepage),
                hasDefault: defaults.profileUrl != null,
                onUseDefaultChanged: (value) =>
                    onUseDefaultChanged(DeveloperField.homepage, value),
              ),
              _DefaultableField(
                width: 220,
                controller: licenseController,
                label: l10n.license,
                useDefault: defaultFields.contains(DeveloperField.license),
                hasDefault: defaults.license.trim().isNotEmpty,
                isLicense: true,
                onUseDefaultChanged: (value) =>
                    onUseDefaultChanged(DeveloperField.license, value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: TextField(
              controller: descriptionController,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.packageDescription),
            ),
          ),
          const SizedBox(height: 16),
          _PathPickerRow(
            icon: Icons.image_outlined,
            path: iconPath,
            placeholder: l10n.noIconSelected,
            buttonIcon: Icons.upload_file_outlined,
            buttonLabel: l10n.icon,
            onPressed: onChooseIcon,
          ),
        ],
      ),
    );
  }
}

/// A text field that either shows the default from the app settings or, once
/// its checkbox is cleared, takes a value of its own.
class _DefaultableField extends StatelessWidget {
  const _DefaultableField({
    required this.width,
    required this.controller,
    required this.label,
    required this.useDefault,
    required this.hasDefault,
    required this.onUseDefaultChanged,
    this.keyboardType,
    this.isLicense = false,
  });

  final double width;
  final TextEditingController controller;
  final String label;
  final bool useDefault;
  final bool hasDefault;
  final ValueChanged<bool> onUseDefaultChanged;
  final TextInputType? keyboardType;

  /// Shows the license picker instead of a plain text field.
  final bool isLicense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLicense)
            LicenseField(
              controller: controller,
              label: label,
              width: width,
              enabled: !useDefault,
            )
          else
            TextField(
              controller: controller,
              readOnly: useDefault,
              keyboardType: keyboardType,
              style: useDefault
                  ? TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                  : null,
              decoration: InputDecoration(
                labelText: label,
                hintText: useDefault && !hasDefault ? l10n.defaultNotSet : null,
                floatingLabelBehavior: useDefault && !hasDefault
                    ? FloatingLabelBehavior.always
                    : null,
              ),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => onUseDefaultChanged(!useDefault),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: useDefault,
                  visualDensity: VisualDensity.compact,
                  onChanged: (value) => onUseDefaultChanged(value ?? false),
                ),
                Text(l10n.useDefault),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PathPickerRow extends StatelessWidget {
  const _PathPickerRow({
    required this.icon,
    required this.path,
    required this.placeholder,
    required this.buttonIcon,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String? path;
  final String placeholder;
  final IconData buttonIcon;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: _IconPreview(path: path, fallbackIcon: icon),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(buttonIcon),
          label: Text(buttonLabel),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(path ?? placeholder, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _IconPreview extends StatelessWidget {
  const _IconPreview({required this.path, required this.fallbackIcon});

  final String? path;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final iconPath = path;
    if (iconPath == null || iconPath.trim().isEmpty) {
      return Icon(fallbackIcon);
    }

    final file = File(iconPath);
    if (!file.existsSync()) {
      return Icon(fallbackIcon);
    }

    final extension = iconPath.split('.').last.toLowerCase();
    if (extension == 'svg') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          Text(
            'SVG',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Icon(fallbackIcon),
    );
  }
}
