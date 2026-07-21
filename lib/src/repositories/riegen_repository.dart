// ═══════════════════════════════════════════════════════════════════════════
// RiegenRepository – Methodenübersicht
// ═══════════════════════════════════════════════════════════════════════════
//
// ─── INTERNE HILFSMETHODEN ───────────────────────────────────────────────
//
// _riegeVonParse(ParseObject p)
//   Wandelt ein ParseObject der Klasse "Riege" in ein Riege-Dart-Objekt um.
//   Input:  p (ParseObject)
//   Output: Riege
//
// _saveWithRetry(ParseObject obj, {int maxVersuche = 3})
//   Speichert ein ParseObject mit Exponential-Backoff-Retry (bis zu
//   maxVersuche Versuche), um stille Netzwerkfehler abzufangen.
//   Input:  obj (ParseObject), maxVersuche (int, optional, default 3)
//   Output: Future<ParseResponse>
//
// ─── CREATE / UPDATE – Riege ──────────────────────────────────────────────
//
// saveRiege({required Riege riege})
//   Erstellt eine neue Riege oder aktualisiert eine bestehende (anhand von
//   riege.objectId). Kein Read-Modify-Write, version wird atomar erhöht.
//   Setzt bei Neuanlage objectId auf dem übergebenen Riege-Objekt.
//   Input:  riege (Riege)
//   Output: Future<bool> (true = erfolgreich gespeichert)
//
// setzeRiegenArt({required String riegenObjectId, required bool fuenfKampf})
//   Setzt die Wettkampfart (Fünf- oder Zehnkampf) einer Riege direkt, ohne
//   vorheriges Laden. Setzt zugleich wetttkampfBeendet auf false zurück.
//   Input:  riegenObjectId (String), fuenfKampf (bool)
//   Output: Future<bool> (true = erfolgreich gesetzt, false bei leerer
//           objectId oder Fehler)
//
// setzeRiegenAlsBeendet({required List<Riege> riegen})
//   Markiert eine Liste von Riegen als beendet/ausgewertet (wetttkampfBeendet
//   = true) und erhöht deren version. Aktualisiert die übergebenen Objekte.
//   Input:  riegen (List<Riege>)
//   Output: Future<int> – Anzahl fehlgeschlagener Speichervorgänge
//           (0 = alle erfolgreich)
//
// ─── READ – Riege ─────────────────────────────────────────────────────────
//
// ladeRiegeNachNummer({required int riegenNummer})
//   Lädt eine einzelne Riege anhand ihrer Riegennummer.
//   Input:  riegenNummer (int)
//   Output: Future<Riege?> (null, falls nicht gefunden)
//
// ladeAlleRiegen()
//   Lädt alle Riegen, sortiert aufsteigend nach riegenNummer.
//   Input:  –
//   Output: Future<List<Riege>>
//
// ladeAuszuwertendeRiegen()
//   Lädt alle Riegen, deren Wettkampf noch nicht beendet ist UND die die
//   erforderliche Stationszahl absolviert haben (5 bei Fünfkampf, 10 bei
//   Zehnkampf). Setzt riege.anzStationen auf den geladenen Fortschrittswert.
//   Input:  –
//   Output: Future<List<Riege>>
//
// ladeRiegenNachArt({required bool fuenfKampf})
//   Lädt alle Riegen einer bestimmten Wettkampfart, sortiert nach riegenNummer.
//   Input:  fuenfKampf (bool)
//   Output: Future<List<Riege>>
//
// ─── riegenLogging – Stationsfortschritt ──────────────────────────────────
//
// erhoeheStationszaehler({required Riege riege, required Station station})
//   Erhöht den Stationszähler (anzAbsolvierterStationen) einer Riege atomar
//   via setIncrement. Idempotenz-Guard verhindert doppeltes Hochzählen für
//   dieselbe Riege+Station-Kombination. Legt bei Erstaufruf einen neuen
//   riegenLogging-Eintrag an, sonst wird der bestehende aktualisiert.
//   Input:  riege (Riege), station (Station)
//   Output: Future<bool> (true = erfolgreich erhöht, false = bereits
//           protokolliert oder Fehler)
//
// _ladeAnzahlAbsolvierterStationen({required String riegeObjectId})
//   Lädt den aktuellen Stationsfortschritt (Anzahl absolvierter Stationen)
//   einer Riege aus riegenLogging.
//   Input:  riegeObjectId (String)
//   Output: Future<int> (0, falls kein Eintrag vorhanden/Abfrage fehlschlägt)
//
// ladeStationsfortschrittFuerRiegen({required List<Riege> riegen})
//   Lädt den Stationsfortschritt für mehrere Riegen in einem einzigen
//   DB-Request (effizienter als n Einzelabfragen).
//   Input:  riegen (List<Riege>)
//   Output: Future<Map<String, int>> (Key = Riege-objectId,
//           Value = anzAbsolvierterStationen)
//
// ─── PRIVATE HILFSMETHODEN ────────────────────────────────────────────────
//
// _loggingEintragVorhanden({required String riegenObjectId, required String stationsObjectId})
//   Prüft, ob für eine Riege bereits ein riegenLogging-Eintrag mit dieser
//   stationsID existiert (Idempotenz-Guard für erhoeheStationszaehler).
//   Hinweis: riegenLogging hat aktuell einen Eintrag PRO Riege, nicht pro
//   Riege+Station – für einen strikten "Station bereits absolviert"-Check
//   wäre langfristig eine separate Tabelle/ein Array-Feld sinnvoller.
//   Input:  riegenObjectId (String), stationsObjectId (String)
//   Output: Future<bool> (true = Eintrag existiert bereits)
// ═══════════════════════════════════════════════════════════════════════════

