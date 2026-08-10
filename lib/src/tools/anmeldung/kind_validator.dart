import 'package:sporttag/src/klassen/kind_klasse.dart';

/// Ergebnis einer Validierung: null = gültig, sonst Fehlermeldung
typedef ValidationError = String?;

/// Zentrale, UI-unabhängige Validierungslogik für Kind-Daten.
/// Wird sowohl in der Sporttag-Anmeldung als auch in der Vorabanmeldung genutzt.
class KindValidator {
  KindValidator._(); // reine Utility-Klasse, keine Instanzen nötig

  // ── Namens-Validierung ──────────────────────────────────────────
  // Geschlecht und Jahrgang werden über Dropdowns befüllt und sind daher
  // per Konstruktion immer gültig – keine gesonderte Prüfung nötig.

  static ValidationError validiereVorname(String? value) {
    return _validiereName(value, feldName: 'Vorname');
  }

  static ValidationError validiereNachname(String? value) {
    return _validiereName(value, feldName: 'Nachname');
  }

static ValidationError validiereJahrgang(int jahrgang, List<int> zulaessigeJahrgaenge) {
  if (jahrgang == 0 || !zulaessigeJahrgaenge.contains(jahrgang)) {
    return 'Bitte einen gültigen Jahrgang wählen';
  }
  return null;
}

static ValidationError validiereGeschlecht(String geschlecht) {
  if (geschlecht.isEmpty) {
    return 'Bitte ein Geschlecht wählen';
  }
  return null;
}

  static ValidationError _validiereName(String? value, {required String feldName}) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '$feldName darf nicht leer sein';
    }
    if (text.length < 2) {
      return '$feldName ist zu kurz';
    }
    if (text.length > 40) {
      return '$feldName ist zu lang';
    }
    // Erlaubt: Buchstaben (inkl. Umlaute/ß), Leerzeichen, Bindestrich, Apostroph
    final gueltigeZeichen = RegExp(r"^[a-zA-ZäöüÄÖÜß\s\-']+$");
    if (!gueltigeZeichen.hasMatch(text)) {
      return '$feldName enthält ungültige Zeichen';
    }
    return null;
  }

  /// Prüft nur die Namensfelder eines Kindes.
  /// Gibt eine Liste von Fehlermeldungen zurück (leer = alles gültig).
  static List<String> validiereNamen(Kind kind) {
    final fehler = <String>[];

    final vornameFehler = validiereVorname(kind.vorname);
    if (vornameFehler != null) fehler.add(vornameFehler);

    final nachnameFehler = validiereNachname(kind.nachname);
    if (nachnameFehler != null) fehler.add(nachnameFehler);

    return fehler;
  }

  // ── Duplikat-Prüfung ─────────────────────────────────────────────

  /// Ein Duplikat liegt vor, wenn Vorname, Nachname, Geschlecht UND
  /// Jahrgang exakt übereinstimmen (Namen case-insensitive, getrimmt).
  ///
  /// Prüft, ob in [alleKinder] bereits ein solches Kind existiert.
  /// [kind] selbst wird dabei ausgeschlossen.
  ///
  /// Gibt das gefundene Duplikat zurück, oder null falls keins existiert.
  static Kind? findeDuplikat(Kind kind, List<Kind> alleKinder) {
    final vorname = kind.vorname.trim().toLowerCase();
    final nachname = kind.nachname.trim().toLowerCase();

    if (vorname.isEmpty || nachname.isEmpty) {
      return null; // leere Namen werden schon durch Namensvalidierung abgefangen
    }

    for (final anderesKind in alleKinder) {
      if (identical(anderesKind, kind)) continue;
      if (kind.objectId.isNotEmpty && anderesKind.objectId == kind.objectId) {
        continue; // dasselbe, bereits gespeicherte Kind
      }

      final gleicherVorname = anderesKind.vorname.trim().toLowerCase() == vorname;
      final gleicherNachname = anderesKind.nachname.trim().toLowerCase() == nachname;
      final gleichesGeschlecht = anderesKind.geschlecht == kind.geschlecht;
      final gleicherJahrgang = anderesKind.jahrgang == kind.jahrgang;

      if (gleicherVorname && gleicherNachname && gleichesGeschlecht && gleicherJahrgang) {
        return anderesKind;
      }
    }
    return null;
  }
}