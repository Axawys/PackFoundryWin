import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/developer_defaults.dart';
import '../models/licenses.dart';
import '../models/output_file_name.dart';

class AppPreferences {
  static const _themeModeKey = 'themeMode';
  static const _localeModeKey = 'localeMode';
  static const _hideWelcomeKey = 'hideWelcome';
  static const _releaseTagKey = 'releaseTag';
  static const _developerEmailKey = 'developerEmail';
  static const _publisherNameKey = 'publisherName';
  static const _homepageUrlKey = 'homepageUrl';
  static const _projectDescriptionKey = 'projectDescription';
  static const _configPresetsKey = 'configPresets';
  static const _defaultOutputPathKey = 'defaultOutputPath';
  static const _defaultPublisherNameKey = 'defaultPublisherName';
  static const _defaultDeveloperEmailKey = 'defaultDeveloperEmail';
  static const _githubProfileKey = 'githubProfile';
  static const _defaultLicenseKey = 'defaultLicense';
  static const _manualFieldsKey = 'manualFields';
  static const _fileNamePartsKey = 'outputFileNameParts';

  Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: _themeModeFromName(preferences.getString(_themeModeKey)),
      localeMode: _localeModeFromName(preferences.getString(_localeModeKey)),
      showWelcome: !(preferences.getBool(_hideWelcomeKey) ?? false),
    );
  }

  Future<void> saveThemeMode(ThemeMode themeMode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, themeMode.name);
  }

  Future<void> saveLocaleMode(AppLocaleMode localeMode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_localeModeKey, localeMode.name);
  }

  Future<void> saveHideWelcome(bool hideWelcome) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_hideWelcomeKey, hideWelcome);
  }

  Future<SavedReleaseMetadata> loadReleaseMetadata() async {
    final preferences = await SharedPreferences.getInstance();
    return SavedReleaseMetadata(
      releaseTag: preferences.getString(_releaseTagKey) ?? '',
      developerEmail: preferences.getString(_developerEmailKey) ?? '',
      publisherName: preferences.getString(_publisherNameKey) ?? '',
      homepageUrl: preferences.getString(_homepageUrlKey) ?? '',
      description: preferences.getString(_projectDescriptionKey) ?? '',
    );
  }

  Future<void> saveReleaseMetadata(SavedReleaseMetadata metadata) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_releaseTagKey, metadata.releaseTag),
      preferences.setString(_developerEmailKey, metadata.developerEmail),
      preferences.setString(_publisherNameKey, metadata.publisherName),
      preferences.setString(_homepageUrlKey, metadata.homepageUrl),
      preferences.setString(_projectDescriptionKey, metadata.description),
    ]);
  }

  /// Null until the defaults are saved for the first time.
  Future<DeveloperDefaults?> loadDeveloperDefaults() async {
    final preferences = await SharedPreferences.getInstance();
    final publisherName = preferences.getString(_defaultPublisherNameKey);
    final developerEmail = preferences.getString(_defaultDeveloperEmailKey);
    final githubProfile = preferences.getString(_githubProfileKey);
    final license = preferences.getString(_defaultLicenseKey);
    if (publisherName == null &&
        developerEmail == null &&
        githubProfile == null &&
        license == null) {
      return null;
    }
    return DeveloperDefaults(
      publisherName: publisherName ?? '',
      developerEmail: developerEmail ?? '',
      githubProfile: githubProfile ?? '',
      license: license ?? LicenseOption.defaultId,
    );
  }

  Future<void> saveDeveloperDefaults(DeveloperDefaults defaults) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_defaultPublisherNameKey, defaults.publisherName),
      preferences.setString(_defaultDeveloperEmailKey, defaults.developerEmail),
      preferences.setString(_githubProfileKey, defaults.githubProfile),
      preferences.setString(_defaultLicenseKey, defaults.license),
    ]);
  }

  /// Fields of the Project workspace that follow the defaults. Only the
  /// unticked ones are stored, so fields added later start ticked.
  Future<Set<DeveloperField>> loadDefaultFields() async {
    final preferences = await SharedPreferences.getInstance();
    final manual = preferences.getStringList(_manualFieldsKey) ?? const [];
    return {
      for (final field in DeveloperField.values)
        if (!manual.contains(field.name)) field,
    };
  }

  Future<void> saveDefaultFields(Set<DeveloperField> fields) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_manualFieldsKey, [
      for (final field in DeveloperField.values)
        if (!fields.contains(field)) field.name,
    ]);
  }

  Future<Set<FileNamePart>> loadFileNameParts() async {
    final preferences = await SharedPreferences.getInstance();
    final names = preferences.getStringList(_fileNamePartsKey);
    if (names == null) {
      return OutputFileName.defaultParts;
    }
    return {
      for (final part in FileNamePart.values)
        if (names.contains(part.name)) part,
    };
  }

  Future<void> saveFileNameParts(Set<FileNamePart> parts) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_fileNamePartsKey, [
      for (final part in FileNamePart.values)
        if (parts.contains(part)) part.name,
    ]);
  }

  Future<List<String>> loadConfigPresetPaths() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_configPresetsKey) ?? const [];
  }

  Future<void> saveConfigPresetPaths(List<String> paths) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_configPresetsKey, paths);
  }

  /// Export folder used when a project has no folder of its own; null means
  /// the built-in build/pack_foundry inside the project.
  Future<String?> loadDefaultOutputPath() async {
    final preferences = await SharedPreferences.getInstance();
    final path = preferences.getString(_defaultOutputPathKey)?.trim();
    return path == null || path.isEmpty ? null : path;
  }

  Future<void> saveDefaultOutputPath(String? path) async {
    final preferences = await SharedPreferences.getInstance();
    if (path == null || path.trim().isEmpty) {
      await preferences.remove(_defaultOutputPathKey);
    } else {
      await preferences.setString(_defaultOutputPathKey, path.trim());
    }
  }

  ThemeMode _themeModeFromName(String? name) {
    return switch (name) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  AppLocaleMode _localeModeFromName(String? name) {
    return switch (name) {
      'english' => AppLocaleMode.english,
      'russian' => AppLocaleMode.russian,
      _ => AppLocaleMode.system,
    };
  }
}

enum AppLocaleMode {
  system,
  english,
  russian;

  Locale? get locale {
    return switch (this) {
      AppLocaleMode.system => null,
      AppLocaleMode.english => const Locale('en'),
      AppLocaleMode.russian => const Locale('ru'),
    };
  }
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.localeMode,
    required this.showWelcome,
  });

  final ThemeMode themeMode;
  final AppLocaleMode localeMode;
  final bool showWelcome;
}

class SavedReleaseMetadata {
  const SavedReleaseMetadata({
    required this.releaseTag,
    required this.developerEmail,
    required this.publisherName,
    required this.homepageUrl,
    required this.description,
  });

  final String releaseTag;
  final String developerEmail;
  final String publisherName;
  final String homepageUrl;
  final String description;
}
