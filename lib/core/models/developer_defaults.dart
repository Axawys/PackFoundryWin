import 'licenses.dart';

/// Release fields of the Project workspace that can follow the defaults from
/// the app settings instead of being typed for every project.
enum DeveloperField { publisher, email, homepage, license }

class DeveloperDefaults {
  const DeveloperDefaults({
    this.publisherName = '',
    this.developerEmail = '',
    this.githubProfile = '',
    this.license = LicenseOption.defaultId,
  });

  final String publisherName;
  final String developerEmail;

  /// SPDX id of the license new projects get.
  final String license;

  /// A GitHub profile URL, or just the user name.
  final String githubProfile;

  /// The profile URL followed by the project folder name, or null when no
  /// profile is set or no project is selected.
  String? homepageFor(String? projectPath) {
    final profile = profileUrl;
    if (profile == null || projectPath == null) {
      return null;
    }
    final folder = projectPath
        .split(RegExp(r'[\\/]'))
        .lastWhere((part) => part.trim().isNotEmpty, orElse: () => '');
    if (folder.isEmpty) {
      return null;
    }
    // GitHub turns spaces in repository names into dashes.
    return '$profile/${folder.trim().replaceAll(RegExp(r'\s+'), '-')}';
  }

  /// [githubProfile] as a full URL without a trailing slash.
  String? get profileUrl {
    var value = githubProfile.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.isEmpty) {
      return null;
    }
    if (value.contains('://')) {
      return value;
    }
    if (value.startsWith('@')) {
      value = value.substring(1);
    }
    return value.contains('/') || value.contains('.')
        ? 'https://$value'
        : 'https://github.com/$value';
  }

  /// The GitHub user name of [githubProfile], or null when the profile is not
  /// a github.com account.
  String? get githubUser {
    final uri = Uri.tryParse(profileUrl ?? '');
    if (uri == null || uri.host.toLowerCase() != 'github.com') {
      return null;
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty);
    if (segments.isEmpty) {
      return null;
    }
    final user = segments.first;
    // GitHub user names are letters, digits and single dashes.
    return RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$').hasMatch(user)
        ? user
        : null;
  }

  /// The avatar GitHub serves for [githubUser], [size] pixels square.
  String? avatarUrl({int size = 192}) {
    final user = githubUser;
    return user == null ? null : 'https://github.com/$user.png?size=$size';
  }
}
