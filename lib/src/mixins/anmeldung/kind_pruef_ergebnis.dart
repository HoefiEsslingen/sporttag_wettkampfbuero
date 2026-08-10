/// Ergebnis der kombinierten Namens- und Duplikat-Prüfung eines Kindes
/// vor dem Speichern (siehe DuplikatPruefungMixin.pruefeKindVorSpeichern).
enum KindPruefErgebnis {
  /// Namen und Duplikat-Prüfung sind in Ordnung, Kind kann gespeichert werden.
  gueltig,

  /// Vorname und/oder Nachname sind ungültig (leer, zu kurz, unerlaubte Zeichen).
  /// Ein Fehlerdialog wurde bereits angezeigt.
  namensfehler,

  /// Es wurde ein Duplikat gefunden und der Nutzer hat die Rückfrage
  /// abgelehnt (Eingabe soll korrigiert statt zusätzlich gespeichert werden).
  duplikatAbgelehnt,
}

extension KindPruefErgebnisX on KindPruefErgebnis {
  bool get istGueltig => this == KindPruefErgebnis.gueltig;
}