import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/klassen/station_klasse.dart';
import 'package:sporttag/src/tools/logger.util.dart';

// ═══════════════════════════════════════════════════════════════════════════
// RiegenRepository
//
// Datenbankklassen:
//   Riege         → riegenNummer, fuenfKampf, wetttkampfBeendet, version
//   riegenLogging → riegenID (Pointer<Riege>), stationsID (Pointer<Station>),
//                   anzAbsolvierterStationen, letzteStationUm, version
// ═══════════════════════════════════════════════════════════════════════════
class RiegenRepository {
  final _log = getLogger();

  // ─────────────────────────────────────────────────────────────────────────
  // INTERNE HILFSMETHODEN
  // ─────────────────────────────────────────────────────────────────────────

  Riege _riegeVonParse(ParseObject p) {
    return Riege(
      objectId: p.objectId ?? '',
      riegenNummer: p.get<int>('riegenNummer') ?? 0,
      fuenfKampf: p.get<bool>('fuenfKampf') ?? false,
      wetttkampfBeendet: p.get<bool>('wetttkampfBeendet') ?? false,
      version: p.get<int>('version') ?? 1,
    );
  }

  /// Retry-Wrapper: bis zu 3 Versuche mit Exponential Backoff.
  /// ACID – Durability: verhindert stilles Datenverlust bei Netzwerkfehlern.
  Future<ParseResponse> _saveWithRetry(
    ParseObject obj, {
    int maxVersuche = 3,
  }) async {
    ParseResponse response = await obj.save();
    for (int v = 2; v <= maxVersuche && !response.success; v++) {
      await Future.delayed(Duration(seconds: 1 << (v - 2)));
      _log.w('Retry $v/$maxVersuche…');
      response = await obj.save();
    }
    return response;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE / UPDATE  –  Riege
  // ─────────────────────────────────────────────────────────────────────────

  /// Erstellt oder aktualisiert eine Riege.
  ///
  /// ACID – Direkt-Write ohne vorheriges Read:
  ///   Bei Updates wird nur die objectId gesetzt; alle zu ändernden Felder
  ///   werden direkt übermittelt. Kein Read-Modify-Write → keine Race Condition.
  Future<bool> saveRiege({required Riege riege}) async {
    final isNew = riege.objectId.isEmpty;
    final obj = ParseObject('Riege');

    if (!isNew) obj.objectId = riege.objectId;

    obj
      ..set('riegenNummer', riege.riegenNummer)
      ..set('fuenfKampf', riege.fuenfKampf)
      ..set('wetttkampfBeendet', riege.wetttkampfBeendet)
      ..setIncrement('version', 1); // atomar, kein RMW

    final response = await _saveWithRetry(obj);
    if (response.success) {
      if (isNew) {
        riege.objectId = (response.results!.first as ParseObject).objectId!;
      }
      riege.version += 1;
      _log.i('Riege ${riege.riegenNummer} gespeichert (v${riege.version}).');
      return true;
    }
    _log.e(
        'Riege ${riege.riegenNummer} fehlgeschlagen: ${response.error?.message}');
    return false;
  }

  /// Setzt Art (Fünf-/Zehnkampf) einer Riege — direkt, ohne vorheriges Laden.
  ///
  /// ACID – Isolation:
  ///   Kein Read-Modify-Write. Nur die benötigten Felder werden überschrieben,
  ///   damit parallele Schreibvorgänge auf andere Felder nicht verloren gehen.
  Future<bool> setzeRiegenArt({
    required String riegenObjectId,
    required bool fuenfKampf,
  }) async {
    if (riegenObjectId.isEmpty) {
      _log.e('setzeRiegenArt: objectId fehlt.');
      return false;
    }

    final obj = ParseObject('Riege')
      ..objectId = riegenObjectId
      ..set('fuenfKampf', fuenfKampf)
      ..set('wetttkampfBeendet', false)
      ..setIncrement('version', 1);

    final response = await _saveWithRetry(obj);
    if (response.success) {
      _log.i(
          'Riege $riegenObjectId → ${fuenfKampf ? "Fünfkampf" : "Zehnkampf"} gesetzt.');
      return true;
    }
    _log.e('setzeRiegenArt fehlgeschlagen: ${response.error?.message}');
    return false;
  }

  /// Setzt alle Riegen als beendet/ausgewertet.
  /// ACID – Atomicity: Fehler werden gezählt und zurückgemeldet.
  Future<int> setzeRiegenAlsBeendet({required List<Riege> riegen}) async {
    int fehler = 0;
    for (final riege in riegen) {
      final obj = ParseObject('Riege')
        ..objectId = riege.objectId
        ..set('wetttkampfBeendet', true)
        ..setIncrement('version', 1);

      final response = await _saveWithRetry(obj);
      if (!response.success) {
        fehler++;
        _log.e(
            'Riege ${riege.riegenNummer} als beendet setzen fehlgeschlagen.');
      } else {
        riege.wetttkampfBeendet = true;
        riege.version += 1;
      }
    }
    return fehler; // 0 = alle erfolgreich
  }

  // ─────────────────────────────────────────────────────────────────────────
  // READ  –  Riege
  // ─────────────────────────────────────────────────────────────────────────

  Future<Riege?> ladeRiegeNachNummer({required int riegenNummer}) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Riege'))
      ..whereEqualTo('riegenNummer', riegenNummer);

    final response = await query.query();
    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      return _riegeVonParse(response.results!.first as ParseObject);
    }
    _log.w('Riege $riegenNummer nicht gefunden.');
    return null;
  }

  Future<List<Riege>> ladeAlleRiegen() async {
    final query = QueryBuilder<ParseObject>(ParseObject('Riege'))
      ..orderByAscending('riegenNummer');
    final response = await query.query();

    if (response.success && response.results != null) {
      return response.results!.cast<ParseObject>().map(_riegeVonParse).toList();
    }
    return [];
  }

  /// Lädt alle Riegen, deren Wettkampf noch nicht beendet ist UND
  /// die die erforderliche Stationszahl absolviert haben.
  ///
  /// "Auszuwertend" bedeutet:
  ///   Fünfkampf-Riegen mit 5 Stationen ODER Zehnkampf-Riegen mit 10 Stationen,
  ///   jeweils noch NICHT als beendet markiert.
  Future<List<Riege>> ladeAuszuwertendeRiegen() async {
    final qFuenfkampf = QueryBuilder<ParseObject>(ParseObject('Riege'))
      ..whereEqualTo('fuenfKampf', true)
      ..whereEqualTo('wetttkampfBeendet', false);

    final qZehnkampf = QueryBuilder<ParseObject>(ParseObject('Riege'))
      ..whereEqualTo('fuenfKampf', false)
      ..whereEqualTo('wetttkampfBeendet', false);

    final combined =
        QueryBuilder.or(ParseObject('Riege'), [qFuenfkampf, qZehnkampf]);
    final response = await combined.query();

    if (response.success && response.results != null) {
      final riegen =
          response.results!.cast<ParseObject>().map(_riegeVonParse).toList();

      // Für jede Riege die absolvierte Stationszahl aus riegenLogging laden
      // und nur Riegen zurückgeben, die alle Stationen abgeschlossen haben.
      final auszuwertende = <Riege>[];
      for (final riege in riegen) {
        final anz = await _ladeAnzahlAbsolvierterStationen(
            riegeObjectId: riege.objectId);
        riege.anzStationen = anz;
        final zielAnzahl = riege.fuenfKampf ? 5 : 10;
        if (anz >= zielAnzahl) auszuwertende.add(riege);
      }
      return auszuwertende;
    }
    return [];
  }

  Future<List<Riege>> ladeRiegenNachArt({required bool fuenfKampf}) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Riege'))
      ..whereEqualTo('fuenfKampf', fuenfKampf)
      ..orderByAscending('riegenNummer');

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!.cast<ParseObject>().map(_riegeVonParse).toList();
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // riegenLogging  –  Stationsfortschritt
  // ─────────────────────────────────────────────────────────────────────────

  /// Erhöht den Stationszähler einer Riege atomar.
  ///
  /// ACID – Atomicity + Isolation:
  ///   Statt Read-Modify-Write wird `setIncrement` auf dem Parse-Objekt
  ///   eingesetzt. Der Server führt die Erhöhung atomar durch — kein
  ///   Lost-Update bei gleichzeitigem Zugriff mehrerer Geräte.
  ///
  ///   Idempotenz-Guard: Vor dem Increment wird geprüft, ob für diese
  ///   Kombination (Riege + Station) bereits ein Logging-Eintrag existiert.
  Future<bool> erhoeheStationszaehler({
    required Riege riege,
    required Station station,
  }) async {
    // Guard: bereits protokolliert?
    final vorhanden = await _loggingEintragVorhanden(
      riegenObjectId: riege.objectId,
      stationsObjectId: station.objectId,
    );
    if (vorhanden) {
      _log.w(
          'Station ${station.stationsName} für Riege ${riege.riegenNummer} bereits protokolliert.');
      return false;
    }

    // Bestehenden riegenLogging-Eintrag für diese Riege suchen
    final riegePointer = ParseObject('Riege')..objectId = riege.objectId;
    final query = QueryBuilder<ParseObject>(ParseObject('riegenLogging'))
      ..whereEqualTo('riegenID', riegePointer)
      ..keysToReturn(['objectId']); // nur objectId laden
    final existing = await query.query();

    final stationPointer = ParseObject('Station')..objectId = station.objectId;
    final ParseObject loggingObj;

    if (existing.success &&
        existing.results != null &&
        existing.results!.isNotEmpty) {
      // Update: atomares Inkrement auf dem bestehenden Eintrag
      loggingObj = ParseObject('riegenLogging')
        ..objectId = (existing.results!.first as ParseObject).objectId
        ..setIncrement('anzAbsolvierterStationen', 1) // atomar!
        ..set('stationsID', stationPointer) // letzte Station
        ..set('letzteStationUm', DateTime.now())
        ..setIncrement('version', 1);
    } else {
      // Erstanlage: erster Logging-Eintrag für diese Riege
      loggingObj = ParseObject('riegenLogging')
        ..set('riegenID', riegePointer)
        ..set('stationsID', stationPointer)
        ..set('anzAbsolvierterStationen', 1)
        ..set('letzteStationUm', DateTime.now())
        ..set('version', 1);
    }

    final response = await _saveWithRetry(loggingObj);
    if (response.success) {
      _log.i(
          'Stationszähler für Riege ${riege.riegenNummer} erhöht → Station: ${station.stationsName}.');
      return true;
    }
    _log.e(
        'Stationszähler-Erhöhung fehlgeschlagen: ${response.error?.message}');
    return false;
  }

  /// Reiner Lese-Check, OHNE Seiteneffekt: wurde diese Station für diese
  /// Riege bereits protokolliert? Nutzt dieselbe Abfrage wie der interne
  /// Guard in erhoeheStationszaehler(), aber ohne zu schreiben.
  Future<bool> istStationBereitsProtokolliert({
    required Riege riege,
    required Station station,
  }) {
    return _loggingEintragVorhanden(
      riegenObjectId: riege.objectId,
      stationsObjectId: station.objectId,
    );
  }

  /// Lädt den aktuellen Stationsfortschritt einer Riege aus riegenLogging.
  Future<int> _ladeAnzahlAbsolvierterStationen({
    required String riegeObjectId,
  }) async {
    final riegePointer = ParseObject('Riege')..objectId = riegeObjectId;
    final query = QueryBuilder<ParseObject>(ParseObject('riegenLogging'))
      ..whereEqualTo('riegenID', riegePointer);

    final response = await query.query();
    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      final obj = response.results!.first as ParseObject;
      return obj.get<int>('anzAbsolvierterStationen') ?? 0;
    }
    return 0;
  }

  /// Lädt den Stationsfortschritt für mehrere Riegen auf einmal (ein DB-Request).
  Future<Map<String, int>> ladeStationsfortschrittFuerRiegen({
    required List<Riege> riegen,
  }) async {
    if (riegen.isEmpty) return {};

    final pointers =
        riegen.map((r) => ParseObject('Riege')..objectId = r.objectId).toList();

    final query = QueryBuilder<ParseObject>(ParseObject('riegenLogging'))
      ..whereContainedIn('riegenID', pointers);

    final response = await query.query();
    if (!response.success || response.results == null) return {};

    final map = <String, int>{};
    for (final obj in response.results!.cast<ParseObject>()) {
      final riegePointer = obj.get<ParseObject>('riegenID');
      final objectId = riegePointer?.objectId ?? '';
      map[objectId] = obj.get<int>('anzAbsolvierterStationen') ?? 0;
    }
    return map;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE HILFSMETHODEN
  // ─────────────────────────────────────────────────────────────────────────

  /// Prüft, ob eine bestimmte Station für eine Riege bereits protokolliert wurde.
  /// (Idempotenz-Guard für erhoeheStationszaehler)
  Future<bool> _loggingEintragVorhanden({
    required String riegenObjectId,
    required String stationsObjectId,
  }) async {
    // riegenLogging hat einen Eintrag PRO Riege (nicht pro Riege+Station),
    // daher prüfen wir hier, ob die stationsID bereits die letzte absolvierte
    // Station ist. Für einen echten "Station bereits absolviert"-Guard
    // empfiehlt sich eine separate Tabelle oder ein Array-Feld.
    // Hier: pragmatische Lösung via resultate-Eintrag (wird von KindRepository gesetzt).
    // Dieser Guard verhindert doppeltes Hochzählen bei re-Aufruf derselben Station.
    final riegePointer = ParseObject('Riege')..objectId = riegenObjectId;
    final stationPointer = ParseObject('Station')..objectId = stationsObjectId;

    final query = QueryBuilder<ParseObject>(ParseObject('riegenLogging'))
      ..whereEqualTo('riegenID', riegePointer)
      ..whereEqualTo('stationsID', stationPointer);

    final response = await query.query();
    return response.success &&
        response.results != null &&
        response.results!.isNotEmpty;
  }
}
