<p align="center">
  <img src="assets/icon.png" alt="PackFoundry" width="160">
</p>

<h1 align="center">PackFoundry for Windows</h1>

<p align="center">
  Сборка установщиков Flutter-приложений для Windows в несколько кликов.
</p>

PackFoundry — GUI-приложение на Flutter, которое упаковывает Flutter-проекты в готовый `setup.exe` без ручной рутины с `flutter build windows`, Visual Studio и Inno Setup. Это Windows-версия проекта [PackFoundry](https://github.com/Axawys/PackFoundry), изначально написанного под Linux.

Главная идея: выбрать проект, указать метаданные релиза, отметить нужные цели и нажать «Собрать». PackFoundry проверяет инструменты, готовит временную копию проекта, собирает приложение, генерирует сценарий Inno Setup и сохраняет установщик в выбранную папку.

## Возможности

- **setup.exe**: сборка Windows-установщика прямо на этом компьютере (`flutter build windows --release` + Inno Setup).
- **build_setup.cmd**: экспорт самодостаточного скрипта, который собирает тот же `setup.exe` на любом Windows-компьютере двойным щелчком.
- **APK**: сборка Android APK через Flutter и Android SDK и отправка на подключённое устройство через `adb`.
- Проверка и установка инструментов из настроек: Flutter SDK, Git, Visual Studio Build Tools (C++), Inno Setup, режим разработчика, Android SDK и Java (через `winget`).
- Иконка `.png` или `.ico` превращается в `.ico` для установщика и для `windows\runner\resources\app_icon.ico`.
- Экран сборки: план этапов с прогрессом, команды `cmd.exe` для каждого этапа и журнал с живым выводом `flutter` и `ISCC`.
- Кнопка запуска проекта без сборки (`flutter run -d windows`).
- Конфигурационный файл `packfoundry.json` для повторяемых сборок.
- Русская и английская локализация, светлая/тёмная/системная тема.

## Требования

| Инструмент | Для чего | Установка |
| --- | --- | --- |
| Flutter SDK | любая сборка | [docs.flutter.dev](https://docs.flutter.dev/get-started/install/windows/desktop) или кнопка в «Настройках» (клонирует в `%LOCALAPPDATA%\PackFoundry\flutter`) |
| Git | Flutter SDK и git-зависимости | `winget install --id Git.Git -e` |
| Visual Studio 2022 / Build Tools с «Desktop development with C++» | `flutter build windows` | `winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"` |
| Inno Setup 6 | `setup.exe` | `winget install --id JRSoftware.InnoSetup -e` |
| Режим разработчика Windows | проекты с плагинами (symlink) | `start ms-settings:developers` |
| Android SDK, Java | только APK | кнопка в «Настройках» (`%LOCALAPPDATA%\PackFoundry\android-sdk`, `Microsoft.OpenJDK.17`) |

PackFoundry ищет `flutter.bat`, `ISCC.exe`, `git.exe` и `vswhere.exe` по файлам: в `PATH`, в `Program Files`, `Program Files (x86)` и `%LOCALAPPDATA%\Programs`, поэтому ничего не нужно добавлять в `PATH` вручную.

## Рабочие пространства

### Настройки

Доступность инструментов по группам (FLUTTER, EXE, APK) с кнопкой установки недостающего, а также тема, язык и папка экспорта по умолчанию.

### Проект

- папка Flutter-проекта и импорт/экспорт `packfoundry.json`;
- размер окна Windows-приложения (патчится `windows\runner\main.cpp` во временной копии);
- иконка `.png`, `.ico` или `.svg` (SVG используется только для предпросмотра, для установщика берётся иконка runner);
- тег релиза, разработчик, email, сайт, лицензия и описание;
- название приложения (из него строится имя выходного файла) и папка экспорта;
- цели сборки: `setup.exe`, `build_setup.cmd`, `apk`.

Настройки окна и иконки применяются только к временной копии проекта, исходники не переписываются.

### Сборка

- «Собрать» — собрать выбранные цели; «Запустить» — `flutter run -d windows` для проверки.
- Слева «План сборки» — этапы со статусом и прогрессом.
- Справа сверху — команды `cmd.exe` выбранного этапа с реальными путями; их можно скопировать по этапу или целиком как `.cmd`-скрипт.
- Справа снизу — журнал процессов с выводом `flutter build` и `ISCC.exe` в реальном времени.

## Цели сборки

### setup.exe

1. Проект копируется во `%TEMP%\pack_foundry_build_*` (вместе с локальными `path:`-зависимостями).
2. Применяются размер окна и иконка.
3. `flutter build windows --release`.
4. Генерируется `setup.iss`: название, версия из тега, издатель, сайт, email, лицензия и описание, иконка, файл `LICENSE` проекта (если есть), русский и английский языки мастера, ярлыки в меню «Пуск» и на рабочем столе.
5. `ISCC.exe` компилирует установщик в папку экспорта.

Установщик позволяет поставить приложение для всех пользователей или только для текущего (без прав администратора) и поддерживает тихую установку `/VERYSILENT /CURRENTUSER`.

### build_setup.cmd

В папку экспорта записываются `build_setup.cmd`, `setup.iss`, `setup.ico` и `license.txt`. Скрипт:

- проверяет Flutter, Git, Visual Studio с C++ (через `vswhere`) и Inno Setup, для отсутствующих выводит команду `winget` или ссылку;
- предупреждает, если выключен режим разработчика;
- выполняет `flutter pub get` и `flutter build windows --release`;
- собирает установщик через `ISCC` в папку `output` рядом со скриптом и печатает путь к нему;
- при ошибке завершается с кодом 1; в конце всегда делает `pause`, чтобы окно не закрылось.

Папка проекта берётся из первого аргумента, иначе — папка скрипта, если в ней лежит `pubspec.yaml`, иначе — путь проекта, выбранный в PackFoundry:

```bat
build_setup.cmd D:\src\hash_checker
```

`set PACKFOUNDRY_NO_PAUSE=1` отключает финальную паузу (удобно для CI). Скрипт собирает исходный проект как есть, без временной копии: размер окна и иконка runner из PackFoundry к нему не применяются.

> MSBuild не работает с очень длинными путями (ошибка `FTK1011`). Если проект лежит глубоко, перенесите его ближе к корню диска.

### APK

`flutter build apk --release` во временной копии и копирование в экспорт. Кнопка «Отправить на устройство» собирает APK в папке проекта и ставит его через `adb install -r` с обработкой понижения версии и конфликта подписи.

## Конфигурационный файл

```json
{
  "schema": "packfoundry.config.v1",
  "projectPath": "$choose_in_packfoundry",
  "outputPath": "$choose_in_packfoundry",
  "iconPath": "assets/icon.png",
  "appName": "HashChecker",
  "releaseTag": "v1.3.0",
  "developerEmail": "dev@example.com",
  "publisherName": "Example Studio",
  "homepageUrl": "https://example.com/hashchecker",
  "license": "GPL-2.0-only",
  "description": "A desktop tool for checking file hashes.",
  "window": { "width": 1280, "height": 800 },
  "packageTypes": ["exe", "cmd", "apk"]
}
```

`$choose_in_packfoundry` означает, что путь выбирается в интерфейсе. Относительные пути считаются от папки конфига. Поддерживаемые `packageTypes`: `exe`, `cmd`, `apk`.

## Имена выходных файлов

```text
AppName_windows_1.3.0_x64_setup.exe
AppName_android_1.3.0_universal.apk
```

## Разработка

```bat
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release
```

## Структура проекта

```text
lib/
  core/
    models/       # модели сборки, конфигов и инструментов
    services/     # сборка, Windows-инструменты, генерация setup.iss и build_setup.cmd, конфиги
  l10n/           # локализация
  ui/
    pages/        # основные страницы приложения
    widgets/      # UI-компоненты
```

## Лицензия

PackFoundry распространяется под лицензией GNU General Public License version 2.0 only.

См. файл [LICENSE](LICENSE).
