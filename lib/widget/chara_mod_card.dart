import 'dart:convert';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:starrail_mod_manager/extension/pathops.dart';
import 'package:starrail_mod_manager/io/fsops.dart';
import 'package:starrail_mod_manager/service/folder_observer_service.dart';
import 'package:starrail_mod_manager/third_party/fluent_ui/red_filled_button.dart';
import 'package:starrail_mod_manager/widget/editor_text.dart';
import 'package:starrail_mod_manager/widget/toggleable.dart';
import 'package:logger/logger.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';

class CharaScope extends StatelessWidget {
  final Directory dir;

  const CharaScope({
    super.key,
    required this.dir,
  });

  @override
  Widget build(BuildContext context) {
    return FileWatchProvider(
      dir: dir,
      child: _CharaModCard(
        dirPath: dir.pathW,
      ),
    );
  }
}

class _CharaModCard extends StatelessWidget {
  static const _minIniSectionWidth = 150.0;
  static final _logger = Logger();

  final PathW dirPath;
  final _contextController = FlyoutController();
  final _contextAttachKey = GlobalKey();

  _CharaModCard({required this.dirPath});

  @override
  Widget build(BuildContext context) {
    return ToggleableMod(
      dirPath: dirPath,
      child: Card(
        backgroundColor: dirPath.basename.isEnabled
            ? Colors.green.lightest
            : Colors.red.lightest.withOpacity(0.5),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            _buildFolderHeader(context),
            const SizedBox(height: 4),
            _buildFolderContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            dirPath.basename.enabledForm.asString,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
        ),
        const SizedBox(width: 4),
        Button(
          child: const Icon(FluentIcons.folder_open),
          onPressed: () => openFolder(dirPath.toDirectory),
        ),
      ],
    );
  }

  Widget _buildFolderContent(BuildContext context) {
    return Expanded(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDesc(context, constraints),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Divider(direction: Axis.vertical),
              ),
              buildIni(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDesc(BuildContext context, BoxConstraints constraints) {
    final v = context.watch<FileWatchService>().curFiles;
    final previewFile = findPreviewFileIn(v);
    if (previewFile == null) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.unknown),
            const SizedBox(height: 4),
            Button(
              onPressed: () async {
                final image = await Pasteboard.image;
                if (image == null) {
                  _logger.d('No image found in clipboard');
                  return;
                }
                final file = dirPath.join(const PathW('preview.png')).toFile;
                await file.writeAsBytes(image);
                if (!context.mounted) return;
                await displayInfoBar(
                  context,
                  builder: (_, close) {
                    return InfoBar(
                      title: const Text('Image pasted'),
                      content: Text('to ${file.path}'),
                      onClose: close,
                    );
                  },
                );
                _logger.d('Image pasted to ${file.path}');
              },
              child: const Text('Paste'),
            )
          ],
        ),
      );
    }
    return _buildImageDesc(context, constraints, previewFile);
  }

  Widget _buildImageDesc(
      BuildContext context, BoxConstraints constraints, File previewFile) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: constraints.maxWidth - _minIniSectionWidth,
      ),
      child: GestureDetector(
        onTapUp: (details) {
          showDialog(
            context: context,
            builder: (context) {
              // add touch to close
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                onSecondaryTap: () => Navigator.of(context).pop(),
                child: Image.memory(
                  previewFile.readAsBytesSync(),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              );
            },
          );
        },
        onSecondaryTapUp: (details) {
          final targetContext = _contextAttachKey.currentContext;
          if (targetContext == null) return;
          final box = targetContext.findRenderObject() as RenderBox;
          final position = box.localToGlobal(
            details.localPosition,
            ancestor: Navigator.of(context).context.findRenderObject(),
          );
          _contextController.showFlyout(
            position: position,
            builder: (context) {
              return FlyoutContent(
                child: SizedBox(
                  width: 120,
                  child: CommandBar(
                    primaryItems: [
                      CommandBarButton(
                        icon: const Icon(FluentIcons.delete),
                        label: const Text('Delete'),
                        onPressed: () => _showDialog(context, previewFile),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        child: FlyoutTarget(
          controller: _contextController,
          key: _contextAttachKey,
          child: Image.memory(
            previewFile.readAsBytesSync(),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, File previewFile) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ContentDialog(
        title: const Text('Delete preview image?'),
        content:
            const Text('Are you sure you want to delete the preview image?'),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
          ),
          RedFilledButton(
            onPressed: () {
              previewFile.deleteSync();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              displayInfoBar(
                context,
                builder: (context, close) => InfoBar(
                  title: const Text('Preview deleted'),
                  content: Text('Preview deleted from ${previewFile.path}'),
                  severity: InfoBarSeverity.warning,
                  onClose: close,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget buildIni() {
    final alliniFile = allFilesToWidget();
    return Expanded(
      child: alliniFile.isNotEmpty
          ? Card(
              backgroundColor: Colors.white.withOpacity(0.4),
              padding: const EdgeInsets.all(4),
              child: ListView(
                children: alliniFile,
              ),
            )
          : const Center(
              child: Text('No ini files found'),
            ),
    );
  }

  List<Widget> allFilesToWidget() {
    final allFiles = getActiveiniFiles(dirPath.toDirectory);
    final List<Widget> alliniFile = [];
    for (final file in allFiles) {
      alliniFile.add(buildIniHeader(file));
      late String lastSection;
      bool metSection = false;
      file
          .readAsLinesSync(encoding: const Utf8Codec(allowMalformed: true))
          .forEach((line) {
        if (line.startsWith('[')) {
          metSection = false;
        }
        final regExp = RegExp(r'\[Key.*?\]');
        final match = regExp.firstMatch(line)?.group(0)!;
        if (match != null) {
          alliniFile.add(Text(match));
          lastSection = match;
          metSection = true;
        }
        final lineLower = line.toLowerCase();
        if (lineLower.startsWith('key')) {
          alliniFile.add(buildIniFieldEditor('key:', lastSection, line, file));
        } else if (lineLower.startsWith('back')) {
          alliniFile.add(buildIniFieldEditor('back:', lastSection, line, file));
        } else if (line.startsWith('\$') && metSection) {
          final cycles = ','.allMatches(line.split(';').first).length + 1;
          alliniFile.add(Text('Cycles: $cycles'));
        }
      });
    }
    return alliniFile;
  }

  Widget buildIniHeader(File iniFile) {
    final basenameString = iniFile.pathW.basename.asString;
    return Row(
      children: [
        Expanded(
          child: Tooltip(
            message: basenameString,
            child: Text(
              basenameString,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Button(
          child: const Icon(FluentIcons.document_management),
          onPressed: () => runProgram(iniFile),
        ),
      ],
    );
  }

  Widget buildIniFieldEditor(
      String data, String section, String line, File file) {
    return Row(
      children: [
        Text(data),
        Expanded(
          child: EditorText(
            section: section,
            line: line,
            file: file,
          ),
        ),
      ],
    );
  }
}
