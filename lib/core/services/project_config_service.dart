import 'dart:convert';
import 'dart:io';

import '../models/project_config.dart';

class ProjectConfigService {
  const ProjectConfigService();

  Future<ProjectConfig> load(String path) async {
    final file = File(path);
    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map) {
      throw const FormatException('PackFoundry config must be a JSON object.');
    }
    return _resolveRelativePaths(
      ProjectConfig.fromJson(Map<String, Object?>.from(raw)),
      file.parent.path,
    );
  }

  Future<void> save(String path, ProjectConfig config) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(config.toJson())}\n');
  }

  ProjectConfig _resolveRelativePaths(ProjectConfig config, String basePath) {
    return ProjectConfig(
      projectPath: _resolvePath(config.projectPath, basePath),
      outputPath: _resolvePath(config.outputPath, basePath),
      iconPath: _resolvePath(config.iconPath, basePath),
      appName: config.appName,
      releaseTag: config.releaseTag,
      developerEmail: config.developerEmail,
      publisherName: config.publisherName,
      homepageUrl: config.homepageUrl,
      license: config.license,
      description: config.description,
      windowWidth: config.windowWidth,
      windowHeight: config.windowHeight,
      packageTypes: config.packageTypes,
    );
  }

  String? _resolvePath(String? path, String basePath) {
    if (path == null ||
        path == ProjectConfig.chooseInPackFoundry ||
        path.startsWith(r"\\") ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path)) {
      return path;
    }
    return _joinPath(basePath, path);
  }

  String _joinPath(String first, String second) {
    final normalizedSecond = second.replaceAll('/', Platform.pathSeparator);
    if (first.endsWith(Platform.pathSeparator)) {
      return '$first$normalizedSecond';
    }
    return '$first${Platform.pathSeparator}$normalizedSecond';
  }
}
