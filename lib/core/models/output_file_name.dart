/// Parts the Windows package file name can be built from, in file name order.
enum FileNamePart { appName, system, version, architecture }

/// Builds package file names such as `HashChecker_1.3.0_setup.exe` from the
/// chosen [parts]. The package kind (`setup`, `portable`) always ends the
/// name, so with no parts at all the file is just `setup.exe`.
class OutputFileName {
  const OutputFileName(this.parts);

  static const defaultParts = {FileNamePart.appName, FileNamePart.version};

  final Set<FileNamePart> parts;

  /// [appName] and [version] must already be safe for file names.
  String baseName({
    required String appName,
    required String version,
    required String kind,
  }) {
    return [
      for (final part in FileNamePart.values)
        if (parts.contains(part))
          switch (part) {
            FileNamePart.appName => appName,
            FileNamePart.system => 'windows',
            FileNamePart.version => version,
            FileNamePart.architecture => 'x64',
          },
      kind,
    ].join('_');
  }
}
