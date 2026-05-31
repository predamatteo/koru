import 'package:async/async.dart';
import 'package:drift/drift.dart';

import '../../domain/entities/blocked_section.dart';
import '../../platform/profile_channel.dart';
import '../database/app_database.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  ProfileRepository({required AppDatabase db, required ProfileChannel channel})
    : _db = db,
      _channel = channel;

  final AppDatabase _db;
  final ProfileChannel _channel;

  // ─── Watchers / reads ─────────────────────────────────────────────────────

  Stream<List<ProfileModel>> watchAllProfiles() {
    // Merge di 3 watch: profiles + app_profile_relations + intervals.
    // Ogni mutazione su relations/intervals rigenera i ProfileModel
    // (count app, in-app sections, orari) senza aspettare che cambi la
    // riga `profiles` stessa.
    final trigger = StreamGroup.merge<dynamic>([
      _db.watchAllProfiles(),
      _db.select(_db.appProfileRelations).watch(),
      _db.select(_db.intervals).watch(),
    ]);
    return trigger.asyncMap((_) async {
      final profiles = await _db.getAllProfiles();
      final models = <ProfileModel>[];
      for (final p in profiles) {
        models.add(await _loadRelations(p));
      }
      return models;
    });
  }

  Future<ProfileModel?> getProfileWithRelations(int id) async {
    final profile = await _db.getProfileById(id);
    if (profile == null) return null;
    return _loadRelations(profile);
  }

  Future<ProfileModel> _loadRelations(Profile profile) async => ProfileModel(
    data: profile,
    apps: await _db.getAppsForProfile(profile.id),
    websites: await _db.getWebsiteRulesForProfile(profile.id),
    intervals: await _db.getIntervalsForProfile(profile.id),
    usageLimits: await _db.getUsageLimitsForProfile(profile.id),
  );

  // ─── Mutations ────────────────────────────────────────────────────────────

  Future<int> createProfile({
    required String title,
    String emoji = 'NoIcon',
    int blockingMode = 0,
    int dayFlags = 127,
    int typeCombinations = 1,
    String colorHex = '#5C8262',
    int? presetId,
  }) async {
    final id = await _db.insertProfile(
      ProfilesCompanion.insert(
        title: Value(title),
        emoji: Value(emoji),
        blockingMode: Value(blockingMode),
        dayFlags: Value(dayFlags),
        typeCombinations: Value(typeCombinations),
        colorHex: Value(colorHex),
        presetId: Value(presetId),
      ),
    );
    await _channel.notifyProfileChanged(id);
    return id;
  }

  Future<void> toggleProfile(int id, bool enabled) async {
    final profile = await _db.getProfileById(id);
    if (profile == null) return;
    await _db.updateProfile(
      profile.toCompanion(true).copyWith(isEnabled: Value(enabled)),
    );
    await _channel.notifyProfileToggled(profileId: id, enabled: enabled);
  }

  Future<void> deleteProfile(int id) async {
    await _db.deleteProfile(id);
    await _channel.notifyProfileChanged(id);
  }

  Future<void> updateProfileDetails({
    required int id,
    String? title,
    String? emoji,
    int? blockingMode,
    int? dayFlags,
    int? typeCombinations,
    bool? blockNotifications,
    bool? blockAdultContent,
    String? colorHex,
  }) async {
    final profile = await _db.getProfileById(id);
    if (profile == null) return;
    // NB: updateProfile usa `.replace()`, che riscrive l'intera riga e resetta
    // ai default le colonne ASSENTI dal companion. Partiamo dallo snapshot
    // completo (`toCompanion(true)`) e per i campi non passati passiamo `null`
    // a copyWith — che significa "lascia il valore esistente". Usare
    // `Value.absent()` qui cancellerebbe i campi non passati (es. l'emoji
    // tornerebbe al default 'NoIcon' modificando solo il titolo).
    await _db.updateProfile(
      profile
          .toCompanion(true)
          .copyWith(
            title: title != null ? Value(title) : null,
            emoji: emoji != null ? Value(emoji) : null,
            blockingMode: blockingMode != null ? Value(blockingMode) : null,
            dayFlags: dayFlags != null ? Value(dayFlags) : null,
            typeCombinations: typeCombinations != null
                ? Value(typeCombinations)
                : null,
            blockNotifications: blockNotifications != null
                ? Value(blockNotifications)
                : null,
            blockAdultContent: blockAdultContent != null
                ? Value(blockAdultContent)
                : null,
            colorHex: colorHex != null ? Value(colorHex) : null,
          ),
    );
    await _channel.notifyProfileChanged(id);
  }

  Future<void> setAppsForProfile(
    int profileId,
    List<String> packageNames,
  ) async {
    // Detect pkg aggiunti ora (non avevano relation prima): per quelli con
    // sezioni in-app supportate (Instagram → Reels/Stories/Explore,
    // YouTube → Shorts) auto-popoliamo blockedSectionsJson. Non tocchiamo
    // relations preesistenti né sezioni già configurate dall'utente.
    final existingBefore = await _db.getAppsForProfile(profileId);
    final existingPkgs = existingBefore.map((r) => r.packageName).toSet();
    final newlyAdded = packageNames.toSet().difference(existingPkgs);

    await _db.setAppsForProfile(profileId, packageNames);

    for (final pkg in newlyAdded) {
      final sections = BlockedSection.forPackage(pkg);
      if (sections.isEmpty) continue;
      await _db.setDefaultBlockedSectionsIfEmpty(
        profileId: profileId,
        packageName: pkg,
        json: BlockedSection.encodeSet(sections.toSet()),
      );
    }

    await _channel.notifyProfileChanged(profileId);
  }

  Future<List<String>> getWifisForProfile(int profileId) async {
    final rows = await _db.getWifisForProfile(profileId);
    return rows.map((w) => w.ssid).toList(growable: false);
  }

  Future<void> setWifisForProfile(int profileId, List<String> ssids) async {
    await _db.setWifisForProfile(profileId, ssids);
    await _channel.notifyProfileChanged(profileId);
  }

  Future<void> setIntervalsForProfile(
    int profileId,
    List<({int from, int to})> timeRanges,
  ) async {
    // transaction(): delete + N insert collassano in UNA sola notifica di
    // `watchAllProfiles` al commit (invece di N+1 ri-emissioni, ognuna delle
    // quali ricostruisce tutti i ProfileModel con un loop N+1) + atomicità:
    // nessuno stato intermedio a 0 fasce osservabile dall'enforcement.
    // Allineato a setAppsForProfile/setWifisForProfile (transazionali a livello DAO).
    await _db.transaction(() async {
      await (_db.delete(
        _db.intervals,
      )..where((i) => i.profileId.equals(profileId))).go();
      for (final range in timeRanges) {
        await _db
            .into(_db.intervals)
            .insert(
              IntervalsCompanion.insert(
                profileId: profileId,
                fromMinutes: range.from,
                toMinutes: range.to,
              ),
            );
      }
    });
    await _channel.notifyProfileChanged(profileId);
  }

  Future<void> addWebsiteRule({
    required int profileId,
    required String name,
    int blockingType = 0,
    bool isAnywhereInUrl = false,
  }) async {
    await _db
        .into(_db.websiteRules)
        .insert(
          WebsiteRulesCompanion.insert(
            profileId: profileId,
            name: name,
            blockingType: Value(blockingType),
            isAnywhereInUrl: Value(isAnywhereInUrl),
          ),
        );
    await _channel.notifyProfileChanged(profileId);
  }

  Future<void> deleteWebsiteRule(int ruleId, int profileId) async {
    await (_db.delete(
      _db.websiteRules,
    )..where((r) => r.id.equals(ruleId))).go();
    await _channel.notifyProfileChanged(profileId);
  }
}
