import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:starrail_mod_manager/base/appbar.dart';
import 'package:starrail_mod_manager/extension/pathops.dart';
import 'package:starrail_mod_manager/io/fsops.dart';
import 'package:starrail_mod_manager/service/app_state_service.dart';
import 'package:starrail_mod_manager/service/folder_observer_service.dart';
import 'package:starrail_mod_manager/service/preset_service.dart';
import 'package:starrail_mod_manager/third_party/fluent_ui/auto_suggest_box.dart';
import 'package:starrail_mod_manager/third_party/fluent_ui/red_filled_button.dart';
import 'package:starrail_mod_manager/widget/folder_drop_target.dart';
import 'package:starrail_mod_manager/window/page/category.dart';
import 'package:starrail_mod_manager/window/page/setting.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

class HomeWindow extends StatefulWidget {
  const HomeWindow({super.key});

  @override
  State<HomeWindow> createState() => _HomeWindowState();
}

class _HomeWindowState<T extends StatefulWidget> extends State<HomeWindow> {
  static const _navigationPaneOpenWidth = 270.0;
  static final _logger = Logger();

  final textEditingController = TextEditingController();

  Key? selectedKey;
  int? selected;
  bool updateDisplayed = false;

  Future<void> _checkUpdate() async {
    const baseLink =
        'https://github.com/traveling-lumine/starrail_mod_manager/releases/latest';
    final url = Uri.parse(baseLink);
    final client = http.Client();
    final request = http.Request('GET', url)..followRedirects = false;
    final upstreamVersion = client.send(request).then((value) {
      final location = value.headers['location'];
      if (location == null) return null;
      final lastSlash = location.lastIndexOf('tag/v');
      if (lastSlash == -1) return null;
      return location.substring(lastSlash + 5, location.length);
    });
    final currentVersion =
        PackageInfo.fromPlatform().then((value) => value.version);
    final List<String?> versions =
        await Future.wait([upstreamVersion, currentVersion]);
    final upVersion = versions[0];
    final curVersion = versions[1];
    if (upVersion == null || curVersion == null) return;
    final upstream =
        upVersion.split('.').map(int.parse).toList(growable: false);
    final current =
        curVersion.split('.').map(int.parse).toList(growable: false);
    bool shouldUpdate = false;
    for (var i = 0; i < 3; i++) {
      if (upstream[i] > current[i]) {
        shouldUpdate = true;
        break;
      } else if (upstream[i] < current[i]) {
        break;
      }
    }
    if (!shouldUpdate) return;
    if (!context.mounted) return;
    unawaited(displayInfoBar(
      context,
      duration: const Duration(minutes: 1),
      builder: (_, close) => InfoBar(
        title: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(text: 'New version available: '),
              TextSpan(
                text: upVersion,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '. Click '),
              TextSpan(
                text: 'here',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => launchUrl(url),
              ),
              const TextSpan(text: ' to open link.'),
            ],
          ),
        ),
        action: FilledButton(
          onPressed: () async {
            unawaited(showDialog(
              context: context,
              builder: (context2) => ContentDialog(
                title: const Text('Start auto update?'),
                content: RichText(
                  textAlign: TextAlign.justify,
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      const TextSpan(
                        text:
                            'This will download the latest version and replace the current one.'
                            ' This feature is experimental and may not work as expected.\n',
                        // justify
                      ),
                      TextSpan(
                        text:
                            'Please backup your mods and resources before proceeding.\nDELETION OF UNRELATED FILES IS POSSIBLE.',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                actions: [
                  Button(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context2).pop();
                    },
                  ),
                  RedFilledButton(
                    child: const Text('Start'),
                    onPressed: () async {
                      Navigator.of(context2).pop();
                      final url =
                          Uri.parse('$baseLink/download/StarrailModManager.zip');
                      final response = await http.get(url);
                      final archive =
                          ZipDecoder().decodeBytes(response.bodyBytes);
                      for (final aFile in archive) {
                        final path = '${Directory.current.path}/${aFile.name}';
                        if (aFile.isFile) {
                          await File(path).writeAsBytes(aFile.content);
                        } else {
                          Directory(path).createSync(recursive: true);
                        }
                      }
                      const updateScript = "@echo update script running\n"
                          "for /f \"delims=\" %%i in ('dir /b /a-d ^| findstr /v /i \"update.cmd\"') do del \"%%i\"\n"
                          "for /f \"delims=\" %%i in ('dir /b /ad ^| findstr /v /i \"Resources StarrailModManager\"') do rd /s /q \"%%i\"\n"
                          "cd StarrailModManager\n"
                          "for /f \"delims=\" %%i in ('dir /b ^| findstr /v /i \"Resources\"') do move \"%%i\" ..\n"
                          "cd ..\n"
                          "rd /s /q StarrailModManager\n"
                          "start starrail_mod_manager.exe\n"
                          "del update.cmd";
                      await File('update.cmd').writeAsString(updateScript);
                      unawaited(Process.run(
                        'start',
                        [
                          'cmd',
                          '/c',
                          'timeout /t 3 && call update.cmd > update.log',
                        ],
                        runInShell: true,
                      ));
                      await Future.delayed(const Duration(milliseconds: 200));
                      exit(0);
                    },
                  ),
                ],
              ),
            ));
          },
          child: const Text('Auto update'),
        ),
        onClose: close,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!updateDisplayed) {
      updateDisplayed = true;
      unawaited(_checkUpdate());
    }

