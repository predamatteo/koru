// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'Koru';

  @override
  String get appTagline =>
      'Un launcher minimalista e un blocker mindful per riprendersi l\'attenzione.';

  @override
  String get onboardingWelcomeTitle => 'Benvenuto in Koru';

  @override
  String get onboardingWelcomeSubtitle =>
      'Koru è un simbolo di crescita interiore. Riprenditi il controllo della tua attenzione, un respiro alla volta.';

  @override
  String get tabHome => 'Home';

  @override
  String get tabProfiles => 'Profili';

  @override
  String get tabStats => 'Statistiche';

  @override
  String get tabSettings => 'Impostazioni';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonConfirm => 'Conferma';

  @override
  String get commonContinue => 'Continua';

  @override
  String get commonBack => 'Indietro';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonEdit => 'Modifica';

  @override
  String get commonOk => 'OK';

  @override
  String get commonEnable => 'Attiva';

  @override
  String get commonDisable => 'Disattiva';

  @override
  String get commonAdd => 'Aggiungi';

  @override
  String get commonRemove => 'Rimuovi';

  @override
  String get commonDone => 'Fatto';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonSearch => 'Cerca';

  @override
  String get commonAll => 'Tutte';

  @override
  String get commonNone => 'Nessuna';

  @override
  String get commonOpen => 'Apri';

  @override
  String get commonReset => 'Reimposta';

  @override
  String get commonSearchApps => 'Cerca app';

  @override
  String get languageTitle => 'Lingua';

  @override
  String get languageSystemDefault => 'Predefinita di sistema';

  @override
  String get languageNativeNote =>
      'Vale anche per l\'overlay di blocco, le notifiche e il widget in home. Da Android 13 in poi la scelta si rispecchia in Impostazioni Android › App › Koru › Lingua.';

  @override
  String get settingsSectionAppearance => 'Aspetto';

  @override
  String get settingsSectionLauncher => 'Launcher';

  @override
  String get settingsSectionDiscipline => 'Disciplina';

  @override
  String get settingsSectionPermissions => 'Permessi';

  @override
  String get settingsSectionAbout => 'Informazioni';

  @override
  String get settingsSectionEmergency => 'Emergenza';

  @override
  String get settingsSetAsDefault => 'Imposta come predefinito';

  @override
  String get settingsAppPersonalization => 'Personalizzazione app';

  @override
  String get permissionsTitle => 'Permessi';

  @override
  String get aboutTitle => 'Informazioni su Koru';

  @override
  String get backdoorTitle => 'Sblocco d\'emergenza';

  @override
  String get appLimitsTitle => 'Limiti giornalieri app';

  @override
  String get notificationFilterTitle => 'Filtro notifiche';

  @override
  String get unlockChallengeTitle => 'Sfida di sblocco';

  @override
  String get strictModeTitle => 'Modalità rigida';

  @override
  String get strictModeStatusOn => 'Modalità rigida ATTIVA';

  @override
  String get strictModeStatusOff => 'Modalità rigida SPENTA';

  @override
  String get strictModeDescriptionOn =>
      'Impostazioni, Recenti e Disinstallazione sono bloccate. Per allentare o spegnere serve ricostruire una sequenza di simboli — il codice d\'emergenza resta solo per le emergenze.';

  @override
  String get strictModeDescriptionOff =>
      'Attiva per bloccare Impostazioni, Recenti e Disinstallazione. Richiede l\'amministratore dispositivo.';

  @override
  String get strictModeWhatToLock => 'Cosa bloccare';

  @override
  String get strictModeBlockSettings => 'Blocca Impostazioni';

  @override
  String get strictModeBlockSettingsSubtitle =>
      'Impedisce di aprire le Impostazioni di Android.';

  @override
  String get strictModeBlockRecents => 'Blocca App recenti';

  @override
  String get strictModeBlockRecentsSubtitle =>
      'Impedisce di aprire la vista App recenti.';

  @override
  String get strictModeBlockUninstall => 'Blocca disinstallazione';

  @override
  String get strictModeBlockUninstallSubtitle =>
      'Impedisce di disinstallare Koru.';

  @override
  String get strictModeDeviceAdmin => 'Amministratore dispositivo';

  @override
  String get strictModeDeviceAdminActive => 'Amministratore dispositivo attivo';

  @override
  String get strictModeDeviceAdminRequired =>
      'Serve l\'amministratore dispositivo';

  @override
  String get strictModeDeviceAdminActiveSubtitle =>
      'Koru ha i permessi che le servono.';

  @override
  String get strictModeDeviceAdminRequiredSubtitle =>
      'A Koru serve l\'amministratore dispositivo per applicare la modalità rigida.';

  @override
  String get strictModeVerificationExpired => 'La verifica è scaduta. Riprova.';

  @override
  String get strictModeApplyFailed =>
      'Non è stato possibile applicare la modifica.';

  @override
  String get strictModeActionRemoveRestriction => 'togliere questa restrizione';

  @override
  String get strictModeActionTurnOff => 'spegnere la modalità rigida';

  @override
  String get strictModeActiveDialogTitle => 'Modalità rigida attiva';

  @override
  String get strictModeActiveDialogBody =>
      'Per disabilitare l\'amministratore dispositivo devi prima spegnere la modalità rigida dall\'interruttore qui sopra.';

  @override
  String get aboutKoruBody =>
      'Il koru è la fronda che si apre di una felce argentata, simbolo sacro maori di vita nuova e crescita interiore. Ci ricorda che la concentrazione non è una costrizione — è un tornare a sé stessi.';

  @override
  String get aboutPrivacyTitle => 'Privacy';

  @override
  String get aboutPrivacyBody =>
      'Tutto quello che fa Koru succede sul tuo dispositivo. Niente account, niente pubblicità, niente tracciamento. Mai.';

  @override
  String unlockChallengeActiveFriction(String level) {
    return 'Attrito attivo: $level';
  }

  @override
  String get unlockChallengeExplainer =>
      'Spegnere un profilo, cancellarlo o togliergli app richiede prima di memorizzare una breve sequenza di simboli e di ricostruirla in una griglia piena di sosia.\n\nServe a mettere qualche secondo di lucidità fra l\'impulso e il tap. Attivare una protezione resta sempre immediato.\n\nSi sceglie quanto attrito, non se averlo: una sfida che si spegne con un tap è proprio il tap che vorresti fermare.';

  @override
  String get unlockChallengeHowMuchFriction => 'Quanto attrito';

  @override
  String get unlockChallengeLevelGentle => 'Leggera';

  @override
  String get unlockChallengeLevelStandard => 'Media';

  @override
  String get unlockChallengeLevelStubborn => 'Testarda';

  @override
  String get unlockChallengeLevelGentleDesc =>
      '3 simboli, 5 secondi per memorizzarli.';

  @override
  String get unlockChallengeLevelStandardDesc =>
      '4 simboli, 4 secondi, più distrattori.';

  @override
  String get unlockChallengeLevelStubbornDesc =>
      '5 simboli, 3 secondi, griglia piena di sosia.';

  @override
  String get unlockChallengeTryNow => 'Provala adesso';

  @override
  String get unlockChallengeTryNowNote =>
      'Una prova a vuoto: non disattiva niente.';

  @override
  String get unlockChallengeActionPreview => 'provare la sfida';

  @override
  String get unlockChallengePreviewPassed =>
      'Superata. È esattamente questo che ti verrà chiesto.';

  @override
  String get unlockChallengePreviewCancelled => 'Prova annullata.';

  @override
  String get permissionsIntro =>
      'Koru gira solo sul tuo dispositivo. Non esce mai niente.';

  @override
  String get permRequiredBadge => 'Necessario';

  @override
  String get permGrant => 'Concedi';

  @override
  String get permAccessibility => 'Accessibilità';

  @override
  String get permAccessibilitySubtitle =>
      'Accorgersi quando apri un\'app che distrae.';

  @override
  String get permUsageAccess => 'Accesso all\'utilizzo';

  @override
  String get permUsageAccessSubtitle => 'Leggere il tempo speso per app.';

  @override
  String get permOverlay => 'Mostra sopra le altre app';

  @override
  String get permOverlaySubtitle => 'Mostrare l\'overlay di blocco.';

  @override
  String get permBattery => 'Ottimizzazione batteria';

  @override
  String get permBatterySubtitle =>
      'Tenere vivo il motore di blocco in background.';

  @override
  String get permNotifications => 'Notifiche';

  @override
  String get permNotificationsSubtitle =>
      'Farti avvisare da Koru quando il blocco ha bisogno di attenzione.';

  @override
  String get permNotificationListener => 'Lettore di notifiche';

  @override
  String get permNotificationListenerSubtitle =>
      'Filtrare le notifiche delle app bloccate (Fase 2).';

  @override
  String get appLimitsIntro =>
      'In ordine di quanto le hai usate oggi. Tocca un\'app per impostare un tetto giornaliero in minuti.';

  @override
  String get appLimitsNotUsedToday => 'Non usata oggi';

  @override
  String appLimitsMinutesToday(int minutes) {
    return '$minutes min oggi';
  }

  @override
  String appLimitsHoursToday(int hours) {
    return '${hours}h oggi';
  }

  @override
  String appLimitsHoursMinutesToday(int hours, int minutes) {
    return '${hours}h ${minutes}m oggi';
  }

  @override
  String appLimitsUsedOfCap(int used, int cap) {
    return '$used / $cap min oggi';
  }

  @override
  String appLimitsBadgeMinutes(int minutes) {
    return '$minutes m';
  }

  @override
  String appLimitsPresetMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get appLimitsDailyCap => 'Tetto giornaliero';

  @override
  String get appLimitsMinPerDay => 'min / giorno';

  @override
  String get appLimitsStrictTitle => 'Limite giornaliero rigido';

  @override
  String get appLimitsStrictOn =>
      'Tetto invalicabile. Niente \"Apri lo stesso\" una volta raggiunto.';

  @override
  String get appLimitsStrictOff =>
      'Bypass consentito, ma sempre più difficile durante la giornata.';

  @override
  String get appLimitsChallengeLockTitle => 'Blocco con sfida';

  @override
  String get appLimitsChallengeLockOn =>
      'Serve la sfida a memoria per allentare il limite, e anche per aprire l\'app a tetto raggiunto.';

  @override
  String get appLimitsChallengeLockOff =>
      'Nessuna sfida: il limite si cambia in un tap.';

  @override
  String appLimitsActionLoosen(String app) {
    return 'allentare il limite di $app';
  }

  @override
  String get notificationFilterIntro =>
      'Le notifiche delle app che silenzi vengono scartate prima di arrivare nella barra di stato.';

  @override
  String get notificationFilterAccessRequired =>
      'Serve l\'accesso alle notifiche';

  @override
  String get notificationFilterAccessRequiredSubtitle =>
      'Attiva Koru in Accesso alle notifiche perché il silenziamento funzioni.';

  @override
  String get backdoorCurrentWeeklyCode => 'Il tuo codice settimanale';

  @override
  String get backdoorCodeExplainer =>
      'Copia il codice in un posto sicuro. Ruota ogni settimana, è generato in modo casuale sul tuo dispositivo, funziona offline, e ogni codice è monouso: appena lo usi per sbloccare la modalità rigida viene sostituito da uno nuovo.';

  @override
  String get backdoorCodeUnavailable =>
      'Codice temporaneamente non disponibile';

  @override
  String get backdoorCodeUnavailableBody =>
      'Lo spazio sicuro del dispositivo (Keystore) non è raggiungibile in questo momento, quindi non possiamo generare il codice settimanale. Riprova tra poco o riavvia il dispositivo.';

  @override
  String get backdoorUnblockSection => 'Sblocco d\'emergenza';

  @override
  String get backdoorEnterCode => 'Inserisci il codice';

  @override
  String get backdoorUnlockButton => 'Sblocca';

  @override
  String backdoorAttemptsLeft(int count) {
    return '$count tentativi rimanenti prima del blocco';
  }

  @override
  String get backdoorResultValid =>
      'Codice valido — modalità rigida disattivata. Il codice è stato consumato; ne sarà generato uno nuovo.';

  @override
  String get backdoorResultInvalid => 'Codice non valido.';

  @override
  String get backdoorResultReplay =>
      'Codice già usato. Aspetta la rotazione settimanale per riceverne uno nuovo.';

  @override
  String backdoorLockoutMinutes(int minutes) {
    return 'Blocco: $minutes minuti rimanenti.';
  }

  @override
  String backdoorLockoutHours(int hours) {
    return 'Blocco: $hours ore rimanenti.';
  }

  @override
  String backdoorLockoutDays(int days) {
    return 'Blocco: $days giorni rimanenti.';
  }

  @override
  String backdoorError(String message) {
    return 'Errore: $message';
  }

  @override
  String get launcherIsDefault => 'Koru è il tuo launcher predefinito';

  @override
  String get launcherIsNotDefault => 'Koru non è il tuo launcher predefinito';

  @override
  String get launcherMakeSelectable => 'Rendi Koru selezionabile come launcher';

  @override
  String get launcherMakeSelectableSubtitle =>
      'Abilita l\'attività HOME. Devi comunque scegliere Koru nel selettore di sistema.';

  @override
  String get launcherOpenSystemPicker =>
      'Apri il selettore launcher di sistema';

  @override
  String get launcherSwipeGestures => 'Gesti di swipe';

  @override
  String get launcherSwipeGesturesSubtitle =>
      'Lo swipe verso l\'alto apre sempre Tutte le app. Assegna un\'azione agli swipe verso sinistra e destra sulla home. Le app che distraggono (bloccate o limitate) non sono selezionabili.';

  @override
  String get launcherSwipeLeft => 'Swipe a sinistra';

  @override
  String get launcherSwipeRight => 'Swipe a destra';

  @override
  String get launcherSwipeAppSearch => 'Cerca app';

  @override
  String get launcherSwipeGenericApp => 'App';

  @override
  String get fontTitle => 'Carattere';

  @override
  String get fontPreviewPangram =>
      'Quel vituperabile xenofobo zelante assaggia il whisky ed esclama: alleluja!';

  @override
  String get personalizationIntro =>
      'Tieni premuto su un\'app per rinominarla. Tocca l\'occhio per nasconderla dal drawer del launcher (l\'app resta installata).';

  @override
  String get personalizationCustomName => 'Nome personalizzato';

  @override
  String get personalizationCustomNameHint => 'Lascia vuoto per reimpostare';

  @override
  String get personalizationResetAll => 'Reimposta tutto';

  @override
  String get personalizationResetDialogTitle =>
      'Reimpostare la personalizzazione?';

  @override
  String get personalizationResetDialogBody =>
      'Tutti i nomi personalizzati verranno rimossi e tutte le app nascoste torneranno visibili.';

  @override
  String personalizationWasNamed(String label) {
    return 'era: $label';
  }

  @override
  String get allAppsTitle => 'Tutte le app';

  @override
  String get dayMon => 'Lun';

  @override
  String get dayTue => 'Mar';

  @override
  String get dayWed => 'Mer';

  @override
  String get dayThu => 'Gio';

  @override
  String get dayFri => 'Ven';

  @override
  String get daySat => 'Sab';

  @override
  String get daySun => 'Dom';

  @override
  String get dayEveryDay => 'Ogni giorno';

  @override
  String get dayWeekdays => 'Giorni feriali';

  @override
  String get dayWeekend => 'Weekend';

  @override
  String get profileUntitled => 'Senza nome';

  @override
  String get profileModeAllowlist => 'Lista consentiti';

  @override
  String get profileModeBlocklist => 'Lista bloccati';

  @override
  String profileAppsCount(int count) {
    return '$count app';
  }

  @override
  String profileSitesCount(int count) {
    return '$count siti';
  }

  @override
  String get profilesNew => 'Nuovo';

  @override
  String get profilesAllDay => 'Tutto il giorno';

  @override
  String profilesAppsBlocked(int count) {
    return '$count app bloccate';
  }

  @override
  String profilesActionTurnOff(String title) {
    return 'spegnere «$title»';
  }

  @override
  String get profilesEmptyTitle => 'Ancora nessun profilo';

  @override
  String get profilesEmptyBody =>
      'Tocca + per creare il tuo primo profilo e scegliere quando e quali app bloccare.';

  @override
  String get profileEditorNewTitle => 'Nuovo profilo';

  @override
  String get profileEditorEditTitle => 'Modifica profilo';

  @override
  String get profileEditorNameHint => 'Nome del profilo';

  @override
  String get profileEditorNameFirst => 'Dai prima un nome al profilo';

  @override
  String get profileEditorPickIcon => 'Scegli un\'icona';

  @override
  String get profileEditorActionDeleteGeneric => 'cancellare il profilo';

  @override
  String profileEditorActionDeleteNamed(String title) {
    return 'cancellare «$title»';
  }

  @override
  String get profileEditorSectionSchedule => 'Orari';

  @override
  String get profileEditorStart => 'Inizio';

  @override
  String get profileEditorEnd => 'Fine';

  @override
  String get profileEditorRemoveTimeSlot => 'Rimuovi fascia oraria';

  @override
  String get profileEditorAddTimeSlot => 'Aggiungi fascia oraria';

  @override
  String get profileEditorAllDayTitle => 'Tutto il giorno';

  @override
  String get profileEditorAllDaySubtitle =>
      'Attivo 24 ore su 24, 00:00 → 00:00';

  @override
  String get profileEditorSectionBlockedApps => 'App bloccate';

  @override
  String get profileEditorAppsSelected => 'App selezionate';

  @override
  String get profileEditorConfigure => 'Configura';

  @override
  String get profileEditorSaveFirst =>
      'Salva prima il profilo per scegliere le app.';

  @override
  String get profileEditorSectionInAppContent => 'Contenuti nelle app';

  @override
  String get profileEditorSectionWebsites => 'Siti web';

  @override
  String get profileEditorBlockedDomains => 'Domini bloccati';

  @override
  String get profileEditorSectionOnlyOnWifi => 'Solo su Wi-Fi';

  @override
  String get profileEditorWifiNoFilter =>
      'Nessun filtro. Il profilo si attiva su qualsiasi rete.';

  @override
  String get profileEditorWifiActiveOnlyOn => 'Profilo attivo solo su:';

  @override
  String get profileEditorAddCurrentWifi => 'Aggiungi corrente';

  @override
  String get profileEditorAddWifiByName => 'Aggiungi per nome';

  @override
  String get profileEditorAddWifiTitle => 'Aggiungi SSID Wi-Fi';

  @override
  String get profileEditorAddWifiHint => 'es. Casa_WiFi';

  @override
  String get profileEditorWifiSsidReadFailed =>
      'Non è stato possibile leggere l\'SSID corrente. Verifica che il Wi-Fi sia acceso e che il permesso di posizione sia concesso.';

  @override
  String get websitesIntro =>
      'Blocca i domini letti dalla barra degli indirizzi del browser. Funziona su Chrome, Firefox, Brave, Samsung e gli altri browser supportati.';

  @override
  String get websitesDomainLabel => 'Dominio';

  @override
  String get websitesDomainHint => 'es. instagram.com';

  @override
  String get websitesMatchAnywhere => 'Cerca ovunque nell\'URL';

  @override
  String get websitesMatchAnywhereOn =>
      'Blocca qualsiasi URL che contiene il testo';

  @override
  String get websitesMatchAnywhereOff => 'Dominio esatto (sottodomini inclusi)';

  @override
  String get websitesEmpty => 'Nessun sito bloccato per ora.';

  @override
  String get websitesRuleAnywhere => 'Ovunque nell\'URL';

  @override
  String get websitesRuleDomain => 'Dominio esatto';

  @override
  String get websitesActionRemove => 'togliere un sito da un profilo acceso';

  @override
  String get blockedAppsSelectApps => 'Scegli le app';

  @override
  String get blockedAppsMostUsedThisWeek => 'Più usate questa settimana';

  @override
  String blockedAppsNoMatch(String query) {
    return 'Nessuna app corrisponde a \"$query\"';
  }

  @override
  String get blockedAppsActionWeaken =>
      'togliere protezione a un profilo acceso';

  @override
  String get sectionInstagramReels => 'Reels';

  @override
  String get sectionInstagramStories => 'Storie';

  @override
  String get sectionInstagramExplore => 'Esplora';

  @override
  String get sectionYoutubeShorts => 'Shorts';

  @override
  String get inAppContentIntro =>
      'Blocca sezioni specifiche dentro un\'app. Se l\'app intera è già nella lista bloccati di questo profilo, le sezioni sono ridondanti e restano disattivate.';

  @override
  String get inAppContentFullyBlocked => 'Bloccata del tutto';

  @override
  String get inAppContentAppFullyBlocked => 'App bloccata del tutto';

  @override
  String get inAppContentSectionDisabled =>
      'Blocco per sezione disattivato: in questo profilo l\'app è bloccata del tutto.';

  @override
  String overlayDesignerTitle(String app) {
    return 'Overlay · $app';
  }

  @override
  String get overlayDesignerBackground => 'Sfondo';

  @override
  String get overlayDesignerMessage => 'Messaggio';

  @override
  String get overlayDesignerTitleField => 'Titolo (facoltativo)';

  @override
  String get overlayDesignerSubtitleField => 'Sottotitolo (facoltativo)';

  @override
  String get overlayDesignerCountdown => 'Conto alla rovescia';

  @override
  String overlayDesignerSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get overlayDesignerAllowOpen =>
      'Consenti l\'apertura dopo il conto alla rovescia';

  @override
  String get overlayDesignerAllowOpenSubtitle =>
      'Mostra il pulsante \"Apri lo stesso\" alla fine del conto alla rovescia.';

  @override
  String get commonViewAll => 'Vedi tutti';

  @override
  String get achievementsTitle => 'Obiettivi';

  @override
  String achievementsUnlockedOf(int total) {
    return '/ $total sbloccati';
  }

  @override
  String get achievementCategoryDiscipline => 'Disciplina';

  @override
  String get achievementCategorySetup => 'Configurazione';

  @override
  String get achievementCleanWeekTitle => 'Settimana pulita';

  @override
  String get achievementCleanWeekDesc =>
      'Sette giorni senza superare nessun limite giornaliero.';

  @override
  String get achievementIntentions50Title => 'Scelta consapevole';

  @override
  String get achievementIntentions50Desc =>
      'Dichiara un\'intenzione 50 volte sull\'overlay di blocco.';

  @override
  String get achievementHonestBlock100Title => 'Blocco onesto';

  @override
  String get achievementHonestBlock100Desc =>
      'Rispetta un blocco (senza bypass) 100 volte.';

  @override
  String get achievementFirstProfileTitle => 'Primo profilo';

  @override
  String get achievementFirstProfileDesc =>
      'Crea il tuo primo profilo di blocco.';

  @override
  String get achievementCuratedTitle => 'Su misura';

  @override
  String get achievementCuratedDesc =>
      'Imposta limiti giornalieri su 3 o più app.';

  @override
  String get achievementLockdownTitle => 'Serrata';

  @override
  String get achievementLockdownDesc =>
      'Attiva la modalità rigida almeno una volta.';

  @override
  String get achievementCustomizedTitle => 'Personalizzato';

  @override
  String get achievementCustomizedDesc =>
      'Personalizza l\'overlay di almeno un\'app.';

  @override
  String get achievementUnlockedToast => 'Obiettivo sbloccato';

  @override
  String get commonLoading => 'Caricamento…';

  @override
  String get monthJan => 'Gen';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'Mag';

  @override
  String get monthJun => 'Giu';

  @override
  String get monthJul => 'Lug';

  @override
  String get monthAug => 'Ago';

  @override
  String get monthSep => 'Set';

  @override
  String get monthOct => 'Ott';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dic';

  @override
  String get statsPeriodToday => 'Oggi';

  @override
  String get statsPeriodWeek => 'Questa settimana';

  @override
  String get statsYesterday => 'Ieri';

  @override
  String get statsPreviousDay => 'Giorno precedente';

  @override
  String get statsNextDay => 'Giorno successivo';

  @override
  String get statsWholeWeek => 'Tutta la settimana';

  @override
  String get statsScreenTime => 'Tempo di utilizzo';

  @override
  String get statsDailyBreakdown => 'Dettaglio per giorno';

  @override
  String get statsTopApps => 'App più usate';

  @override
  String get statsInterventions => 'Interventi';

  @override
  String get statsTapADay => 'Tocca un giorno per vederne le app';

  @override
  String get statsNoUsageRecorded => 'Nessun utilizzo registrato';

  @override
  String get statsNoUsageThisDay =>
      'Nessun utilizzo registrato per questo giorno.';

  @override
  String get statsNoUsageThisPeriod =>
      'Nessun utilizzo in primo piano registrato in questo periodo.';

  @override
  String get statsNoBlocksYet => 'Ancora nessun blocco';

  @override
  String statsPercentRespected(int percent) {
    return '$percent% rispettati';
  }

  @override
  String statsPercentSkipped(int percent) {
    return '$percent% saltati';
  }

  @override
  String get statsRefYesterday => 'ieri';

  @override
  String get statsRefDayBefore => 'il giorno prima';

  @override
  String get statsRefLastWeek => 'la settimana scorsa';

  @override
  String statsNoDataFrom(String period) {
    return 'nessun dato da $period';
  }

  @override
  String statsDeltaFrom(String delta, String period) {
    return '$delta% rispetto a $period';
  }

  @override
  String get homeGreetingNight => 'Ancora sveglio?';

  @override
  String get homeGreetingMorning => 'Buongiorno.';

  @override
  String get homeGreetingAfternoon => 'Buon pomeriggio.';

  @override
  String get homeGreetingEvening => 'Buonasera.';

  @override
  String get homeGreetingSubtitle =>
      'Fai un respiro. Su cosa vuoi concentrarti oggi?';

  @override
  String get homeActiveRightNow => 'Attivo adesso';

  @override
  String get homeNoProfileActiveNow => 'Nessun profilo attivo adesso';

  @override
  String get homeCreateOneToStart => 'Creane uno per iniziare';

  @override
  String homeProfilesConfigured(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profili configurati',
      one: '$count profilo configurato',
    );
    return '$_temp0';
  }

  @override
  String get homeBlocksLabel => 'Blocchi';

  @override
  String get todayLimitsHeader => 'Limiti di oggi';

  @override
  String get todayLimitsEmptyTitle => 'Ancora nessun limite giornaliero';

  @override
  String get todayLimitsEmptyBody =>
      'Metti un tetto al tempo che puoi passare in un\'app ogni giorno. Koru interviene quando lo raggiungi.';

  @override
  String get todayLimitsSetOne => 'Imposta un limite';

  @override
  String todayLimitsUsedOfCap(int used, int cap) {
    return '$used / $cap min';
  }

  @override
  String get a11yBannerTitle => 'Il blocco di Koru è SPENTO';

  @override
  String get a11yBannerBody =>
      'Il servizio di accessibilità è stato disattivato dal sistema. Limiti e profili non funzionano finché non lo riattivi.';

  @override
  String get a11yBannerAction => 'Riattiva';

  @override
  String get favoritesFolderOptions => 'Opzioni cartella';

  @override
  String get favoritesRenameFolder => 'Rinomina cartella';

  @override
  String get favoritesDeleteFolder => 'Elimina cartella';

  @override
  String get favoritesDeleteFolderSubtitle => 'Le sue app tornano nella home';

  @override
  String favoritesFolderDeleted(String name) {
    return 'Cartella \"$name\" eliminata';
  }

  @override
  String get favoritesEmptyFolder => 'Cartella vuota';

  @override
  String get favoritesEmptyHint =>
      'Tieni premuto su un\'app nel drawer per aggiungerla qui.';

  @override
  String allAppsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count app',
      one: '$count app',
    );
    return '$_temp0';
  }

  @override
  String get allAppsClearSearch => 'Cancella la ricerca';

  @override
  String get allAppsNoMatch => 'Nessuna app corrispondente';

  @override
  String get appMenuOptions => 'Opzioni app';

  @override
  String get appMenuAddFavorite => 'Aggiungi ai preferiti';

  @override
  String get appMenuRemoveFavorite => 'Togli dai preferiti';

  @override
  String appMenuAddedFavoriteToast(String app) {
    return '$app aggiunta ai preferiti';
  }

  @override
  String appMenuRemovedFavoriteToast(String app) {
    return '$app tolta dai preferiti';
  }

  @override
  String appMenuFavoritesFailed(String error) {
    return 'Aggiornamento dei preferiti fallito: $error';
  }

  @override
  String get appMenuMoveToFolder => 'Sposta in una cartella…';

  @override
  String get appMenuRemoveFromFolder => 'Togli dalla cartella';

  @override
  String appMenuMovedBackHome(String app) {
    return '$app riportata nella home';
  }

  @override
  String get appMenuAppInfo => 'Info app';

  @override
  String get appMenuUninstall => 'Disinstalla';

  @override
  String appMenuUninstallFailed(String app, String error) {
    return 'Impossibile disinstallare $app: $error';
  }

  @override
  String get appMenuStrictDialogTitle => 'Modalità rigida attiva';

  @override
  String get appMenuStrictDialogBody =>
      'La disinstallazione delle app è bloccata finché la modalità rigida protegge la disinstallazione. Disattiva quell\'opzione nelle impostazioni della Modalità rigida per disinstallare le app.';

  @override
  String folderMoveTitle(String app) {
    return 'Sposta \"$app\"';
  }

  @override
  String get folderMoveSubtitle => 'Scegli la cartella di destinazione';

  @override
  String get folderNew => 'Nuova cartella…';

  @override
  String get folderNewTitle => 'Nuova cartella';

  @override
  String get folderNameHint => 'Nome della cartella';

  @override
  String get launcherPhone => 'Telefono';

  @override
  String get launcherCamera => 'Fotocamera';

  @override
  String get launcherKoruDashboard => 'Dashboard Koru';

  @override
  String get launcherOpenAppsReset => 'Contatore app aperte azzerato';

  @override
  String get launcherLeftShortcut => 'Scorciatoia sinistra';

  @override
  String get launcherRightShortcut => 'Scorciatoia destra';

  @override
  String get launcherResetToDefault => 'Ripristina il valore predefinito';

  @override
  String get launcherShortcutReset =>
      'Scorciatoia ripristinata al valore predefinito';

  @override
  String get challengeIntroTitle => 'Un momento';

  @override
  String get challengeIntroSubtitle => 'Prima di indebolire la protezione.';

  @override
  String challengeIntroBody(String action) {
    return 'Per $action devi prima ricostruire una sequenza di simboli.';
  }

  @override
  String get challengeIntroHint =>
      'Te li mostriamo per qualche secondo, poi li ritrovi in una griglia piena di simboli quasi identici.';

  @override
  String get challengeShowSequence => 'Mostrami la sequenza';

  @override
  String get challengeMemorizeTitle => 'Memorizza';

  @override
  String get challengeMemorizeSubtitle =>
      'Questi simboli, in questo ordine. Poi spariscono.';

  @override
  String get challengeRecallTitle => 'Ricostruisci';

  @override
  String get challengeRecallSubtitle =>
      'Toccali nell\'ordine di prima. Attenzione ai sosia.';

  @override
  String get challengeBlockedTitle => 'Non adesso';

  @override
  String get challengeExpiredMidway =>
      'La verifica è scaduta prima che finissi. Puoi ricominciare.';

  @override
  String challengeFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tentativi andati storti. Nessuna fretta.',
      one: 'Un tentativo andato storto. Nessuna fretta.',
    );
    return '$_temp0';
  }

  @override
  String get challengeGiveUp => 'Lascia stare';

  @override
  String challengeCooldown(String time) {
    return 'Troppi tentativi falliti di fila. Riprova fra $time.';
  }

  @override
  String get challengeStartFailed =>
      'Non è stato possibile avviare la verifica. Riprova fra un momento.';

  @override
  String get commonApply => 'Applica';

  @override
  String get onboardingWelcomeTagline =>
      'Un simbolo maori di crescita interiore.';

  @override
  String get onboardingWelcomeBody =>
      'Koru è un launcher minimalista e un blocker mindful. Ti aiuta a riprenderti l\'attenzione — un respiro alla volta.';

  @override
  String get onboardingLauncherTitle => 'Usa Koru come launcher';

  @override
  String get onboardingLauncherBody =>
      'Imposta Koru come schermata home predefinita per l\'esperienza minimalista completa. Puoi sempre cambiare idea più avanti nelle Impostazioni.';

  @override
  String get onboardingLauncherCta => 'Imposta Koru come launcher predefinito';

  @override
  String get onboardingLauncherSkipHint =>
      'Oppure salta — Koru funziona bene in entrambi i casi.';

  @override
  String get onboardingPresetsTitle => 'Avvio rapido';

  @override
  String get onboardingPresetsBody =>
      'Tocca un preset per creare un profilo già pronto. Puoi modificarlo più avanti.';

  @override
  String get onboardingEnterKoru => 'Entra in Koru';

  @override
  String get onboardingSkipForNow => 'Salta per ora';

  @override
  String get overlayTakeABreath => 'Fai un respiro';

  @override
  String get overlayFocusModeActive => 'La modalità focus è attiva';

  @override
  String get overlaySectionBlocked => 'Sezione bloccata';

  @override
  String get overlayWebsiteBlocked => 'Sito bloccato';

  @override
  String overlayPausedBy(String profile) {
    return 'In pausa per “$profile”';
  }

  @override
  String overlayOpenApp(String app) {
    return 'Apri $app';
  }

  @override
  String overlayDontOpenApp(String app) {
    return 'Non aprire $app';
  }

  @override
  String get overlayTapTimerToPause => 'Tocca il timer per metterlo in pausa';

  @override
  String get overlayPaused => 'In pausa';

  @override
  String overlayCountdownSemantics(int seconds) {
    return 'Conto alla rovescia: $seconds secondi rimanenti';
  }

  @override
  String usageLimitActionOpenBeyond(String app) {
    return 'aprire $app oltre il limite di oggi';
  }

  @override
  String get reelsScrolledToday => 'Scrollati oggi';

  @override
  String reelsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'reel',
      one: 'reel',
    );
    return '$_temp0';
  }

  @override
  String get reelsNoneToday => 'Nessuno oggi';

  @override
  String reelsNoneTodayWithAverage(int average) {
    return 'Nessuno oggi — la tua media è $average';
  }

  @override
  String get reelsFirstDays => 'Primi giorni di rilevazione';

  @override
  String reelsOnAverage(int average) {
    return 'Esattamente la tua media giornaliera ($average)';
  }

  @override
  String reelsMoreThanAverage(int delta, int average) {
    return '$delta in più della tua media giornaliera ($average)';
  }

  @override
  String reelsFewerThanAverage(int delta, int average) {
    return '$delta in meno della tua media giornaliera ($average)';
  }
}
