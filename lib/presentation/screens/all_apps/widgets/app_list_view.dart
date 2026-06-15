import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../data/database/app_database.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/app_list_provider.dart';
import '../../../providers/favorites_provider.dart';

class AppListView extends ConsumerWidget {
  const AppListView({required this.scrollController, super.key});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = ref.watch(groupedAppsProvider);
    final blocking = ref.watch(platformChannelServiceProvider).blocking;
    // PERF: Set per lookup O(1). `favs.contains` veniva chiamato 2 volte per
    // ogni tile (isFavorite + menu contestuale) su una List → O(n) per tile.
    final favs =
        (ref.watch(favoritesProvider).valueOrNull ?? const <String>[]).toSet();
    final favoritesController = ref.watch(favoritesControllerProvider);
    final folders =
        ref.watch(foldersProvider).valueOrNull ?? const <LauncherFolder>[];

    if (grouped.isEmpty) {
      return Center(
        child: Text(
          'No matching apps',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: KoruColors.textSecondary),
        ),
      );
    }

    // PERF: appiattiamo i gruppi in un'unica lista [header | app] e usiamo
    // ListView.builder, così solo le righe visibili vengono costruite. Prima
    // `ListView(children:)` materializzava il Widget di OGNI app a ogni rebuild
    // (es. a ogni keystroke di ricerca). Le altezze restano fisse (header 40 /
    // tile 50): coerenti con `_computeSectionOffsets` della FastScroller, e il
    // `padding: top: 4` sostituisce il vecchio SizedBox(height: 4) iniziale,
    // preservando gli offset di scroll.
    final rows = <Object>[];
    for (final entry in grouped.entries) {
      rows.add(entry.key); // String → header di sezione
      rows.addAll(entry.value); // InstalledAppInfo → riga app
    }

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, right: 42),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is String) return _SectionHeader(letter: row);
        final app = row as InstalledAppInfo;
        return _AppTile(
          app: app,
          isFavorite: favs.contains(app.packageName),
          onTap: () => blocking.launchApp(app.packageName),
          onLongPress: () => showAppContextMenu(
            context: context,
            app: app,
            isFavorite: favs.contains(app.packageName),
            currentFolderId: null,
            folders: folders,
            favoritesController: favoritesController,
            blocking: blocking,
          ),
        );
      },
    );
  }
}