    final imageFiles =
        context.select<CategoryIconFolderObserverService, List<File>>(
            (value) => value.curFiles);
    final sortedMenus = context
        .select<DirWatchService, List<String>>(
            (value) => value.curDirs.map((e) => e.path).toList(growable: false))
        .map((e) => PathW(e))
        .toList(growable: false)
      ..sort(
        (a, b) => compareNatural(a.basename.asString, b.basename.asString),
      );
    final List<_FolderPaneItem> subFolders = sortedMenus
        .map((e) => _FolderPaneItem(
              dirPath: e,
              imageFile: findPreviewFileIn(imageFiles, name: e.basename),
            ))
        .toList(growable: false);

    final List<NavigationPaneItem> footerItems = [
      PaneItemSeparator(
        key: const ValueKey('<separator>'),
      ),
      ..._buildPaneItemActions(),
      PaneItem(
        key: const ValueKey('<settings>'),
        icon: const Icon(FluentIcons.settings),
        title: const Text('Settings'),
        body: const SettingPage(),
      ),
    ];

    final List<NavigationPaneItem> combined = [
      ...subFolders,
      ...footerItems,
    ];

    // search matching key in combined list
    final idx = combined.indexWhere((e) => e.key == selectedKey);

    if (idx == -1) {
      if (subFolders.isEmpty) {
        selected = combined.length - 1;
        selectedKey = combined.last.key;
      } else {
        final selVal = selected;
        final afterVal =
            selVal == null ? 0 : selVal.clamp(0, subFolders.length - 1);
        selected = afterVal;
        selectedKey = subFolders[afterVal].key;
      }
    } else {
      selected = idx;
    }

