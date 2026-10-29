import 'package:flutter_test/flutter_test.dart';
import 'package:pack_foundry/core/models/developer_defaults.dart';

void main() {
  test('joins the GitHub profile with the project folder name', () {
    const defaults = DeveloperDefaults(
      githubProfile: 'https://github.com/Axawys/',
    );

    expect(
      defaults.homepageFor(r'C:\Users\dev\Projects\HashChecker\'),
      'https://github.com/Axawys/HashChecker',
    );
    expect(
      defaults.homepageFor(r'D:\src\Hash Checker'),
      'https://github.com/Axawys/Hash-Checker',
    );
  });

  test('accepts a bare user name or a URL without a scheme', () {
    expect(
      const DeveloperDefaults(githubProfile: '@Axawys').profileUrl,
      'https://github.com/Axawys',
    );
    expect(
      const DeveloperDefaults(githubProfile: 'github.com/Axawys').profileUrl,
      'https://github.com/Axawys',
    );
  });

  test('finds the GitHub user for the avatar', () {
    expect(
      const DeveloperDefaults(
        githubProfile: 'https://github.com/Axawys/',
      ).avatarUrl(),
      'https://github.com/Axawys.png?size=192',
    );
    expect(
      const DeveloperDefaults(githubProfile: '@Axawys').githubUser,
      'Axawys',
    );
    expect(
      const DeveloperDefaults(
        githubProfile: 'github.com/Axawys/PackFoundryWin',
      ).githubUser,
      'Axawys',
    );
    // Not a GitHub account, so there is no avatar to load.
    expect(
      const DeveloperDefaults(
        githubProfile: 'https://gitlab.com/Axawys',
      ).avatarUrl(),
      isNull,
    );
    expect(const DeveloperDefaults().avatarUrl(), isNull);
  });

  test('has no homepage without a profile or a project', () {
    expect(const DeveloperDefaults().homepageFor(r'C:\app'), isNull);
    expect(
      const DeveloperDefaults(githubProfile: 'Axawys').homepageFor(null),
      isNull,
    );
  });
}
