import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/koru_type.dart';
import '../../../../core/theme/launcher_phase.dart';
import '../../../../data/database/app_database.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/app_list_provider.dart';
import '../../../providers/favorites_provider.dart';

/// Misure delle righe del drawer.
///
/// Vivono qui e non sparse nei widget perché sono un **contratto**: la
/// fast-scrollbar (`FastScroller` → `AllAppsScreen._computeSectionOffsets`)
/// calcola dove saltare sommando queste altezze senza misurare l'albero. Se
/// cambi una dimensione qui e non lì, il salto su una lettera atterra sul
/// posto sbagliato.
abstract final class AppListMetrics {
  const AppListMetrics._();

  /// Lettera di sezione: enorme e quasi trasparente, sta *sotto* i nomi come
  /// il titolo corrente di una pagina, non sopra come un'etichetta.
  static const double headerFontSize = 46;
  static const double headerPadTop = 16;
  static const double headerPadBottom = 2;

  /// Nome app in modalità sfoglia (nessuna query).
  static const double browseFontSize = 25;
  static const double browseOpacity = 0.92;

  /// Altezza minima di una riga app: il testo è più basso, ma il bersaglio
  /// per il dito no.
  static const double minRowHeight = 46;
  static const double rowPadding = 12;

  static const double topPadding = 4;

  /// Corridoio riservato al rail A-Z sul bordo destro.
  static const double railGutter = 44;

  static double headerHeight(TextScaler textScaler) =>
      textScaler.scale(headerFontSize) + headerPadTop + headerPadBottom;

  static double rowHeight(TextScaler textScaler, double fontSize) =>
      math.max(minRowHeight, textScaler.scale(fontSize) + rowPadding);
}

/// Scala dei risultati di ricerca: **la rilevanza si legge come dimensione**.
/// Il match migliore è grande e pieno, gli altri arretrano. Oltre il quinto la
/// scala si appiattisce invece di continuare a sparire.
const List<double> _kSearchSizes = [34, 29, 26, 24, 22];
const List<double> _kSearchOpacities = [1, 0.9, 0.8, 0.72, 0.64];

/// Le app del drawer come **parole su una pagina**, non righe di una lista.
///
/// Due modalità, con due gerarchie diverse:
///
/// - **sfoglia** (nessuna query) — sezioni A-Z, con la lettera in serif
///   gigante al 15% di opacità dietro i nomi;
/// - **ricerca** — lista piatta ordinata per rilevanza
///   ([rankedSearchResultsProvider]), dove il rango si legge nella dimensione
///   del testo e la parte che combacia è dipinta in accento.
///
/// In entrambe il contenuto è **ancorato al fondo**: pochi risultati stanno
/// vicino alla riga di query e al pollice, non appesi in cima allo schermo.
class AppListView extends ConsumerWidget {
  const AppListView({
    required this.scrollController,
    required this.phase,
    super.key,
  });

  final ScrollController scrollController;
  final LauncherPhase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searching = ref.watch(appSearchQueryProvider).trim().isNotEmpty;
    final blocking = ref.watch(platformChannelServiceProvider).blocking;
    // PERF: Set per lookup O(1). `favs.contains` veniva chiamato 2 volte per
    // ogni tile (isFavorite + menu contestuale) su una List → O(n) per tile.
    final favs =
        (ref.watch(favoritesProvider).valueOrNull ?? const <String>[]).toSet();
    final favoritesController = ref.watch(favoritesControllerProvider);
    final folders =
        ref.watch(foldersProvider).valueOrNull ?? const <LauncherFolder>[];

    // PERF: appiattiamo tutto in un'unica lista di righe e usiamo
    // ListView.builder, così solo quelle visibili vengono costruite. Prima
    // `ListView(children:)` materializzava il Widget di OGNI app a ogni rebuild
    // (es. a ogni keystroke di ricerca).
    final rows = searching
        ? _searchRows(ref.watch(rankedSearchResultsProvider))
        : _browseRows(ref.watch(groupedAppsProvider));

