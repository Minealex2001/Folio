/// Stub no-op: telemetría ya no escribe a Firestore (Fase 30).
class FolioFirestoreSync {
  FolioFirestoreSync._();

  static void initialize() {}

  static void addEvent(Object event) {}

  static Future<void> flush() async {}
}
