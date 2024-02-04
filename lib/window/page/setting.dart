import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:starrail_mod_manager/extension/pathops.dart';
import 'package:starrail_mod_manager/service/app_state_service.dart';
import 'package:starrail_mod_manager/third_party/no_deref_file_opener.dart';
import 'package:starrail_mod_manager/window/page/license.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

const itemPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 16);

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(
        title: Text('Settings'),
      ),
      children: [
        SelectItem(
          title: 'Select mod root folder',
          icon: FluentIcons.folder_open,
          path:
              context.select<AppStateService, PathW>((value) => value.modRoot),
          onPressed: () {
            final dir = DirectoryPicker().getDirectory();
            if (dir == null) return;
            context.read<AppStateService>().modRoot = dir.pathW;
          },
        ),
        SelectItem(
          title: 'Select 3D Migoto executable',
          icon: FluentIcons.document_management,
          path: context
              .select<AppStateService, PathW>((value) => value.modExecFile),
          onPressed: () {
            final file = OpenNoDereferenceFilePicker().getFile();
            if (file == null) return;
            context.read<AppStateService>().modExecFile = file.pathW;
          },
        ),
        SelectItem(
          title: 'Select launcher',
          icon: FluentIcons.document_management,
          path: context
              .select<AppStateService, PathW>((value) => value.launcherFile),
          onPressed: () {
            final file = OpenNoDereferenceFilePicker().getFile();
            if (file == null) return;
            context.read<AppStateService>().launcherFile = file.pathW;
          },
        ),
        SwitchItem(
          text: 'Run 3d migoto and launcher using one button',
          checked: context
              .select<AppStateService, bool>((value) => value.runTogether),
          onChanged: (value) {
            context.read<AppStateService>().runTogether = value;
          },
        ),
        SwitchItem(
          text: 'Move folder instead of copying for mod folder drag-and-drop',
          checked: context
              .select<AppStateService, bool>((value) => value.moveOnDrag),
          onChanged: (value) {
            context.read<AppStateService>().moveOnDrag = value;
          },
        ),
        SwitchItem(
          text: 'Show folder icon images',
          checked: context
              .select<AppStateService, bool>((value) => value.showFolderIcon),
          onChanged: (value) {
            context.read<AppStateService>().showFolderIcon = value;
          },
        ),
        SwitchItem(
          text: 'Show enabled mods first',
          checked: context.select<AppStateService, bool>(
              (value) => value.showEnabledModsFirst),
          onChanged: (value) {
            context.read<AppStateService>().showEnabledModsFirst = value;
          },
        ),
        Padding(
          padding: itemPadding,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Licenses',
                  style: FluentTheme.of(context).typography.bodyLarge,
                ),
              ),
              RepaintBoundary(
                child: Button(
                  onPressed: () {
                    showLicense(context);
                  },
                  child: const Text('View'),
                ),
              )
            ],
          ),
        ),
        Padding(
          padding: itemPadding,
          child: FutureBuilder(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Text('Loading...');
              }
              final packageInfo = snapshot.data as PackageInfo;
              return Text(
                'Version: ${packageInfo.version}',
                style: FluentTheme.of(context).typography.caption,
              );
            },
          ),
        ),
      ],
    );
  }

  void showLicense(BuildContext context) {
    Navigator.of(context).push(FluentPageRoute(
      builder: (BuildContext context) => const OssLicensesPage(),
    ));
  }
}

class SwitchItem extends StatelessWidget {
  final String text;
  final bool checked;
  final void Function(bool) onChanged;

  const SwitchItem({
    super.key,
    required this.text,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: itemPadding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: FluentTheme.of(context).typography.bodyLarge,
            ),
          ),
          RepaintBoundary(
            child: ToggleSwitch(
              checked: checked,
              onChanged: onChanged,
            ),
          )
        ],
      ),
    );
  }
}

class SelectItem extends StatelessWidget {
  final String title;
  final PathW path;
  final IconData icon;
  final VoidCallback? onPressed;

  const SelectItem({
    super.key,
    required this.title,
    required this.icon,
    required this.path,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: itemPadding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FluentTheme.of(context).typography.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  path.asString,
                  style: FluentTheme.of(context).typography.caption,
                ),
              ],
            ),
          ),
          RepaintBoundary(
            child: Button(
              onPressed: onPressed,
              child: Icon(icon),
            ),
          )
        ],
      ),
    );
  }
}
