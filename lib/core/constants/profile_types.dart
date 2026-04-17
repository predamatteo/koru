/// Bit flags per [Profile.typeCombinations] — condizioni di attivazione.
abstract class ProfileType {
  static const int time = 1;
  static const int location = 2; // Phase 2
  static const int wifi = 4; // Phase 2
  static const int bluetooth = 8; // Phase 2
  static const int usageLimit = 16;
  static const int launchCount = 32;
  static const int quickBlock = 64;
  static const int strictMode = 0x80000000;

  static bool hasType(int combinations, int type) => combinations & type != 0;
  static int addType(int combinations, int type) => combinations | type;
  static int removeType(int combinations, int type) => combinations & ~type;
}

/// Modalità di matching per le app associate al profilo.
abstract class BlockingMode {
  static const int blocklist = 0; // blocca le app selezionate
  static const int allowlist = 1; // blocca tutto tranne le app selezionate
}

/// Valori speciali di [Profile.pausedUntil].
abstract class PausedUntil {
  static const int notPaused = 0;
  static const int disabledByUser = -1;
}
