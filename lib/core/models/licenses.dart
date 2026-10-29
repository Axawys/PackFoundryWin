/// A license offered in the license picker: its SPDX id, which is what the
/// installer and configs store, and a readable name.
class LicenseOption {
  const LicenseOption(this.id, this.name);

  final String id;
  final String name;

  static const defaultId = 'GPL-3.0-only';

  static const popular = [
    LicenseOption('GPL-3.0-only', 'GNU GPL v3'),
    LicenseOption('GPL-3.0-or-later', 'GNU GPL v3 or later'),
    LicenseOption('GPL-2.0-only', 'GNU GPL v2'),
    LicenseOption('GPL-2.0-or-later', 'GNU GPL v2 or later'),
    LicenseOption('LGPL-3.0-only', 'GNU LGPL v3'),
    LicenseOption('LGPL-2.1-only', 'GNU LGPL v2.1'),
    LicenseOption('AGPL-3.0-only', 'GNU AGPL v3'),
    LicenseOption('MIT', 'MIT License'),
    LicenseOption('Apache-2.0', 'Apache License 2.0'),
    LicenseOption('BSD-3-Clause', 'BSD 3-Clause'),
    LicenseOption('BSD-2-Clause', 'BSD 2-Clause'),
    LicenseOption('MPL-2.0', 'Mozilla Public License 2.0'),
    LicenseOption('EPL-2.0', 'Eclipse Public License 2.0'),
    LicenseOption('ISC', 'ISC License'),
    LicenseOption('Unlicense', 'The Unlicense'),
    LicenseOption('CC0-1.0', 'Creative Commons Zero'),
    LicenseOption('Proprietary', 'Proprietary'),
  ];
}
