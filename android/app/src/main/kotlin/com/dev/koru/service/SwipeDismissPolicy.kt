package com.dev.koru.service

// -----------------------------------------------------------------------------
// Decisione pura "questo drag verticale chiude l'overlay di blocco?".
//
// Vive fuori da OverlayView.kt (che è Compose puro) per essere esercitabile da
// un unit test JVM senza far girare una composizione.
// -----------------------------------------------------------------------------

/// Soglie del gesto swipe-up di [BlockedScreen]. Valori in dp / dp al secondo:
/// il chiamante li converte in px con `toPx()`, così restano density-independent.
internal object SwipeDismissDefaults {
    /// Distanza richiesta a un flick VELOCE (oltre [FLING_DP_PER_SEC]).
    const val SHORT_DP = 24f

    /// Distanza richiesta a un trascinamento LENTO. Era l'unica soglia
    /// esistente, e valeva 80dp: quel numero doveva coprire da solo anche i
    /// tap "sporchi" sui pulsanti, quindi era per forza generoso.
    const val LONG_DP = 48f

    /// Sopra questa velocità (verso l'alto) il gesto è considerato un flick
    /// deliberato. ~300dp/s ⇒ 24dp percorsi in meno di ~80ms: nessun tap
    /// accidentale su "Don't open" / countdown / durate ci arriva.
    const val FLING_DP_PER_SEC = 300f
}

/// Due soglie invece di una. Il motivo per cui prima serviva tanto spazio non
/// era il layout, ma il fatto che la distanza fosse l'UNICO discriminante
/// contro i falsi positivi: i controlli interattivi (chip, "Don't open",
/// CountdownButton, bottoni durata) stanno sotto lo stesso pointerInput del
/// Box radice, quindi un tap che scivola verso l'alto è indistinguibile da uno
/// swipe corto. Aggiungendo la velocità come secondo asse possiamo scendere a
/// [SwipeDismissDefaults.SHORT_DP] per il flick e tenere una soglia più
/// permissiva ([SwipeDismissDefaults.LONG_DP]) per il trascinamento lento.
///
/// @param dyTotalPx somma dei delta verticali del drag (negativo = verso l'alto)
/// @param velocityYPxPerSec velocità verticale a fine gesto (negativa = alto)
/// @param shortPx distanza minima quando il gesto supera [flingPxPerSec]
/// @param longPx distanza minima per un gesto lento
internal fun shouldDismissOnSwipeUp(
    dyTotalPx: Float,
    velocityYPxPerSec: Float,
    shortPx: Float,
    longPx: Float,
    flingPxPerSec: Float,
): Boolean {
    // Solo verso l'alto: lo swipe-down resta ignorato (era già così).
    if (dyTotalPx >= 0f) return false
    val isFling = velocityYPxPerSec <= -flingPxPerSec
    val requiredPx = if (isFling) shortPx else longPx
    return dyTotalPx <= -requiredPx
}