    if (rows.isEmpty) return _EmptyResults(phase: phase);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        return ListView.builder(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: _topPadding(rows, constraints.maxHeight, textScaler),
            right: AppListMetrics.railGutter,
          ),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];
            return switch (row) {
              _HeaderRow(:final letter) =>
                _SectionHeader(letter: letter, phase: phase),
              _AppRow(:final ranked, :final size, :final opacity) => _AppTile(
                  ranked: ranked,
                  phase: phase,
                  fontSize: size,
                  opacity: opacity,
                  isFavorite: favs.contains(ranked.app.packageName),
                  onTap: () => blocking.launchApp(ranked.app.packageName),
                  onLongPress: () => showAppContextMenu(
                    context: context,
                    app: ranked.app,
                    isFavorite: favs.contains(ranked.app.packageName),
                    currentFolderId: null,
                    folders: folders,
                    favoritesController: favoritesController,
                    blocking: blocking,
                  ),
                ),
            };
          },
        );
      },
    );
  }

  List<_Row> _browseRows(Map<String, List<InstalledAppInfo>> grouped) {
    final rows = <_Row>[];
    for (final entry in grouped.entries) {
      rows.add(_HeaderRow(entry.key));
      for (final app in entry.value) {
        rows.add(
          _AppRow(
            RankedApp(app: app),
            AppListMetrics.browseFontSize,
            AppListMetrics.browseOpacity,
          ),
        );
      }
    }
    return rows;
  }

  List<_Row> _searchRows(List<RankedApp> ranked) {
    return [
      for (var i = 0; i < ranked.length; i++)
        _AppRow(
          ranked[i],
          _kSearchSizes[math.min(i, _kSearchSizes.length - 1)],
          _kSearchOpacities[math.min(i, _kSearchOpacities.length - 1)],
        ),
    ];
  }

  /// Ancoraggio al fondo: padding superiore pari allo spazio avanzato. Vale
  /// `AppListMetrics.topPadding` esattamente quando il contenuto scrolla,
  /// quindi non sposta mai gli offset su cui salta la fast-scrollbar.
  double _topPadding(
    List<_Row> rows,
    double viewportHeight,
    TextScaler textScaler,
  ) {
    var content = 0.0;
    for (final row in rows) {
      content += switch (row) {
        _HeaderRow() => AppListMetrics.headerHeight(textScaler),
        _AppRow(:final size) => AppListMetrics.rowHeight(textScaler, size),
      };
    }
    return math.max(AppListMetrics.topPadding, viewportHeight - content);
  }
}

sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.letter);
  final String letter;
}

class _AppRow extends _Row {
  const _AppRow(this.ranked, this.size, this.opacity);
  final RankedApp ranked;
  final double size;
  final double opacity;
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.phase});

  final LauncherPhase phase;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Text(
          'No matching apps',
          style: KoruType.serif(size: 25, color: phase.ink2),
        ),
      ),
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
        'Uninstalling apps is blocked while strict mode protects '
        'uninstalling. Disable that option in Strict mode settings to '
        'uninstall apps.',
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

/// Lettera di sezione: serif enorme al 15% di opacità. Non è un'etichetta
/// sopra un gruppo — è il segno d'acqua della pagina che stai sfogliando, e
/// per questo non compete con i nomi delle app.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.letter, required this.phase});

  final String letter;
  final LauncherPhase phase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        AppListMetrics.headerPadTop,
        24,
        AppListMetrics.headerPadBottom,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          letter,
          style: KoruType.serif(
            size: AppListMetrics.headerFontSize,
            color: phase.ink,
            opacity: 0.15,
          ),
        ),
      ),
    );
  }
}

/// Una app: una parola. La parte che combacia con la query è l'unico pezzo in
/// accento — il match si legge dentro il nome, senza evidenziazione a blocco.
///
/// Il preferito è marcato da un punto in accento a fine riga invece che da una
/// stella: nel drawer non entra nessuna icona.
class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.ranked,
    required this.phase,
    required this.fontSize,
    required this.opacity,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
  });

  final RankedApp ranked;
  final LauncherPhase phase;
  final double fontSize;
  final double opacity;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final base = KoruType.serif(
      size: fontSize,
      height: 1.1,
      color: phase.ink,
      opacity: opacity,
    );
    final label = ranked.app.label;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppListMetrics.minRowHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: AppListMetrics.rowPadding / 2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  ranked.hasMatch
                      ? TextSpan(
                          children: [
                            TextSpan(text: label.substring(0, ranked.matchStart)),
                            TextSpan(
                              text: label.substring(
                                ranked.matchStart,
                                ranked.matchStart + ranked.matchLength,
                              ),
                              style: TextStyle(color: phase.accent),
                            ),
                            TextSpan(
                              text: label
                                  .substring(ranked.matchStart + ranked.matchLength),
                            ),
                          ],
                        )
                      : TextSpan(text: label),
                  style: base,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isFavorite) ...[
                const SizedBox(width: 10),
                Text(
                  '•',
                  style: KoruType.mono(
                    size: 10,
                    color: phase.accent,
                    opacity: 0.7,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
