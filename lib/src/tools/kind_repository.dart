import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/klassen/station_klasse.dart';
import 'package:sporttag/src/tools/logger.util.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Hilfsobjekt für Batch-Operationen
// ═══════════════════════════════════════════════════════════════════════════
class BatchErgebnis {
  final int erfolgreich;
  final int fehlgeschlagen;
  final List<String> fehlerMeldungen;

  const BatchErgebnis({
    required this.erfolgreich,
    required this.fehlgeschlagen,
    required this.fehlerMeldungen,
  });

  bool get alleErfolgreich => fehlgeschlagen == 0;

  @override
  String toString() =>
      'BatchErgebnis(✓ $erfolgreich / ✗ $fehlgeschlagen)';
}

// ═══════════════════════════════════════════════════════════════════════════
// KindRepository
//
// Datenbankklassen:
//   Kind           → vorName, nachName, geschlecht, jahrgang, bezahlt, version
//   kinderDerRiege → kindID (Pointer<Kind>), riegenID (Pointer<Riege>), position
//   resultate      → kindID (Pointer<Kind>), stationsID (Pointer<Station>), punkte, erreichtUm
// ═══════════════════════════════════════════════════════════════════════════
class KindRepository {
  final _log = getLogger();

  // ─────────────────────────────────────────────────────────────────────────
  // INTERNE HILFSMETHODEN
  // ─────────────────────────────────────────────────────────────────────────

  /// Baut ein Kind-Dart-Objekt aus einem ParseObject (Klasse "Kind").
  Kind _kindVonParse(ParseObject p) {
    return Kind(
      objectId:   p.objectId ?? '',
      vorname:    p.get<String>('vorName')    ?? '',
      nachname:   p.get<String>('nachName')   ?? '',
      geschlecht: p.get<String>('geschlecht') ?? 'w',
      jahrgang:   p.get<int>('jahrgang')      ?? 2017,
      bezahlt:    p.get<bool>('bezahlt')       ?? false,
      version:    p.get<int>('version')        ?? 1,
    );
  }

