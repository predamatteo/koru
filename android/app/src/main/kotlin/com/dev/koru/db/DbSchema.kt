package com.dev.koru.db

/**
 * ARCH-04 — Contratto di schema cross-runtime (lato Kotlin).
 *
 * Koru ha DUE runtime che aprono LO STESSO file SQLite (`koru.db`):
 *  - Drift (Dart) è il PROPRIETARIO dello schema + delle migrazioni
 *    (`app_database.dart` + i file in `lib/data/database/tables/`).
 *  - Il lato nativo ([NativeDatabase]) legge lo stesso file con SQL grezzo e
 *    nomi di colonna hardcoded. NON c'è alcun legame a compile-time fra i due:
 *    una rename di colonna lato Drift compila benissimo e rompe l'enforcement
 *    nativo SILENZIOSAMENTE a runtime (una rawQuery che fallisce ⇒ risultato
 *    vuoto ⇒ il blocking smette di funzionare).
 *
 * Questo oggetto dichiara UNA VOLTA SOLA ogni nome di tabella e di colonna che
 * [NativeDatabase] referenzia, raggruppati per tabella. Tutte le query in
 * [NativeDatabase] usano queste costanti invece di literal inline, così la
 * conoscenza nativa dello schema è dichiarata in un solo punto, greppabile e
 * aggiornabile senza dover scorrere ogni stringa SQL.
 *
 * COSA GARANTISCE il contratto (e cosa NO):
 *  - [DbSchemaContractTest] (Kotlin) costruisce un DB SQLite con ESATTAMENTE le
 *    colonne qui dichiarate ed esegue ogni read query di [NativeDatabase]: se
 *    una query referenzia una colonna/tabella NON presente qui (typo, drift
 *    interno) il test fallisce con "no such column/table". → cattura il drift
 *    INTERNO al nativo a test-time invece che a runtime.
 *  - Il test Dart `db_schema_contract_test.dart` mantiene una mappa gemella di
 *    questo oggetto e verifica che lo schema VIVO di Drift contenga ogni
 *    (tabella → colonne) di cui il nativo dipende: se Drift rinomina/elimina
 *    una colonna usata dal nativo, quel test fallisce. → cattura il drift
 *    CROSS-RUNTIME (Drift che diverge dal nativo).
 *  - NON è un codegen: questo oggetto e la mappa Dart sono mantenuti a mano e
 *    DEVONO restare in sync — SONO il contratto cross-runtime. I due test
 *    falliscono se il contratto è violato da un lato, ma non possono inventare
 *    la corrispondenza da soli. Un rename coordinato richiede di aggiornare
 *    ENTRAMBE le liste (qui + Dart) oltre allo schema Drift.
 *
 * Vedi anche [NativeDatabase] per gli invarianti di runtime (journal_mode,
 * busy_timeout, "Drift owns schema") che completano questo contratto.
 */
object DbSchema {

    /** Nome del file DB condiviso (Drift lo crea, il nativo lo riapre). */
    const val DB_NAME = "koru.db"

    object Profiles {
        const val TABLE = "profiles"
        const val ID = "id"
        const val TITLE = "title"
        const val TYPE_COMBINATIONS = "type_combinations"
        const val ON_CONDITIONS = "on_conditions"
        const val OPERATOR = "operator"
        const val DAY_FLAGS = "day_flags"
        const val BLOCK_NOTIFICATIONS = "block_notifications"
        const val BLOCK_LAUNCH = "block_launch"
        const val IS_ENABLED = "is_enabled"
        const val IS_LOCKED = "is_locked"
        const val ON_UNTIL = "on_until"
        const val LOCKED_UNTIL = "locked_until"
        const val PAUSED_UNTIL = "paused_until"
        const val BLOCKING_MODE = "blocking_mode"
        const val BLOCK_UNSUPPORTED_BROWSERS = "block_unsupported_browsers"
        const val BLOCK_ADULT_CONTENT = "block_adult_content"
        const val COLOR_HEX = "color_hex"
        const val EMOJI = "emoji"
    }

    object AppProfileRelations {
        const val TABLE = "app_profile_relations"
        const val PACKAGE_NAME = "package_name"
        const val PROFILE_ID = "profile_id"
        const val IS_ENABLED = "is_enabled"
        const val OVERLAY_CONFIG_JSON = "overlay_config_json"
        const val BLOCKED_SECTIONS_JSON = "blocked_sections_json"
    }

    object Intervals {
        const val TABLE = "intervals"
        const val ID = "id"
        const val PROFILE_ID = "profile_id"
        const val FROM_MINUTES = "from_minutes"
        const val TO_MINUTES = "to_minutes"
        const val IS_ENABLED = "is_enabled"
    }

    object UsageLimits {
        const val TABLE = "usage_limits"
        const val ID = "id"
        const val PROFILE_ID = "profile_id"
        const val PERIOD_TYPE = "period_type"
        const val LIMIT_TYPE = "limit_type"
        const val LAST_RESET_TIME = "last_reset_time"
        const val ALLOWED_COUNT = "allowed_count"
        const val USED_COUNT = "used_count"
    }

    object WebsiteRules {
        const val TABLE = "website_rules"
        const val ID = "id"
        const val PROFILE_ID = "profile_id"
        const val NAME = "name"
        const val BLOCKING_TYPE = "blocking_type"
        const val IS_ANYWHERE_IN_URL = "is_anywhere_in_url"
        const val IS_ENABLED = "is_enabled"
    }

    object WifiNetworks {
        const val TABLE = "wifi_networks"
        const val PROFILE_ID = "profile_id"
        const val SSID = "ssid"
    }

    object AdultContentSites {
        const val TABLE = "adult_content_sites"
        const val DOMAIN = "domain"
    }

    object BlockSessions {
        const val TABLE = "block_sessions"
        const val NAME = "name"
        const val TIMESTAMP = "timestamp"
    }

    object RestrictedAccessEvents {
        const val TABLE = "restricted_access_events"
        const val OCCURRED_AT = "occurred_at"
        const val DAY_START_DATE = "day_start_date"
        const val PACKAGE_NAME = "package_name"
        const val EVENT_TYPE = "event_type"
        const val RESTRICTION_TYPE = "restriction_type"
    }

    object IntentionUsageEvents {
        const val TABLE = "intention_usage_events"
        const val OCCURRED_AT = "occurred_at"
        const val DAY_START_DATE = "day_start_date"
        const val PACKAGE_NAME = "package_name"
        const val INTENTION_NAME = "intention_name"
    }

    object FocusUsageEvents {
        const val TABLE = "focus_usage_events"
        const val OCCURRED_AT = "occurred_at"
        const val DAY_START_DATE = "day_start_date"
        const val DURATION_IN_MS = "duration_in_ms"
    }
}
