import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'package:sporttag/src/klassen/station_klasse.dart';
import 'package:sporttag/src/tools/logger.util.dart';

// ═══════════════════════════════════════════════════════════════════════════
// StationRepository
//
// Datenbankklasse: Station → stationsName, stationsNummer, nurZehnKampf, version
//
// Stationen sind Stammdaten – sie werden einmalig angelegt und dann nur
// noch gelesen. Daher liegt der Schwerpunkt auf effizienten Read-Methoden
// mit lokalem Caching (damit die App während eines Wettkampftages die
// Station-objectIDs nicht ständig neu laden muss).
// ═══════════════════════════════════════════════════════════════════════════
class StationRepository {
  final _log = getLogger();

  /// Lokaler Cache: stationsName → Station
  /// Verhindert wiederholte DB-Abfragen für dieselben Stammdaten.
  final Map<String, Station> _cache = {};

  // ─────────────────────────────────────────────────────────────────────────
  // INTERNE HILFSMETHODEN
  // ─────────────────────────────────────────────────────────────────────────

  Station _stationVonParse(ParseObject p) {
    return Station(
      objectId:       p.objectId ?? '',
      stationsName:   p.get<String>('stationsName')   ?? '',
      stationsNummer: p.get<int>('stationsNummer')     ?? 0,
      nurZehnKampf:   p.get<bool>('nurZehnKampf')      ?? false,
      version:        p.get<int>('version')             ?? 1,
    );
  }

  Future<ParseResponse> _saveWithRetry(ParseObject obj, {int maxVersuche = 3}) async {
    ParseResponse response = await obj.save();
    for (int v = 2; v <= maxVersuche && !response.success; v++) {
      await Future.delayed(Duration(seconds: 1 << (v - 2)));
      response = await obj.save();
    }
    return response;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────────────────────────────────────

  /// Lädt alle Stationen und befüllt den Cache.
  Future<List<Station>> ladeAlleStationen() async {
    final query = QueryBuilder<ParseObject>(ParseObject('Station'))
      ..orderByAscending('stationsNummer');

    final response = await query.query();
    if (!response.success || response.results == null) return [];

    final stationen = response.results!
        .cast<ParseObject>()
        .map(_stationVonParse)
        .toList();

    // Cache füllen
    for (final s in stationen) {
      _cache[s.stationsName] = s;
    }
    _log.i('${stationen.length} Stationen geladen und gecacht.');
    return stationen;
  }

  /// Gibt eine Station anhand ihres Namens zurück.
  /// Nutzt den Cache, um DB-Zugriffe zu vermeiden.
  Future<Station?> ladeStationNachName({required String stationsName}) async {
    if (_cache.containsKey(stationsName)) return _cache[stationsName];

    final query = QueryBuilder<ParseObject>(ParseObject('Station'))
      ..whereEqualTo('stationsName', stationsName);

    final response = await query.query();
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      final station = _stationVonParse(response.results!.first as ParseObject);
      _cache[stationsName] = station;
      return station;
    }
    _log.w('Station "$stationsName" nicht gefunden.');
    return null;
  }

  /// Gibt nur Stationen zurück, die für den angegebenen Wettkampftyp relevant sind.
  Future<List<Station>> ladeStationenFuerWettkampf({required bool istZehnkampf}) async {
    if (_cache.isNotEmpty) {
      final gefiltert = _cache.values.where((s) {
        if (istZehnkampf) return true;         // Zehnkampf: alle Stationen
        return !s.nurZehnKampf;               // Fünfkampf: nur nicht-exklusive
      }).toList()
        ..sort((a, b) => a.stationsNummer.compareTo(b.stationsNummer));
      return gefiltert;
    }

    // Cache leer → alles laden
    await ladeAlleStationen();
    return ladeStationenFuerWettkampf(istZehnkampf: istZehnkampf);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE / UPDATE  (Stammdaten-Pflege, selten benötigt)
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> saveStation({required Station station}) async {
    final isNew = station.objectId.isEmpty;
    final obj   = ParseObject('Station');

    if (!isNew) obj.objectId = station.objectId;

    obj
      ..set('stationsName',   station.stationsName)
      ..set('stationsNummer', station.stationsNummer)
      ..set('nurZehnKampf',   station.nurZehnKampf)
      ..setIncrement('version', 1);

    final response = await _saveWithRetry(obj);
    if (response.success) {
      if (isNew) {
        station.objectId = (response.results!.first as ParseObject).objectId!;
      }
      _cache[station.stationsName] = station; // Cache aktualisieren
      _log.i('Station "${station.stationsName}" gespeichert.');
      return true;
    }
    _log.e('Station-Speichern fehlgeschlagen: ${response.error?.message}');
    return false;
  }

  // Cache-Verwaltung
  void cacheLeeren() => _cache.clear();
  bool get cacheGefuellt => _cache.isNotEmpty;
}
