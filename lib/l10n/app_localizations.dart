import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import '../core/models/output_file_name.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ru')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get _isRu => locale.languageCode == 'ru';

  String get settings => _isRu ? 'Настройки' : 'Settings';
  String get welcomeTitle =>
      _isRu ? 'Добро пожаловать в PackFoundry' : 'Welcome to PackFoundry';
  String get welcomeIntro => _isRu
      ? 'PackFoundry помогает собрать Flutter-проект и подготовить установщики без ручной рутины.'
      : 'PackFoundry helps build Flutter projects and prepare installers without repetitive release chores.';
  String get welcomeFeatureProject => _isRu
      ? 'Выберите папку Flutter-проекта, и приложение проверит доступные цели сборки.'
      : 'Choose a Flutter project folder and the app will check available build targets.';
  String get welcomeFeatureTools => _isRu
      ? 'Следите за Flutter SDK, Visual Studio, Inno Setup и Android SDK в одном окне.'
      : 'Track Flutter SDK, Visual Studio, Inno Setup and Android SDK in one workspace.';
  String get welcomeFeatureBuild => _isRu
      ? 'Запускайте сборку, смотрите прогресс, логи и понятные сообщения об ошибках.'
      : 'Run builds with visible progress, logs and clear failure messages.';
  String get themeChoice => _isRu ? 'Тема интерфейса' : 'Interface theme';
  String get themeSystem => _isRu ? 'Системная' : 'System';
  String get themeLight => _isRu ? 'Светлая' : 'Light';
  String get themeDark => _isRu ? 'Тёмная' : 'Dark';
  String get languageChoice => _isRu ? 'Язык интерфейса' : 'Interface language';
  String get languageSystem => _isRu ? 'Системный' : 'System';
  String get languageEnglish => _isRu ? 'English' : 'English';
  String get languageRussian => _isRu ? 'Русский' : 'Russian';
  String get dontShowAgain =>
      _isRu ? 'Больше не показывать' : 'Do not show again';
  String get startUsing => _isRu ? 'Начать' : 'Start';
  String get cancel => _isRu ? 'Отменить' : 'Cancel';
  String get readyTitle => _isRu ? 'Готово' : 'Ready';
  String get readyDetail => _isRu
      ? 'Выберите проект и нужные установщики, чтобы начать.'
      : 'Choose a project and select target installers to begin.';
  String get projectNotSelectedTitle =>
      _isRu ? 'Проект не выбран' : 'Project is not selected';
  String get projectNotSelectedDetail => _isRu
      ? 'Выберите папку Flutter-проекта перед сборкой установщиков.'
      : 'Choose a Flutter project folder before building installers.';

  String get project => _isRu ? 'Проект' : 'Project';
  String get noProjectSelected =>
      _isRu ? 'Проект не выбран' : 'No project selected';
  String get chooseFolder => _isRu ? 'Выбрать папку' : 'Choose folder';
  String get projectPath => _isRu ? 'Путь к проекту' : 'Project path';
  String get chooseProject => _isRu ? 'Выбрать проект' : 'Choose project';
  String get chooseOutput => _isRu ? 'Выбрать папку экспорта' : 'Choose output';
  String get exportConfig => _isRu ? 'Экспорт конфига' : 'Export config';
  String get configFileType =>
      _isRu ? 'PackFoundry config' : 'PackFoundry config';
  String get iconTypeGroup => _isRu ? 'Иконки приложения' : 'Application icons';
  String get chooseIcon => _isRu ? 'Выбрать иконку' : 'Choose icon';
  String get pubspecFound =>
      _isRu ? 'pubspec.yaml найден' : 'pubspec.yaml found';
  String get pubspecMissing =>
      _isRu ? 'pubspec.yaml не найден' : 'pubspec.yaml missing';
  String get windowsRunnerFound =>
      _isRu ? 'Windows runner найден' : 'Windows runner found';
  String get androidManifestFound =>
      _isRu ? 'Android-манифест найден' : 'Android manifest found';
  String get projectVersionFound => _isRu ? 'Версия найдена' : 'Version found';
  String get projectVersionMissing =>
      _isRu ? 'Версия не указана' : 'Version missing';
  String get projectDescriptionFound =>
      _isRu ? 'Описание найдено' : 'Description found';
  String get projectDescriptionMissing =>
      _isRu ? 'Описание не указано' : 'Description missing';
  String projectIconFound(String path) =>
      _isRu ? 'Иконка: $path' : 'Icon: $path';
  String get projectIconMissing =>
      _isRu ? 'Иконка в assets не найдена' : 'No icon found in assets';
  String get configExported =>
      _isRu ? 'Конфиг PackFoundry сохранён.' : 'PackFoundry config was saved.';

  String configImportFailed(String detail) {
    return _isRu
        ? 'Не удалось импортировать конфиг: $detail'
        : 'Could not import config: $detail';
  }

  String configExportFailed(String detail) {
    return _isRu
        ? 'Не удалось экспортировать конфиг: $detail'
        : 'Could not export config: $detail';
  }

  String projectFolderNotFound(String path) {
    return _isRu ? 'Папка не найдена: $path' : 'Folder was not found: $path';
  }

  String get configPresets => _isRu ? 'Конфиги' : 'Configs';
  String get addConfig => _isRu ? 'Добавить конфиг' : 'Add config';
  String get saveCurrentConfig =>
      _isRu ? 'Сохранить текущий' : 'Save current settings';
  String get configPresetBroken =>
      _isRu ? 'Файл не читается' : 'File cannot be read';
  String get removeConfigPreset =>
      _isRu ? 'Убрать из списка' : 'Remove from list';
  String get configPresetRemoved => _isRu
      ? 'Конфиг убран из списка. Файл на диске сохранён.'
      : 'Config was removed from the list. The file on disk is kept.';
  String get configPresetAlreadyPinned => _isRu
      ? 'Этот конфиг уже в списке.'
      : 'This config is already in the list.';

  String get applicationName =>
      _isRu ? 'Название приложения' : 'Application name';
  String get versionMajor => _isRu ? 'Мажорная' : 'Major';
  String get versionMinor => _isRu ? 'Минорная' : 'Minor';
  String get versionPatch => _isRu ? 'Патч' : 'Patch';
  String get developerEmail => _isRu ? 'Почта разработчика' : 'Developer email';
  String get publisherName =>
      _isRu ? 'Разработчик / издатель' : 'Developer / publisher';
  String get homepageUrl => _isRu ? 'Сайт проекта' : 'Project homepage';
  String get license => _isRu ? 'Лицензия' : 'License';
  String get packageDescription =>
      _isRu ? 'Описание пакета' : 'Package description';
  String get windowWidth => _isRu ? 'Ширина окна' : 'Window width';
  String get windowHeight => _isRu ? 'Высота окна' : 'Window height';
  String get icon => _isRu ? 'Иконка' : 'Icon';
  String get defaultOutput => _isRu
      ? 'По умолчанию: build/pack_foundry'
      : 'Default: build/pack_foundry';
  String defaultOutputAt(String path) =>
      _isRu ? 'По умолчанию: $path' : 'Default: $path';
  String get defaultOutputFolder =>
      _isRu ? 'Папка экспорта по умолчанию' : 'Default output folder';
  String get resetToBuiltIn => _isRu ? 'Сбросить' : 'Reset';
  String get outputFileName =>
      _isRu ? 'Имя файла установщика' : 'Installer file name';
  String fileNamePart(FileNamePart part) {
    return switch (part) {
      FileNamePart.appName => _isRu ? 'Название приложения' : 'App name',
      FileNamePart.system => _isRu ? 'Система' : 'System',
      FileNamePart.version => _isRu ? 'Версия' : 'Version',
      FileNamePart.architecture => _isRu ? 'Архитектура' : 'Architecture',
    };
  }

  String get developerDefaults =>
      _isRu ? 'Разработчик по умолчанию' : 'Developer defaults';
  String get developerDefaultsHint => _isRu
      ? 'Подставляются в поля с замком на вкладке «Проект». '
            'Сайт проекта = профиль GitHub + имя папки проекта.'
      : 'Used by the locked fields of the Project workspace. '
            'Project homepage = GitHub profile + project folder name.';
  String get githubProfile => _isRu ? 'Профиль GitHub' : 'GitHub profile';
  String get defaultNotSet =>
      _isRu ? 'Не задано в настройках' : 'Not set in settings';
  String get builtInOutputHint => _isRu
      ? 'build/pack_foundry в папке проекта'
      : 'build/pack_foundry inside the project';

  String get windowsBuildGroupTitle => 'Windows';
  String get androidBuildGroupTitle => 'Android';
  String get installMissingTools =>
      _isRu ? 'Установить недостающие инструменты' : 'Install missing tools';
  String get installingTools => _isRu ? 'Установка...' : 'Installing...';

  String get commonToolsGroupTitle => 'Flutter';
  String get commonToolsGroupSubtitle => _isRu
      ? 'Flutter SDK и Git, без которых не соберётся ни одна цель.'
      : 'Flutter SDK and Git that every build target relies on.';
  String get gitNote => _isRu
      ? 'Загружает и обновляет Flutter SDK, нужен flutter pub get для git-зависимостей.'
      : 'Downloads and updates the Flutter SDK and fetches git dependencies.';
  String get requiresCommonTools => _isRu
      ? 'Также нужны общие инструменты — они установятся вместе с этой группой.'
      : 'Common tools are also required; they are installed along with this group.';
  String get installPreparing =>
      _isRu ? 'Подготовка установки…' : 'Preparing installation…';
  String get installStepFlutterSdk => 'Flutter SDK';
  String get installStepAndroidSdk => 'Android SDK';
  String get installStepGit => 'Git';
  String get installStepJava => 'OpenJDK 17';
  String get installStepVisualStudio => 'Visual Studio Build Tools (C++)';
  String get installStepInnoSetup => 'Inno Setup 6';
  String get installStepDeveloperMode =>
      _isRu ? 'Режим разработчика' : 'Developer Mode';
  String get developerModeOpened => _isRu
      ? 'Открыты параметры Windows: включите «Режим разработчика».'
      : 'Windows Settings are open: turn on Developer Mode.';
  String get installEstimatingTime =>
      _isRu ? 'Оцениваем время…' : 'Estimating time…';
  String get installCannotCancel => _isRu
      ? 'Этот шаг выполняет установщик winget, его нельзя прервать безопасно.'
      : 'This step runs a winget installer and cannot be interrupted safely.';

  String installOverallProgress(int progress) {
    return _isRu ? 'Установка: $progress%' : 'Installing: $progress%';
  }

  String installStepCounter(int current, int total) {
    return _isRu ? 'Шаг $current из $total' : 'Step $current of $total';
  }

  String toolInstallSuccess(String detail) {
    return _isRu
        ? 'Инструменты установлены. $detail'
        : 'Tools installed. $detail';
  }

  String toolInstallFailed(String detail) {
    return _isRu
        ? 'Не удалось установить инструменты. $detail'
        : 'Could not install tools. $detail';
  }

  String get noProjectPlatforms => _isRu
      ? 'У проекта нет ни Windows, ни Android. Добавьте платформу: flutter create --platforms=windows,android .'
      : 'The project has neither Windows nor Android. Add a platform: flutter create --platforms=windows,android .';
  String get buildScriptTargetHint => _isRu
      ? 'Скрипт для сборки setup.exe на любом Windows-компьютере'
      : 'Script that builds setup.exe on any Windows machine';
  String get portableTargetHint => _isRu
      ? 'Один exe: запускается сразу, без установки'
      : 'One exe that runs right away, no install';

  String get windowsBuildGroupSubtitle => _isRu
      ? 'Сборка Windows-приложения и установщика setup.exe через Inno Setup на этом компьютере.'
      : 'Build the Windows app and its setup.exe with Inno Setup on this machine.';
  String get androidBuildGroupSubtitle => _isRu
      ? 'Сборка Android APK через Flutter и локальный Android SDK.'
      : 'Build Android APK through Flutter and the local Android SDK.';

  String get flutterSdkNotFound => _isRu
      ? 'Flutter SDK не найден. Установите его в «Настройки → Общие» или добавьте папку flutter\\bin в PATH.'
      : 'Flutter SDK was not found. Install it in Settings → Common tools, or add the flutter\\bin folder to PATH.';
  String get flutterSdkNote => _isRu
      ? 'Нужен для сборки под любую платформу.'
      : 'Required for every build target.';
  String get visualStudioNote => _isRu
      ? 'Компилятор MSVC из нагрузки «Разработка классических приложений на C++». Ищется через vswhere.'
      : 'The MSVC compiler from the "Desktop development with C++" workload, found with vswhere.';
  String get innoSetupNote => _isRu
      ? 'ISCC.exe упаковывает собранное Windows-приложение в setup.exe.'
      : 'ISCC.exe packages the built Windows app into setup.exe.';
  String get developerModeName =>
      _isRu ? 'Режим разработчика' : 'Developer Mode';
  String get developerModeNote => _isRu
      ? 'Нужен проектам с плагинами: Flutter создаёт для них символические ссылки.'
      : 'Needed by projects with plugins: Flutter links them with symlinks.';
  String get buildScriptToolName => _isRu ? 'Скрипт сборки' : 'Build script';
  String get buildScriptToolNote => _isRu
      ? 'Экспортируется без дополнительных инструментов: скрипт сам проверит их на компьютере, где его запустят.'
      : 'Exported without extra tools: the script checks them on the machine that runs it.';
  String get androidSdkNote => _isRu
      ? 'Включает сборку APK и AAB артефактов.'
      : 'Enables APK and AAB release artifacts.';
  String get javaNote => _isRu
      ? 'Нужна Android Gradle toolchain для сборки APK/AAB.'
      : 'Required by the Android Gradle toolchain for APK/AAB builds.';

  String get interfaceSection => _isRu ? 'Интерфейс' : 'Interface';
  String get outputFilesSection => _isRu ? 'Выходные файлы' : 'Output files';
  String get developerNotSet =>
      _isRu ? 'Разработчик не задан' : 'No developer set';
  String get githubProfileNotSet =>
      _isRu ? 'Профиль GitHub не задан' : 'No GitHub profile';
  String get aboutApp => _isRu ? 'О приложении' : 'About the app';
  String projectChecksPassed(int count) =>
      _isRu ? 'Проверок пройдено: $count' : '$count checks passed';
  String get developerStep => _isRu ? 'Разработчик' : 'Developer';
  String get outputStep => _isRu ? 'Результат' : 'Output';
  String get changeIcon => _isRu ? 'Сменить иконку' : 'Change icon';
  String get noActiveConfig => _isRu ? 'Без конфига' : 'No config';
  String get exportFolder => _isRu ? 'Папка экспорта' : 'Export folder';
  String get lockHint => _isRu
      ? 'Поля с замком берут значения из настроек. Нажмите на замок, чтобы ввести своё.'
      : 'Locked fields use the values from Settings. Click the lock to enter your own.';
  String get lockedFieldHint => _isRu
      ? 'Из настроек. Нажмите, чтобы ввести своё значение'
      : 'From Settings. Click to enter your own value';
  String get customFieldHint => _isRu
      ? 'Своё значение. Нажмите, чтобы взять из настроек'
      : 'Custom value. Click to use the value from Settings';
  String get chooseProjectToBuild => _isRu
      ? 'Выберите папку проекта, чтобы собрать'
      : 'Choose a project folder to build';
  String get selectTargetToBuild =>
      _isRu ? 'Выберите хотя бы одну цель' : 'Select at least one target';
  String get readyToBuild => _isRu ? 'Готово к сборке' : 'Ready';
  String buildingProgress(int percent) =>
      _isRu ? 'Идёт сборка… $percent%' : 'Building… $percent%';
  String get openBuild => _isRu ? 'Открыть сборку' : 'Open build';
  String get toolchain => _isRu ? 'Инструменты' : 'Toolchain';
  String get checkToolsAgain => _isRu ? 'Проверить снова' : 'Check again';
  String get toolsReady => _isRu ? 'Готово' : 'Ready';
  String toolsMissingCount(int count) =>
      _isRu ? 'Не хватает: $count' : '$count missing';
  String get allTargets => _isRu ? 'все цели' : 'every target';
  String toolsNotInstalled(String names) =>
      _isRu ? 'Не установлено: $names' : 'Not installed: $names';
  String get build => _isRu ? 'Сборка' : 'Build';
  String selectedTargets(int count) {
    if (!_isRu) {
      return '$count selected target${count == 1 ? '' : 's'}';
    }
    return 'Выбрано целей: $count';
  }

  String get building => _isRu ? 'Сборка...' : 'Building...';
  String get buildInstallers => _isRu ? 'Собрать' : 'Build';
  String get runWithoutBuild => _isRu ? 'Запустить' : 'Run';
  String get runningApp => _isRu ? 'Приложение запущено' : 'App is running';
  String get stopRunningApp => _isRu ? 'Остановить' : 'Stop';
  String get sendToDevice =>
      _isRu ? 'Отправить на устройство' : 'Send to device';
  String get sendToDeviceHint => _isRu
      ? 'Собирает release APK и устанавливает его на подключенное Android-устройство.'
      : 'Builds a release APK and installs it on the connected Android device.';
  String get cancelSendToDevice => _isRu ? 'Отменить' : 'Cancel';
  String get adbMissing => _isRu
      ? 'adb не найден. Установите Android SDK во вкладке «Настройки».'
      : 'adb was not found. Install the Android SDK on the Settings tab.';
  String get androidDeviceSearchTitle =>
      _isRu ? 'Поиск устройства' : 'Looking for a device';
  String get androidDeviceMissingMessage => _isRu
      ? 'Подключите Android-устройство по USB и включите отладку по USB в параметрах разработчика.'
      : 'Connect an Android device over USB and enable USB debugging in the developer options.';
  String get androidDeviceUnauthorizedTitle =>
      _isRu ? 'Подтвердите отладку' : 'Confirm debugging';
  String androidDeviceUnauthorizedMessage(String device) {
    return _isRu
        ? 'Устройство $device подключено, но не авторизовано. На экране телефона появится запрос «Разрешить отладку по USB?» с отпечатком ключа — сверьте его и нажмите «Разрешить», затем повторите проверку.'
        : 'Device $device is connected but not authorized. The phone shows an "Allow USB debugging?" prompt with a key fingerprint — confirm it, then check again.';
  }

  String get retryDeviceCheck => _isRu ? 'Проверить снова' : 'Check again';
  String get chooseAndroidDeviceTitle =>
      _isRu ? 'Выберите устройство' : 'Choose a device';
  String get androidBuildingApk =>
      _isRu ? 'Сборка release APK...' : 'Building the release APK...';
  String androidInstallingApk(String device) {
    return _isRu ? 'Установка на $device...' : 'Installing on $device...';
  }

  String get androidApkMissing => _isRu
      ? 'APK не найден после сборки. Подробности — в техническом логе.'
      : 'The APK was not found after the build. See the technical log.';
  String get androidBuildFailed => _isRu
      ? 'Не удалось собрать APK. Подробности — в техническом логе.'
      : 'The APK build failed. See the technical log.';
  String androidInstallSucceeded(String device) {
    return _isRu
        ? 'APK установлен на $device.'
        : 'The APK was installed on $device.';
  }

  String get androidInstallFailed => _isRu
      ? 'Установка не удалась. Подробности — в техническом логе.'
      : 'The install failed. See the technical log.';
  String get androidSignatureConflictTitle =>
      _isRu ? 'Установлена другая сборка' : 'A different build is installed';
  String get androidSignatureConflictMessage => _isRu
      ? 'На устройстве уже стоит версия приложения, подписанная другим ключом. Обновить её поверх нельзя — старую нужно удалить, вместе с ней будут потеряны данные приложения.'
      : 'The device already has a version of the app signed with a different key. It cannot be updated in place — the old one must be removed, and the app data will be lost with it.';
  String get removeAndInstall =>
      _isRu ? 'Удалить и установить' : 'Uninstall and install';
  String get androidSendCancelled =>
      _isRu ? 'Отправка на устройство отменена.' : 'Send to device cancelled.';
  String get buildSuccessTitle =>
      _isRu ? 'Сборка завершена' : 'Build completed';
  String get buildSuccessMessage => _isRu
      ? 'Выбранные установщики успешно собраны и сохранены в папку экспорта.'
      : 'Selected installers were built successfully and saved to the output folder.';
  String get buildWarningsTitle =>
      _isRu ? 'Сборка не завершена' : 'Build did not finish';
  String get buildWarningsMessage => _isRu
      ? 'Сборка остановилась на одном из шагов. Подробности — в журнале процессов.'
      : 'The build stopped on one of the steps. See the process log for details.';
  String get ok => _isRu ? 'OK' : 'OK';
  String get buildPlanTitle => _isRu ? 'План сборки' : 'Build plan';
  String get buildCommandsTitle => _isRu ? 'Команды' : 'Commands';
  String get processLogTitle => _isRu ? 'Журнал процессов' : 'Process log';
  String get noBuildPlan => _isRu
      ? 'Выберите форматы установщиков на вкладке «Проект», чтобы увидеть план сборки.'
      : 'Select installer formats on the Project tab to see the build plan.';
  String get noBuildCommands => _isRu
      ? 'Выберите форматы установщиков, чтобы увидеть команды сборки.'
      : 'Select installer formats to preview build commands.';
  String get noStepCommands => _isRu
      ? 'У этого этапа нет отдельных команд.'
      : 'This step has no separate commands.';
  String get copyStepCommands =>
      _isRu ? 'Скопировать команды этапа' : 'Copy step commands';
  String get copyFullScript => _isRu ? 'Весь скрипт' : 'Full script';
  String get copyLog => _isRu ? 'Скопировать журнал' : 'Copy log';
  String get copiedToClipboard =>
      _isRu ? 'Скопировано в буфер обмена' : 'Copied to clipboard';
  String get selectProjectForCommands => _isRu
      ? 'Выберите Flutter-проект, чтобы PackFoundry подставил реальные пути и имена.'
      : 'Select a Flutter project so PackFoundry can resolve real paths and names.';
  String overallProgressLabel(int progress) {
    return _isRu
        ? 'Общий прогресс: $progress%'
        : 'Overall progress: $progress%';
  }

  String buildRemainingTime(int seconds) {
    if (seconds <= 0) {
      return _isRu
          ? 'Осталось: меньше минуты'
          : 'Remaining: less than a minute';
    }
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) {
      return _isRu ? 'Осталось: ~$minutes мин' : 'Remaining: ~$minutes min';
    }
    final hours = minutes ~/ 60;
    final restMinutes = minutes % 60;
    if (restMinutes == 0) {
      return _isRu ? 'Осталось: ~$hours ч' : 'Remaining: ~$hours h';
    }
    return _isRu
        ? 'Осталось: ~$hours ч $restMinutes мин'
        : 'Remaining: ~$hours h $restMinutes min';
  }

  String roadmapUsuallySeconds(int seconds) {
    return _isRu ? 'Обычно: ~$seconds сек' : 'Usually: ~$seconds sec';
  }

  String roadmapUsuallyMinutes(int minutes) {
    return _isRu ? 'Обычно: ~$minutes мин' : 'Usually: ~$minutes min';
  }

  String targetStatusLabel(String statusName) {
    return switch (statusName) {
      'ready' =>
        _isRu
            ? 'Готово к сборке на этом компьютере'
            : 'Ready to build on this machine',
      'installable' =>
        _isRu
            ? 'Нужны дополнительные инструменты'
            : 'Install extra tools to enable',
      'blocked' =>
        _isRu
            ? 'Заблокировано до установки SDK/toolchain'
            : 'Blocked until SDK/toolchain is installed',
      'missingPlatform' =>
        _isRu
            ? 'Платформа не добавлена в проект'
            : 'Platform is not added to the project',
      _ => statusName,
    };
  }

  String roadmapStepTitle(String id, String fallback) {
    return switch (id) {
      'project' => _isRu ? 'Проект' : 'Project',
      'workspace' => 'Workspace',
      'build-script' => _isRu ? 'Скрипт сборки' : 'Build script',
      'windows-build' => 'Flutter build',
      'installer' => 'SETUP.EXE',
      'portable' => 'PORTABLE',
      'android-build' => _isRu ? 'APK сборка' : 'APK build',
      'apk-export' => _isRu ? 'APK экспорт' : 'APK export',
      'summary' => _isRu ? 'Экспорт' : 'Export',
      'cleanup' => _isRu ? 'Очистка' : 'Cleanup',
      _ => fallback,
    };
  }

  String roadmapStepDescription(String id, String fallback) {
    return switch (id) {
      'project' =>
        _isRu
            ? 'Проверка pubspec.yaml, метаданных приложения и папки экспорта.'
            : 'Check pubspec.yaml, app metadata and export folder.',
      'workspace' =>
        _isRu
            ? 'Копирование проекта и применение настроек без изменения исходников.'
            : 'Copy the project and apply settings without touching sources.',
      'build-script' =>
        _isRu
            ? 'Запись build_setup.cmd, setup.iss и иконки в папку экспорта.'
            : 'Write build_setup.cmd, setup.iss and the icon to the export folder.',
      'windows-build' =>
        _isRu
            ? 'Сборка Windows release runner.'
            : 'Compile the Windows release runner.',
      'installer' =>
        _isRu
            ? 'Генерация setup.iss и компиляция через Inno Setup.'
            : 'Generate setup.iss and compile it with Inno Setup.',
      'portable' =>
        _isRu
            ? 'Упаковка приложения в один exe, который запускается без установки.'
            : 'Pack the app into one exe that runs without installing.',
      'android-build' =>
        _isRu
            ? 'Сборка Android release APK через Flutter и Gradle.'
            : 'Compile the Android release APK through Flutter and Gradle.',
      'apk-export' =>
        _isRu
            ? 'Поиск готового APK и копирование в папку экспорта.'
            : 'Find the generated APK and copy it to the export folder.',
      'summary' =>
        _isRu
            ? 'Проверка и вывод списка созданных артефактов.'
            : 'Verify and report generated artifacts.',
      'cleanup' =>
        _isRu
            ? 'Удаление временной копии проекта.'
            : 'Remove the temporary workspace.',
      _ => fallback,
    };
  }

  String roadmapDetail(String detail) {
    if (!_isRu) {
      return detail;
    }
    return switch (detail) {
      'Checking project folder and pubspec.yaml.' =>
        'Проверяем папку проекта и pubspec.yaml.',
      'Project metadata and output folder are ready.' =>
        'Метаданные проекта и папка экспорта готовы.',
      'Copying project into a disposable workspace.' =>
        'Копируем проект во временное рабочее окружение.',
      'Temporary project copy is ready.' => 'Временная копия проекта готова.',
      'Writing build_setup.cmd and setup.iss.' =>
        'Записываем build_setup.cmd и setup.iss.',
      'Running flutter build windows --release.' =>
        'Запускаем flutter build windows --release.',
      'Generating setup.iss.' => 'Генерируем setup.iss.',
      'Generating portable.iss.' => 'Генерируем portable.iss.',
      'The Windows build failed.' => 'Сборка Windows не удалась.',
      'Running ISCC.exe.' => 'Запускаем ISCC.exe.',
      'Running flutter build apk --release.' =>
        'Запускаем flutter build apk --release.',
      'Android release APK was compiled.' => 'Android release APK собран.',
      'Selected artifacts were written to the export folder.' =>
        'Выбранные артефакты записаны в папку экспорта.',
      'Removing the temporary workspace.' => 'Удаляем временную копию проекта.',
      'Temporary files were removed.' => 'Временные файлы удалены.',
      _ => detail,
    };
  }

  String roadmapStatusLabel(String statusName) {
    return switch (statusName) {
      'pending' => _isRu ? 'Ожидает' : 'Pending',
      'running' => _isRu ? 'Выполняется' : 'Running',
      'success' => _isRu ? 'Готово' : 'Done',
      'warning' => _isRu ? 'Ошибка или предупреждение' : 'Error or warning',
      'skipped' => _isRu ? 'Пропущено' : 'Skipped',
      _ => statusName,
    };
  }

  String roadmapStepExpandedDetail(String id) {
    return switch (id) {
      'project' =>
        _isRu
            ? 'PackFoundry проверяет, что выбранная папка похожа на Flutter-проект: есть pubspec.yaml, понятна папка экспорта и можно прочитать базовые настройки приложения.'
            : 'PackFoundry checks that the selected folder looks like a Flutter project: pubspec.yaml exists, the export folder is usable, and basic app metadata can be read.',
      'workspace' =>
        _isRu
            ? 'Проект копируется во временную папку. Размер окна и иконка применяются только к этой копии, поэтому исходники проекта не меняются.'
            : 'The project is copied into a temporary folder. The window size and icon are applied only to that copy, so source files are not modified.',
      'build-script' =>
        _isRu
            ? 'В папку экспорта записываются build_setup.cmd, setup.iss, иконка и файл лицензии. Скрипт запускается двойным щелчком: проверяет Flutter, Visual Studio, Inno Setup и Git, собирает проект и создаёт setup.exe в папке output рядом с собой.'
            : 'build_setup.cmd, setup.iss, the icon and the license file are written to the export folder. Double-click the script: it checks Flutter, Visual Studio, Inno Setup and Git, builds the project and writes setup.exe to the output folder next to it.',
      'windows-build' =>
        _isRu
            ? 'Во временной копии запускается flutter build windows --release. Flutter компилирует приложение, плагины и native runner в build\\windows\\x64\\runner\\Release.'
            : 'flutter build windows --release runs in the temporary copy. Flutter compiles the app, plugins and native runner into build\\windows\\x64\\runner\\Release.',
      'installer' =>
        _isRu
            ? 'PackFoundry генерирует setup.iss из названия, версии, разработчика, сайта, лицензии и иконки, затем ISCC.exe собирает setup.exe и кладёт его в папку экспорта.'
            : 'PackFoundry generates setup.iss from the name, version, publisher, homepage, license and icon, then ISCC.exe compiles setup.exe into the export folder.',
      'portable' =>
        _isRu
            ? 'PackFoundry генерирует portable.iss, и ISCC.exe упаковывает приложение в один exe. При запуске он распаковывает приложение во временную папку, запускает его и удаляет папку после закрытия. В систему ничего не устанавливается.'
            : 'PackFoundry generates portable.iss and ISCC.exe packs the app into one exe. When started, it unpacks the app into a temporary folder, runs it and deletes the folder once the app closes. Nothing is installed.',
      'android-build' =>
        _isRu
            ? 'Во временной копии запускается flutter build apk --release через Gradle и Android SDK.'
            : 'flutter build apk --release runs in the temporary copy through Gradle and the Android SDK.',
      'summary' =>
        _isRu
            ? 'На этом этапе PackFoundry подтверждает, что выбранные артефакты записаны в папку экспорта, и завершает общий прогресс сборки.'
            : 'At this step, PackFoundry confirms that selected artifacts were written to the export folder and completes the overall build progress.',
      'cleanup' =>
        _isRu
            ? 'Удаляется временная копия проекта вместе с промежуточными файлами сборки.'
            : 'The temporary project copy is removed together with build intermediates.',
      _ =>
        _isRu
            ? 'PackFoundry выполняет технический этап сборки и обновляет прогресс по мере получения событий.'
            : 'PackFoundry runs a technical build step and updates progress as events arrive.',
    };
  }
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