    return NavigationView(
      transitionBuilder: (child, animation) =>
          SuppressPageTransition(child: child),
      appBar: () {
        return NavigationAppBar(
          actions: const WindowButtons(),
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: DragToMoveArea(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Starrail Mod Manager'),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildPresetAddIcon(),
                  const SizedBox(width: 8),
                  _buildPresetSelect(),
                  const SizedBox(width: 138),
                ],
              ),
            ],
          ),
        );
      }(),
      pane: NavigationPane(
        selected: selected,
        onChanged: (value) => _setSelectedState(value, combined[value].key!),
        displayMode: PaneDisplayMode.auto,
        size: const NavigationPaneSize(
            openWidth: _HomeWindowState._navigationPaneOpenWidth),
        autoSuggestBox: _buildAutoSuggestBox(subFolders, combined),
        autoSuggestBoxReplacement: const Icon(FluentIcons.search),
        items: subFolders.map((e) {
          // haha... blame List<T>::+ operator
          // ignore: unnecessary_cast
          return e as NavigationPaneItem;
        }).toList(growable: false),
        footerItems: footerItems,
      ),
    );
  }

  Widget _buildPresetSelect() {
    return Selector<PresetService, List<String>>(
      selector: (p0, p1) => p1.getGlobalPresets(),
      builder: (context, value, child) => ComboBox(
        items: value
            .map((e) => ComboBoxItem(value: e, child: Text(e)))
            .toList(growable: false),
        placeholder: const Text('Global Preset...'),
        onChanged: (value) => showDialog(
          barrierDismissible: true,
          context: context,
          builder: (context2) => ContentDialog(
            title: const Text('Apply Global Preset?'),
            content: Text('Preset name: $value'),
            actions: [
              RedFilledButton(
                child: const Text('Delete'),
                onPressed: () {
                  Navigator.of(context2).pop();
                  context.read<PresetService>().removeGlobalPreset(value!);
                },
              ),
              Button(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context2).pop();
                },
              ),
              FilledButton(
                child: const Text('Apply'),
                onPressed: () {
                  Navigator.of(context2).pop();
                  context.read<PresetService>().setGlobalPreset(value!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetAddIcon() {
    return IconButton(
      icon: const Icon(FluentIcons.add),
      onPressed: () {
        showDialog(
          barrierDismissible: true,
          context: context,
          builder: (context2) {
            return ContentDialog(
              title: const Text('Add Global Preset'),
              content: SizedBox(
                height: 40,
                child: TextBox(
                  controller: textEditingController,
                  placeholder: 'Preset Name',
                ),
              ),
              actions: [
                Button(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context2).pop();
                  },
                ),
                FilledButton(
                  child: const Text('Add'),
                  onPressed: () {
                    Navigator.of(context2).pop();
                    final text = textEditingController.text;
                    textEditingController.clear();
                    context.read<PresetService>().addGlobalPreset(text);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<PaneItemAction> _buildPaneItemActions() {
    const icon = Icon(FluentIcons.user_window);
    return context.select<AppStateService, bool>((value) => value.runTogether)
        ? [
            PaneItemAction(
              key: const ValueKey('<run_both>'),
              icon: icon,
              title: const Text('Run 3d migoto & launcher'),
              onTap: () {
                _runMigoto();
                _runLauncher();
              },
            ),
          ]
        : [
            PaneItemAction(
              key: const ValueKey('<run_migoto>'),
              icon: icon,
              title: const Text('Run 3d migoto'),
              onTap: () => _runMigoto(),
            ),
            PaneItemAction(
              key: const ValueKey('<run_launcher>'),
              icon: icon,
              title: const Text('Run launcher'),
              onTap: () => _runLauncher(),
            ),
          ];
  }

  Widget _buildAutoSuggestBox(
      List<_FolderPaneItem> subFolders, List<NavigationPaneItem> combined) {
    return AutoSuggestBox2(
      items: subFolders
          .map((e) => AutoSuggestBoxItem2(
                value: e.key,
                label: e.dirPath.basename.asString,
              ))
          .toList(growable: false),
      trailingIcon: const Icon(FluentIcons.search),
      onSelected: (item) {
        final idx = subFolders.indexWhere((e) => e.key == item.value);
        _setSelectedState(idx, combined[idx].key!);
      },
      onSubmissionFailed: (text) {
        if (text.isEmpty) return;
        test(e) {
          final name =
              (e.key as ValueKey<PathW>).value.basename.asString.toLowerCase();
          return name.startsWith(text.toLowerCase());
        }

        final index = subFolders.indexWhere(test);
        if (index == -1) return;
        _setSelectedState(index, combined[index].key!);
      },
    );
  }

  void _runMigoto() {
    final path = context.read<AppStateService>().modExecFile;
    runProgram(path.toFile);
    displayInfoBar(
      context,
      builder: (context, close) {
        return InfoBar(
          title: const Text('Ran 3d migoto'),
          onClose: close,
        );
      },
    );
    _logger.t('Ran 3d migoto $path');
  }

  void _runLauncher() {
    final launcher = context.read<AppStateService>().launcherFile;
    runProgram(launcher.toFile);
    _logger.t('Ran launcher $launcher');
  }

  void _setSelectedState(int index, Key key) {
    setState(() {
      selected = index;
      selectedKey = key;
    });
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Key>('selectedKey', selectedKey));
    properties.add(IntProperty('selected', selected));
  }
}

class _FolderPaneItem extends PaneItem {
  static const maxIconWidth = 80.0;

  static Widget _getIcon(File? imageFile) {
    return Selector<AppStateService, bool>(
      selector: (_, service) => service.showFolderIcon,
      builder: (_, value, __) =>
          value ? _buildImage(imageFile) : const Icon(FluentIcons.folder_open),
    );
  }

  static Widget _buildImage(File? imageFile) {
    final Image image;
    if (imageFile == null) {
      image = Image.asset('images/app_icon.ico');
    } else {
      image = Image.file(
        imageFile,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxIconWidth),
      child: AspectRatio(
        aspectRatio: 1,
        child: image,
      ),
    );
  }

  PathW dirPath;

  _FolderPaneItem({
    required this.dirPath,
    File? imageFile,
  }) : super(
          title: Text(
            dirPath.basename.asString,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          icon: _getIcon(imageFile),
          body: DirWatchProvider(
            key: Key(dirPath.asString),
            dir: dirPath.toDirectory,
            child: CategoryPage(dirPath: dirPath),
          ),
          key: ValueKey(dirPath),
        );

  @override
  Widget build(BuildContext context, bool selected, VoidCallback? onPressed,
      {PaneDisplayMode? displayMode,
      bool showTextOnTop = true,
      int? itemIndex,
      bool? autofocus}) {
    return FolderDropTarget(
      dirPath: dirPath,
      child: super.build(
        context,
        selected,
        onPressed,
        displayMode: displayMode,
        showTextOnTop: showTextOnTop,
        itemIndex: itemIndex,
        autofocus: autofocus,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<PathW>('dirPath', dirPath));
  }
}