/// Bottom sheet contestuale per un'app: favorite/unfavorite, sposta/rimuovi da
/// cartella, app info, uninstall. Condiviso tra drawer e lista favoriti.
///
/// [currentFolderId] è la cartella in cui l'app si trova ORA (valorizzato solo
/// quando il menu è aperto da dentro una cartella nel launcher): se non null
/// abilita "Remove from folder". [folders] sono le cartelle proposte come
/// destinazione da "Move to folder…".
Future<void> showAppContextMenu({
  required BuildContext context,
  required InstalledAppInfo app,
  required bool isFavorite,
  required List<LauncherFolder> folders,
  required FavoritesController favoritesController,
  required BlockingChannel blocking,
  int? currentFolderId,
}) {
  return showStyledSheet(
    context: context,
    title: app.label,
    subtitle: 'App options',
    builder: (ctx) => [
      SheetActionTile(
        icon: isFavorite ? Icons.star_border : Icons.star,
        label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
        accent: KoruColors.primary,
        onTap: () async {
          final messenger = ScaffoldMessenger.maybeOf(context);
          Navigator.pop(ctx);
          try {
            if (isFavorite) {
              await favoritesController.remove(app.packageName);
            } else {
              await favoritesController.add(
                app.packageName,
                label: app.label,
              );
            }
            messenger?.hideCurrentSnackBar();
            messenger?.showSnackBar(
              SnackBar(
                content: Text(
                  isFavorite
                      ? 'Removed ${app.label} from favorites'
                      : 'Added ${app.label} to favorites',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          } catch (e) {
            messenger?.showSnackBar(
              SnackBar(
                content: Text('Favorites update failed: $e'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      ),
      SheetActionTile(
        icon: Icons.drive_file_move_outline,
        label: 'Move to folder…',
        onTap: () {
          Navigator.pop(ctx);
          showMoveToFolderSheet(
            context: context,
            app: app,
            isFavorite: isFavorite,
            currentFolderId: currentFolderId,
            folders: folders,
            favoritesController: favoritesController,
          );
        },
      ),
      if (currentFolderId != null)
        SheetActionTile(
          icon: Icons.folder_off_outlined,
          label: 'Remove from folder',
          onTap: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            Navigator.pop(ctx);
            await favoritesController.moveToFolder(app.packageName, null);
            messenger?.hideCurrentSnackBar();
            messenger?.showSnackBar(
              SnackBar(
                content: Text('Moved ${app.label} back to home'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      SheetActionTile(
        icon: Icons.info_outline,
        label: 'App info',
        onTap: () {
          Navigator.pop(ctx);
          blocking.openAppInfo(app.packageName);
        },
      ),
      const _SheetDivider(),
      SheetActionTile(
        icon: Icons.delete_outline,
        label: 'Uninstall',
        danger: true,
        onTap: () async {
          final messenger = ScaffoldMessenger.maybeOf(context);
          Navigator.pop(ctx);
          try {
            await blocking.uninstallApp(app.packageName);
          } on PlatformException catch (e) {
            // Strict mode con BLOCK_UNINSTALLING attivo: il native
            // rifiuta prima di lanciare l'intent. Invece di lasciare
            // l'utente con "non succede niente", spieghiamo perché.
            if (e.code == 'BLOCK_UNINSTALLING') {
              if (context.mounted) await _showUninstallBlockedDialog(context);
            } else if (messenger != null) {
              // Qualsiasi ALTRO fallimento del native (es. nessuna activity
              // di sistema gestisce la disinstallazione su certi ROM OEM →
              // UNINSTALL_FAILED): prima veniva ingoiato qui e l'utente
              // vedeva "non succede niente". Diamo un feedback esplicito.
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Impossibile disinstallare ${app.label}: '
                    '${e.message ?? e.code}',
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        },
      ),
    ],
  );
}

/// Alert mostrato quando la disinstallazione viene rifiutata dal native perché
/// la modalità rigida (BLOCK_UNINSTALLING) è attiva. Senza questo, il tap su
/// "Uninstall" sembrava non fare nulla (il package installer veniva rimandato
/// indietro dallo StrictModeEnforcer).
Future<void> _showUninstallBlockedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Strict mode active'),
      content: const Text(
        'Uninstalling is blocked from here while Strict mode uninstall '
        'protection is on. Turn that option off in Strict mode settings '
        'to uninstall apps.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Bottom sheet che elenca le cartelle disponibili come destinazione, più la
/// voce "New folder…". Alla scelta assegna l'app: se non ancora favorita la
/// favorita direttamente dentro la cartella, altrimenti la sposta.
Future<void> showMoveToFolderSheet({
  required BuildContext context,
  required InstalledAppInfo app,
  required bool isFavorite,
  required int? currentFolderId,
  required List<LauncherFolder> folders,
  required FavoritesController favoritesController,
}) {
  final targets =
      folders.where((f) => f.id != currentFolderId).toList(growable: false);
  return showStyledSheet(
    context: context,
    title: 'Move "${app.label}"',
    subtitle: 'Choose a destination folder',
    builder: (ctx) => [
      for (final f in targets)
        SheetActionTile(
          icon: Icons.folder_outlined,
          label: f.name,
          onTap: () async {
            Navigator.pop(ctx);
            await _assignToFolder(favoritesController, app, isFavorite, f.id);
          },
        ),
      SheetActionTile(
        icon: Icons.create_new_folder_outlined,
        label: 'New folder…',
        accent: KoruColors.primary,
        onTap: () async {
          Navigator.pop(ctx);
          if (!context.mounted) return;
          final name = await showFolderNameDialog(context);
          if (name == null) return;
          final id = await favoritesController.createFolder(name);
          await _assignToFolder(favoritesController, app, isFavorite, id);
        },
      ),
    ],
  );
}

Future<void> _assignToFolder(
  FavoritesController controller,
  InstalledAppInfo app,
  bool isFavorite,
  int folderId,
) {
  if (isFavorite) {
    return controller.moveToFolder(app.packageName, folderId);
  }
  return controller.add(app.packageName, label: app.label, folderId: folderId);
}

/// Apre un bottom sheet contestuale con lo stile Koru condiviso: superficie
/// elevata, angoli arrotondati, drag handle e header (titolo + sottotitolo).
/// Il [builder] restituisce le righe d'azione ([SheetActionTile]) renderizzate
/// sotto l'header.
Future<void> showStyledSheet({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<Widget> Function(BuildContext ctx) builder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: KoruColors.surfaceElevated,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ContextSheet(
      title: title,
      subtitle: subtitle,
      children: builder(ctx),
    ),
  );
}

/// Layout del bottom sheet contestuale: drag handle, intestazione e le righe
/// d'azione passate in [children].
class _ContextSheet extends StatelessWidget {
  const _ContextSheet({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: KoruColors.textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 18, 24, subtitle == null ? 14 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: KoruColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Riga d'azione di un bottom sheet contestuale: icona in un chip arrotondato
/// più etichetta. [accent] tinge l'icona/il chip per le azioni primarie (es.
/// preferiti); [danger] usa la palette di pericolo per le azioni distruttive.
class SheetActionTile extends StatelessWidget {
  const SheetActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.accent,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        danger ? KoruColors.danger : KoruColors.textPrimary;
    final Color iconColor =
        danger ? KoruColors.danger : (accent ?? KoruColors.textPrimary);
    final Color chipColor = danger
        ? KoruColors.dangerContainer
        : (accent != null ? KoruColors.primaryContainer : KoruColors.surface);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: foreground),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KoruColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Separatore sottile usato per isolare visivamente le azioni distruttive dal
/// resto delle voci del bottom sheet.
class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Divider(height: 1),
    );
  }
}

/// Dialog per creare (`initial == null`) o rinominare una cartella. Ritorna il
/// nome digitato (trimmed, non vuoto) o `null` se annullato/vuoto.
///
/// Il `TextEditingController` vive dentro un `StatefulWidget` interno
/// ([_FolderNameDialog]) e viene disposto nel suo `dispose()`, durante la
/// teardown del dialog gestita da Flutter. Pattern precedente: controller
/// creato fuori e disposto dopo `await showDialog` causava
/// `_dependents.isEmpty is not true` in `InheritedElement.debugDeactivated()`
/// (framework.dart:6268) perché il TextField era ancora montato durante
/// l'animazione di pop quando il controller veniva disposto.
Future<String?> showFolderNameDialog(
  BuildContext context, {
  String? initial,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => _FolderNameDialog(initial: initial),
  );
  if (result == null || result.isEmpty) return null;
  return result;
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({this.initial});

  final String? initial;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'New folder' : 'Rename folder'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
        decoration: const InputDecoration(hintText: 'Folder name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: KoruColors.textSecondary,
          letterSpacing: 3,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
  });

  final InstalledAppInfo app;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  app.label,
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isFavorite)
                const Icon(Icons.star, size: 16, color: KoruColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