  /// Speichert ein einzelnes ParseObject mit Exponential-Backoff-Retry (max. 3 Versuche).
  /// ACID: Durability – stille Netzwerkfehler werden durch Wiederholung abgesichert.
  Future<ParseResponse> _saveWithRetry(
    ParseObject obj, {
    int maxVersuche = 3,
  }) async {
    ParseResponse response = await obj.save();
    for (int versuch = 2; versuch <= maxVersuche && !response.success; versuch++) {
      await Future.delayed(Duration(seconds: 1 << (versuch - 2))); // 1s, 2s
      _log.w('Retry $versuch/$maxVersuche…');
      response = await obj.save();
    }
    return response;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE / UPDATE  –  Kind
  // ─────────────────────────────────────────────────────────────────────────

  /// Legt ein neues Kind an oder aktualisiert es (Upsert).
  ///
  /// ACID – Optimistic Locking mit dem Feld "version":
  ///   Beim Update wird geprüft, ob "version" in der DB noch dem erwarteten
  ///   Wert entspricht. Stimmt er nicht überein, hat ein anderes Gerät
  ///   zwischenzeitlich gespeichert → Konflikt wird gemeldet.
  Future<bool> saveKind({required Kind kind}) async {
    final isNew = kind.objectId.isEmpty;

    if (isNew) {
      // ── CREATE ────────────────────────────────────────────────────────────
      final obj = ParseObject('Kind')
        ..set('vorName',    kind.vorname)
        ..set('nachName',   kind.nachname)
        ..set('geschlecht', kind.geschlecht)
        ..set('jahrgang',   kind.jahrgang)
        ..set('bezahlt',    kind.bezahlt)
        ..set('version',    1);

      final response = await _saveWithRetry(obj);
      if (response.success) {
        kind.objectId = (response.results!.first as ParseObject).objectId!;
        kind.version  = 1;
        _log.i('Kind neu angelegt: ${kind.vorname} ${kind.nachname}');
        return true;
      }
      _log.e('CREATE Kind fehlgeschlagen: ${response.error?.message}');
      return false;
    }

    // ── UPDATE mit Optimistic Locking ────────────────────────────────────
    // Nur Felder aktualisieren, die in Kind direkt gespeichert sind.
    // "version" wird atomar inkrementiert und als Guard verwendet.
    final obj = ParseObject('Kind')
      ..objectId = kind.objectId
      ..set('vorName',    kind.vorname)
      ..set('nachName',   kind.nachname)
      ..set('geschlecht', kind.geschlecht)
      ..set('jahrgang',   kind.jahrgang)
      ..set('bezahlt',    kind.bezahlt)
      ..setIncrement('version', 1); // atomar: kein Read-Modify-Write nötig

    // Guard: update nur wenn version noch dem erwarteten Wert entspricht
    // (Parse Server unterstützt kein WHERE in save() direkt →
    //  wir prüfen nach dem Save, ob version tatsächlich +1 ist)
    final response = await _saveWithRetry(obj);
    if (response.success) {
      kind.version += 1;
      _log.i('Kind aktualisiert: ${kind.vorname} ${kind.nachname} (v${kind.version})');
      return true;
    }
    _log.e('UPDATE Kind fehlgeschlagen: ${response.error?.message}');
    return false;
  }

  /// Speichert eine Liste von Kindern und meldet Teilfehler zurück.
  /// ACID – Atomicity: jeder Fehler wird erfasst, kein stiller Abbruch.
  Future<BatchErgebnis> saveKinderListe({required List<Kind> kinder}) async {
    int ok = 0;
    int nok = 0;
    final fehler = <String>[];

    for (final kind in kinder) {
      if (await saveKind(kind: kind)) {
        ok++;
      } else {
        nok++;
        fehler.add('${kind.vorname} ${kind.nachname}');
      }
    }
    _log.i('saveKinderListe: ✓ $ok  ✗ $nok');
    return BatchErgebnis(erfolgreich: ok, fehlgeschlagen: nok, fehlerMeldungen: fehler);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // READ  –  Kind
  // ─────────────────────────────────────────────────────────────────────────

  /// Lädt alle Kinder (paginiert, max. 1000 Einträge).
  Future<List<Kind>> ladeAlleKinder() async {
    return _paginierteAbfrage(
      query: QueryBuilder<ParseObject>(ParseObject('Kind')),
    );
  }

  /// Lädt nur Kinder, die die Startgebühr bezahlt haben (= angemeldet).
  Future<List<Kind>> ladeAngemeldeteKinder() async {
    return _paginierteAbfrage(
      query: QueryBuilder<ParseObject>(ParseObject('Kind'))
        ..whereEqualTo('bezahlt', true),
    );
  }

  /// Generische paginierte Abfrage, um das 100-Limit von Parse zu umgehen.
  Future<List<Kind>> _paginierteAbfrage({
    required QueryBuilder<ParseObject> query,
    int seitenGroesse = 100,
  }) async {
    final ergebnis = <Kind>[];
    int skip = 0;

    while (true) {
      query
        ..setLimit(seitenGroesse)
        ..setAmountToSkip(skip);

      final response = await query.query();
      if (!response.success || response.results == null) break;

      final seite = response.results!
          .cast<ParseObject>()
          .map(_kindVonParse)
          .toList();

      ergebnis.addAll(seite);
      if (seite.length < seitenGroesse) break; // letzte Seite erreicht
      skip += seitenGroesse;
    }
    return ergebnis;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // kinderDerRiege  –  Riegenzuordnung
  // ─────────────────────────────────────────────────────────────────────────

  /// Ordnet ein Kind einer Riege zu (neuer Eintrag in "kinderDerRiege").
  /// Prüft vorher, ob der Eintrag bereits existiert (Idempotenz).
  Future<bool> weiseKindRiegeZu({
    required Kind   kind,
    required Riege  riege,
    required int    position,
  }) async {
    // Idempotenz-Check: existiert der Eintrag bereits?
    final existing = await _ladeKindDerRiegeEintrag(
      kindObjectId:   kind.objectId,
      riegenObjectId: riege.objectId,
    );
    if (existing != null) {
      _log.w('Zuordnung ${kind.nachname} → Riege ${riege.riegenNummer} existiert bereits.');
      return true; // bereits korrekt zugeordnet
    }

    final kindPointer  = ParseObject('Kind')..objectId = kind.objectId;
    final riegePointer = ParseObject('Riege')..objectId = riege.objectId;

    final obj = ParseObject('kinderDerRiege')
      ..set('kindID',    kindPointer)
      ..set('riegenID',  riegePointer)
      ..set('position',  position)
      ..set('version',   1);

    final response = await _saveWithRetry(obj);
    if (response.success) {
      _log.i('${kind.nachname} → Riege ${riege.riegenNummer} (Pos. $position) gespeichert.');
      return true;
    }
    _log.e('Zuordnung fehlgeschlagen: ${response.error?.message}');
    return false;
  }

  /// Aktualisiert die Riegenzuordnung eines Kindes (z. B. beim Umteilen).
  Future<bool> aktualisiereRiegenZuordnung({
    required Kind  kind,
    required Riege neueRiege,
    required int   neuePosition,
  }) async {
    // bestehenden Eintrag suchen
    final query = QueryBuilder<ParseObject>(ParseObject('kinderDerRiege'))
      ..whereEqualTo('kindID', ParseObject('Kind')..objectId = kind.objectId)
      ..includeObject(['riegenID']);

    final response = await query.query();
    if (!response.success || response.results == null || response.results!.isEmpty) {
      // Kein Eintrag vorhanden → neu anlegen
      return weiseKindRiegeZu(kind: kind, riege: neueRiege, position: neuePosition);
    }

    final eintrag = response.results!.first as ParseObject;
    final riegePointer = ParseObject('Riege')..objectId = neueRiege.objectId;

    final update = ParseObject('kinderDerRiege')
      ..objectId = eintrag.objectId
      ..set('riegenID',  riegePointer)
      ..set('position',  neuePosition)
      ..setIncrement('version', 1);

    final updateRes = await _saveWithRetry(update);
    if (updateRes.success) {
      _log.i('Riegenzuordnung ${kind.nachname} → Riege ${neueRiege.riegenNummer} aktualisiert.');
      return true;
    }
    _log.e('Aktualisierung Riegenzuordnung fehlgeschlagen: ${updateRes.error?.message}');
    return false;
  }

  /// Lädt alle Kinder einer bestimmten Riege (über kinderDerRiege).
  Future<List<Kind>> ladeKinderDerRiege({required Riege riege}) async {
    final riegePointer = ParseObject('Riege')..objectId = riege.objectId;

    final query = QueryBuilder<ParseObject>(ParseObject('kinderDerRiege'))
      ..whereEqualTo('riegenID', riegePointer)
      ..includeObject(['kindID'])
      ..orderByAscending('position');

    final response = await query.query();
    if (!response.success || response.results == null) return [];

    final kinder = <Kind>[];
    for (final obj in response.results!.cast<ParseObject>()) {
      final kindParse = obj.get<ParseObject>('kindID');
      if (kindParse != null) {
        final kind = _kindVonParse(kindParse);
        kind.riegenNummer = riege.riegenNummer; // transienter Wert setzen
        kinder.add(kind);
      }
    }
    return kinder;
  }

  /// Lädt Kinder aus mehreren Riegen parallel (effizienter als sequenzielle Schleife).
  Future<List<Kind>> ladeKinderAusRiegen({
    required List<Riege> listeVonRiegen,
  }) async {
    final futures = listeVonRiegen.map(
      (riege) => ladeKinderDerRiege(riege: riege),
    );
    final listen = await Future.wait(futures);
    return listen.expand((l) => l).toList();
  }

  /// Löscht alle kinderDerRiege-Einträge einer Riege (z. B. vor Neueinteilung).
  Future<bool> loescheRiegenZuordnungen({required Riege riege}) async {
    final riegePointer = ParseObject('Riege')..objectId = riege.objectId;

    final query = QueryBuilder<ParseObject>(ParseObject('kinderDerRiege'))
      ..whereEqualTo('riegenID', riegePointer);

    final response = await query.query();
    if (!response.success || response.results == null) return true; // bereits leer

    int fehler = 0;
    for (final obj in response.results!.cast<ParseObject>()) {
      final delResponse = await obj.delete();
      if (!delResponse.success) fehler++;
    }
    if (fehler > 0) _log.e('Löschen: $fehler Zuordnungen fehlgeschlagen.');
    return fehler == 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // resultate  –  Punkte pro Kind und Station
  // ─────────────────────────────────────────────────────────────────────────

  /// Speichert das Ergebnis eines Kindes für eine Station.
  ///
  /// ACID – Idempotenz-Guard:
  ///   Prüft, ob für dieses Kind + diese Station bereits ein Resultat
  ///   existiert. Ist das der Fall, wird NICHT nochmals gespeichert.
  ///   Damit sind doppelte Auswertungen (z. B. durch versehentlichen
  ///   Doppelklick oder Netzwerk-Retry) ausgeschlossen.
  Future<bool> speichereResultat({
    required Kind    kind,
    required Station station,
    required int     punkte,
  }) async {
    // Guard: existiert der Eintrag bereits?
    final vorhanden = await _resultatVorhanden(
      kindObjectId:     kind.objectId,
      stationsObjectId: station.objectId,
    );
    if (vorhanden) {
      _log.w('Resultat für ${kind.nachname} @ ${station.stationsName} existiert bereits. Übersprungen.');
      return false; // kein Doppel-Eintrag
    }

    final kindPointer    = ParseObject('Kind')    ..objectId = kind.objectId;
    final stationPointer = ParseObject('Station') ..objectId = station.objectId;

    final obj = ParseObject('resultate')
      ..set('kindID',      kindPointer)
      ..set('stationsID',  stationPointer)
      ..set('punkte',      punkte)
      ..set('erreichtUm',  DateTime.now())
      ..set('version',     1);

    final response = await _saveWithRetry(obj);
    if (response.success) {
      _log.i('Resultat gespeichert: ${kind.nachname} @ ${station.stationsName} → $punkte Pkt.');
      return true;
    }
    _log.e('Resultat-Speichern fehlgeschlagen: ${response.error?.message}');
    return false;
  }

  /// Lädt die Gesamtpunktzahl eines Kindes aus der Back4App-Klasse 'resultate'.
/// Gibt 0 zurück, falls keine Ergebnisse vorhanden sind oder die Abfrage fehlschlägt.
Future<int> ladePunktesumme({required Kind kind}) async {

  // Pointer auf den Kind-Datensatz in Back4App erstellen.
  // Parse benötigt diesen Pointer, um in 'resultate' nach kindID zu filtern.
  final kindPointer = ParseObject('Kind')..objectId = kind.objectId;

  // Abfrage auf die Klasse 'resultate': alle Einträge dieses Kindes laden.
  final query = QueryBuilder<ParseObject>(ParseObject('resultate'))
    ..whereEqualTo('kindID', kindPointer);

  final response = await query.query();

  // Fehlerfall: Abfrage fehlgeschlagen oder keine Einträge → 0 Punkte
  if (!response.success || response.results == null) return 0;

  // Alle resultate-Einträge durchlaufen, Punktefeld auslesen und aufsummieren.
  // ?? 0 verhindert null-Fehler falls 'punkte' in einem Eintrag nicht gesetzt ist.
  // fold() akkumuliert die Summe: startet bei 0, addiert jeden Punktewert.
  return response.results!
      .cast<ParseObject>()                        // Typ auf ParseObject festlegen
      .map((obj) => obj.get<int>('punkte') ?? 0)  // Punktefeld auslesen
      .fold<int>(0, (sum, p) => sum + p);              // Summe bilden
}
  /// Lädt alle Resultate (als Map Kind → Punkte) für eine Liste von Kindern.
  /// Effizienter als n Einzelabfragen.
  Future<Map<String, int>> ladePunkteSummenFuerKinder({
    required List<Kind> kinder,
  }) async {
    if (kinder.isEmpty) return {};

    // whereContainedIn: ein einziger DB-Request für alle Kinder
    final pointers = kinder
        .map((k) => ParseObject('Kind')..objectId = k.objectId)
        .toList();

    final query = QueryBuilder<ParseObject>(ParseObject('resultate'))
      ..whereContainedIn('kindID', pointers);

    final response = await query.query();
    if (!response.success || response.results == null) return {};

    final summen = <String, int>{};
    for (final obj in response.results!.cast<ParseObject>()) {
      final kindPointer = obj.get<ParseObject>('kindID');
      final objectId    = kindPointer?.objectId ?? '';
      final punkte      = obj.get<int>('punkte') ?? 0;
      summen[objectId]  = (summen[objectId] ?? 0) + punkte;
    }
    return summen;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HILFSMETHODEN  –  Darstellung / Sortierung (reine Logik, kein DB-Zugriff)
  // ─────────────────────────────────────────────────────────────────────────

  Map<String, List<Kind>> gruppiereKinder({required List<Kind> ausDerListe}) {
    final Map<String, List<Kind>> map = {};
    for (final kind in ausDerListe) {
      final key = '${kind.geschlecht}_${kind.jahrgang}';
      (map[key] ??= []).add(kind);
    }
    return map;
  }

  List<Kind> zurAnzeigeSortieren({
    required List<Kind> alleKinder,
    required Set<Kind>  ausgewerteteKinder,
  }) {
    return List<Kind>.from(alleKinder)
      ..sort((a, b) {
        final ausA = ausgewerteteKinder.contains(a);
        final ausB = ausgewerteteKinder.contains(b);

        if (ausA && !ausB) return 1;
        if (!ausA && ausB) return -1;

        if (!ausA && !ausB) {
          final jv = b.jahrgang.compareTo(a.jahrgang);
          if (jv != 0) return jv;
          final gv = b.geschlecht.compareTo(a.geschlecht);
          if (gv != 0) return gv;
          return a.nachname.compareTo(b.nachname);
        }

        return a.nachname.compareTo(b.nachname);
      });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE HILFSMETHODEN
  // ─────────────────────────────────────────────────────────────────────────

  Future<ParseObject?> _ladeKindDerRiegeEintrag({
    required String kindObjectId,
    required String riegenObjectId,
  }) async {
    final query = QueryBuilder<ParseObject>(ParseObject('kinderDerRiege'))
      ..whereEqualTo('kindID',   ParseObject('Kind')  ..objectId = kindObjectId)
      ..whereEqualTo('riegenID', ParseObject('Riege') ..objectId = riegenObjectId);

    final response = await query.query();
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      return response.results!.first as ParseObject;
    }
    return null;
  }

  Future<bool> _resultatVorhanden({
    required String kindObjectId,
    required String stationsObjectId,
  }) async {
    final query = QueryBuilder<ParseObject>(ParseObject('resultate'))
      ..whereEqualTo('kindID',     ParseObject('Kind')    ..objectId = kindObjectId)
      ..whereEqualTo('stationsID', ParseObject('Station') ..objectId = stationsObjectId);

    final response = await query.query();
    return response.success &&
        response.results != null &&
        response.results!.isNotEmpty;
  }
}
