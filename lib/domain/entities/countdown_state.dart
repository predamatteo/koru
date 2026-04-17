/// Fasi del CountdownButtonWidget.
///
/// - [initialized]: creato ma non ancora partito (viene avviato in postFrame)
/// - [animating]: sta riempiendo la barra
/// - [paused]: tap durante animating → ferma, tap di nuovo → resume
/// - [finished]: countdown giunto a 0, mostra finishedText e permette onTap
enum CountdownPhase {
  initialized,
  animating,
  paused,
  finished,
}
