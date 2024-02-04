import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:starrail_mod_manager/extension/pathops.dart';
import 'package:starrail_mod_manager/io/fsops.dart';
import 'package:starrail_mod_manager/service/app_state_service.dart';
import 'package:starrail_mod_manager/service/folder_observer_service.dart';
import 'package:starrail_mod_manager/service/preset_service.dart';
import 'package:starrail_mod_manager/third_party/fluent_ui/red_filled_button.dart';
import 'package:starrail_mod_manager/third_party/min_extent_delegate.dart';
import 'package:starrail_mod_manager/widget/chara_mod_card.dart';
import 'package:starrail_mod_manager/widget/folder_drop_target.dart';
import 'package:provider/provider.dart';

class CategoryPage extends StatelessWidget {
  final PathW dirPath;
  final textEditingController = TextEditingController();

  CategoryPage({
    super.key,
    required this.dirPath,
  });

  @override
  Widget build(BuildContext context) {
    return FolderDropTarget(
      dirPath: dirPath,
      child: ScaffoldPage(
        header: PageHeader(
          title: Text(dirPath.basename.asString),
          commandBar: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildPresetAddIcon(context),
              const SizedBox(width: 8),
              _buildPresetSelect(),
              SizedBox(
                width: 60,
                child: CommandBar(
                  mainAxisAlignment: MainAxisAlignment.end,
                  primaryItems: [
                    CommandBarButton(
                      icon: const Icon(FluentIcons.folder_open),
                      onPressed: () {
                        openFolder(dirPath.toDirectory);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: FluentTheme(
          data: FluentThemeData(
            scrollbarTheme: ScrollbarThemeData(
              thickness: 8,
              hoveringThickness: 10,
              scrollbarColor: Colors.grey[140],
            ),
          ),
          child: Selector<AppStateService, bool>(
            selector: (p0, p1) => p1.showEnabledModsFirst,
            builder: (context, enabledFirst, child) {
              return _FolderMatchWidget(enabledFirst: enabledFirst);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPresetSelect() {
    return Selector<PresetService, List<String>>(
      selector: (p0, p1) => p1.getLocalPresets(dirPath.basename.asString),
      builder: (context, value, child) {
        return ComboBox(
          items: value
              .map((e) => ComboBoxItem(
                    value: e,
                    child: Text(e),
                  ))
              .toList(growable: false),
          placeholder: const Text('Local Preset...'),
          onChanged: (value) {
            showDialog(
              barrierDismissible: true,
              context: context,
              builder: (context2) {
                return ContentDialog(
                  title: const Text('Apply Local Preset?'),
                  content: Text('Preset name: $value'),
                  actions: [
                    RedFilledButton(
                      child: const Text('Delete'),
                      onPressed: () {
                        Navigator.of(context2).pop();
                        context.read<PresetService>().removeLocalPreset(
                              dirPath.basename.asString,
                              value!,
                            );
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
                        context.read<PresetService>().setLocalPreset(
                              dirPath.basename.asString,
                              value!,
                            );
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPresetAddIcon(BuildContext context) {
    return IconButton(
      icon: const Icon(FluentIcons.add),
      onPressed: () {
        showDialog(
          barrierDismissible: true,
          context: context,
          builder: (context2) {
            return ContentDialog(
              title: const Text('Add Local Preset'),
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
                    context
                        .read<PresetService>()
                        .addLocalPreset(dirPath.basename.asString, text);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FolderMatchWidget extends StatefulWidget {
  final bool enabledFirst;

  const _FolderMatchWidget({required this.enabledFirst});

  @override
  State<_FolderMatchWidget> createState() => _FolderMatchWidgetState();
}

class _FolderMatchWidgetState extends State<_FolderMatchWidget> {
  static const minCrossAxisExtent = 440.0;
  static const mainAxisExtent = 400.0;

  List<CharaScope>? currentChildren;

  @override
  Widget build(BuildContext context) {
    final dirs = context.watch<DirWatchService>().curDirs
      ..sort(
        (a, b) {
          final a2 = a.pathW.basename.enabledForm.asString;
          final b2 = b.pathW.basename.enabledForm.asString;
          var compareTo = a2.toLowerCase().compareTo(b2.toLowerCase());
          if (widget.enabledFirst) {
            final aEnabled = a.pathW.basename.isEnabled;
            final bEnabled = b.pathW.basename.isEnabled;
            if (aEnabled && !bEnabled) {
              return -1;
            } else if (!aEnabled && bEnabled) {
              return 1;
            }
          }
          return compareTo;
        },
      );

    if (currentChildren == null) {
      currentChildren = dirs.map((e) => _buildCharaCard(e)).toList();
    } else {
      final List<CharaScope> newCurrentChildren = [];
      for (var i = 0; i < dirs.length; i++) {
        final dir = dirs[i];
        final idx = currentChildren!.indexWhere((e) {
          return e.dir.path == dir.path;
        });
        if (idx == -1) {
          newCurrentChildren.add(_buildCharaCard(dir));
        } else {
          newCurrentChildren.add(currentChildren![idx]);
        }
      }
      currentChildren = newCurrentChildren;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMinCrossAxisExtent(
        minCrossAxisExtent: minCrossAxisExtent,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: mainAxisExtent,
      ),
      itemCount: currentChildren!.length,
      itemBuilder: (BuildContext context, int index) => currentChildren![index],
    );
  }

  CharaScope _buildCharaCard(Directory dir) {
    return CharaScope(
      key: Key(dir.path),
      dir: dir,
    );
  }
}
