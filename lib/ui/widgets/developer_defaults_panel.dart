import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'license_field.dart';
import 'section.dart';

class DeveloperDefaultsPanel extends StatelessWidget {
  const DeveloperDefaultsPanel({
    required this.publisherNameController,
    required this.developerEmailController,
    required this.githubProfileController,
    required this.licenseController,
    super.key,
  });

  final TextEditingController publisherNameController;
  final TextEditingController developerEmailController;
  final TextEditingController githubProfileController;
  final TextEditingController licenseController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Section(
      title: l10n.developerDefaults,
      icon: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.developerDefaultsHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: publisherNameController,
                  decoration: InputDecoration(labelText: l10n.publisherName),
                ),
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: developerEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l10n.developerEmail),
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: githubProfileController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.githubProfile,
                    hintText: 'https://github.com/user',
                  ),
                ),
              ),
              LicenseField(
                controller: licenseController,
                label: l10n.license,
                width: 220,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
