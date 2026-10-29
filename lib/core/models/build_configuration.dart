import 'build_target.dart';
import 'output_file_name.dart';

class BuildConfiguration {
  const BuildConfiguration({
    required this.appName,
    required this.releaseTag,
    required this.developerEmail,
    required this.publisherName,
    required this.homepageUrl,
    required this.license,
    required this.description,
    required this.projectPath,
    required this.outputPath,
    required this.iconPath,
    required this.windowWidth,
    required this.windowHeight,
    required this.targets,
    this.fileNameParts = OutputFileName.defaultParts,
  });

  final String appName;
  final String releaseTag;
  final String developerEmail;
  final String publisherName;
  final String homepageUrl;
  final String license;
  final String description;
  final String projectPath;
  final String? outputPath;
  final String? iconPath;
  final int? windowWidth;
  final int? windowHeight;
  final List<BuildTarget> targets;

  /// What the Windows package file names are made of.
  final Set<FileNamePart> fileNameParts;
}
