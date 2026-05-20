/// Modello di presentazione per la home del launcher Koru.
///
/// La home mostra una lista "top-level" che interlaccia app preferite sciolte
/// e cartelle (vedi `launcher_folders_table.dart`). Questi tipi descrivono
/// quella lista già risolta (label dal DB, app disinstallate filtrate) così la
/// UI non deve fare join né raggruppamenti.
library;

/// Una app preferita risolta (package + label).
class LauncherApp {
  const LauncherApp({required this.packageName, required this.label});

  final String packageName;
  final String label;
}

/// Elemento top-level della home: una app sciolta oppure una cartella.
sealed class LauncherItem {
  const LauncherItem();
}

/// App preferita fuori da ogni cartella.
class LauncherLooseApp extends LauncherItem {
  const LauncherLooseApp(this.app);

  final LauncherApp app;
}

/// Cartella che raggruppa app preferite. `apps` è già ordinata e filtrata.
class LauncherFolderItem extends LauncherItem {
  const LauncherFolderItem({
    required this.id,
    required this.name,
    required this.apps,
  });

  final int id;
  final String name;
  final List<LauncherApp> apps;

  int get count => apps.length;
}
