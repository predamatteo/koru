/// App sempre lasciate usabili durante Quick Block e Pomodoro (work phase):
/// chiamate d'emergenza, orologio, fotocamera, SMS, e Koru stesso.
/// L'utente può estendere la whitelist aggiungendo altre app dall'editor.
const Set<String> kDefaultFocusWhitelist = {
  // Koru stesso — servono le route Settings per fermare il timer.
  'com.dev.koru',

  // System UI / launchers principali.
  'com.android.systemui',
  'com.android.launcher',
  'com.android.launcher3',
  'com.google.android.apps.nexuslauncher',
  'com.miui.home',
  'com.sec.android.app.launcher',
  'com.huawei.android.launcher',
  'com.oppo.launcher',
  'com.oneplus.launcher',

  // Telefono / dialer.
  'com.android.dialer',
  'com.google.android.dialer',
  'com.samsung.android.dialer',
  'com.samsung.android.incallui',
  'com.miui.phone',

  // Camera (anche foto durante focus session).
  'com.android.camera',
  'com.android.camera2',
  'com.sec.android.app.camera',
  'com.google.android.GoogleCamera',
  'com.huawei.camera',
  'com.miui.camera',
  'com.oneplus.camera',

  // SMS / messaging base.
  'com.google.android.apps.messaging',
  'com.samsung.android.messaging',
  'com.android.mms',

  // Clock / Alarm — incluse tutte le varianti OEM per evitare che le sveglie
  // restino bloccate. Gli allarmi di sistema suonano comunque (AlarmManager),
  // ma l'utente deve poter aprire l'app per spegnerli o snoozarli.
  'com.google.android.deskclock',
  'com.sec.android.app.clockpackage',
  'com.android.deskclock',
  'com.android.alarmclock',
  'com.oneplus.deskclock',
  'com.oplus.alarmclock',
  'com.coloros.alarmclock',
  'com.huawei.deskclock',
  'com.asus.deskclock',
  'com.sonyericsson.alarm',
  'com.htc.android.worldclock',
  'com.motorola.blur.alarmclock',

  // Emergency / safety.
  'com.android.emergency',
  'com.google.android.safetyhub',
};
