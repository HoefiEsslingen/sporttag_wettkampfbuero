import 'tools/logger.util.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'kind_klasse.dart';
import 'riegen_klasse.dart';

class KindRepository {
  // Erstellt ein Kind-Objekt aus der Datenbank-Daten (ParseObject)
  Kind createKindFromParse(ParseObject parseObject) {
    return Kind(
      objectId: parseObject.get<String>('objectId') ?? '',
      vorname: parseObject.get<String>('Vorname') ?? '',
      nachname: parseObject.get<String>('Nachname') ?? '',
      jahrgang: parseObject.get<String>('Jahrgang') ?? '',
      geschlecht: parseObject.get<String>('Geschlecht') ?? '',
      erreichtePunkte: parseObject.get<int>('Punkte') ?? 0,
      bezahlt: parseObject.get<bool>('bezahlt') ?? false,
      riegenNummer: parseObject.get<int>('RiegenNummer') ?? 0,
    );
  }

  // Logger einrichten
  final log = getLogger();

  // Speichert ein Kind-Objekt in die Back4App-Datenbank
  Future<bool> saveKindToDatabase({required Kind kind}) async {
    final ParseObject parseKind = ParseObject('Kind')
      ..set('Vorname', kind.vorname)
      ..set('Nachname', kind.nachname)
      ..set('Jahrgang', kind.jahrgang)
      ..set('Geschlecht', kind.geschlecht)
      ..set('Punkte', kind.erreichtePunkte)
      ..set('bezahlt', kind.bezahlt)
      ..set('RiegenNummer', kind.riegenNummer);

    if (kind.objectId.isNotEmpty) {
      // Wenn die objectID existiert, setze sie, um das bestehende Objekt zu aktualisieren
      parseKind.objectId = kind.objectId;
    }

    // Speichere das Kind-Objekt in die Datenbank
    final ParseResponse response = await parseKind.save();

    if (response.success) {
      log.i('Kind erfolgreich gespeichert.');
      return true;
    } else {
      log.i('Fehler beim Speichern des Kinds: ${response.error?.message}');
      return false;
    }
  }

  // Methode zum Laden eines Kindes anhand des Namens und Jahrgangs aus der Datenbank
  Future<Kind?> loadKindFromDatabase(
      String vorname, String nachname, String jahrgang) async {
    final QueryBuilder<ParseObject> query =
        QueryBuilder<ParseObject>(ParseObject('Kind'))
          ..whereEqualTo('Vorname', vorname)
          ..whereEqualTo('Nachname', nachname)
          ..whereEqualTo('Jahrgang', jahrgang);

    final ParseResponse response = await query.query();

    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      return createKindFromParse(response.results!.first);
    } else {
      log.i(
          'Kein Kind gefunden mit Vorname: $vorname, Nachname: $nachname, Jahrgang: $jahrgang');
      return null;
    }
  }

  Future<List<Kind>> loadAllKinder() async {
    const int limit = 100;
    int skip = 0;
    final List<Kind> alleKinder = [];

    while (true) {
      final query = QueryBuilder<ParseObject>(ParseObject('Kind'))
        ..setLimit(limit)
        ..setAmountToSkip(skip);

      final response = await query.query();

      if (response.success && response.results != null) {
        final kinderTeilListe = response.results!
            .map((obj) => createKindFromParse(obj as ParseObject))
            .toList();

        alleKinder.addAll(kinderTeilListe);

        if (kinderTeilListe.length < limit) break; // keine weiteren Daten
        skip += limit;
      } else {
        break; // Abbruch bei Fehler oder leeren Ergebnissen
      }
    }

    return alleKinder;
  }

  Future<List<Kind>> loadKinderAusRiegen(
      {required List<Riege> listeVonRiegen}) async {
    final List<Kind> alleKinder = [];

/*************************************************************
 * Alte Version der Schleife, um Kinder aus mehreren Riegen zu laden
 * Diese Version ist weniger performant, da sie für jede Riege eine separate Anfrage an die Datenbank sendet.
 * Sie wurde durch den neuen Code ersetzt, der alle Kinder in einem Rutsch lädt.
for (var riege in listeVonRiegen) {
  var kinderTeilListe = await loadKinderAusRiege(mitRiegenNummer: riege.riegenNummer);
  alleKinder.addAll(kinderTeilListe);
}
************************************************************/
// Performanter ist folgender Code, der alle Kinder in einem Rutsch lädt
    final futures = listeVonRiegen.map(
        (riege) => loadKinderAusRiege(mitRiegenNummer: riege.riegenNummer));

    final listenVonKindern = await Future.wait(futures);

    for (var kinderListe in listenVonKindern) {
      alleKinder.addAll(kinderListe);
    }
    return alleKinder;
  }

  Future<List<Kind>> loadKinderAusRiege({required int mitRiegenNummer}) async {
    const int limit = 100;
    int skip = 0;
    final List<Kind> alleKinder = [];

    while (true) {
      // Filtert die Kinder nach der angegebenen RiegenNummer
      final query = QueryBuilder<ParseObject>(ParseObject('Kind'))
        ..setLimit(limit)
        ..setAmountToSkip(skip)
        ..whereEqualTo('RiegenNummer', mitRiegenNummer);

      final response = await query.query();

      if (response.success && response.results != null) {
        final kinderTeilListe = response.results!
            .map((obj) => createKindFromParse(obj as ParseObject))
            .toList();

        alleKinder.addAll(kinderTeilListe);

        if (kinderTeilListe.length < limit) break; // keine weiteren Daten
        skip += limit;
      } else {
        break; // Abbruch bei Fehler oder leeren Ergebnissen
      }
    }
    return alleKinder;
  }

  // NEU: Methode, um eine Liste von Kindern als Ganzes in die Datenbank zu speichern
  Future<void> saveKinderListeToDatabase(List<Kind> kinderListe) async {
    for (var kindElement in kinderListe) {
      await saveKindToDatabase(kind: kindElement); // Verwendet die vorhandene Methode zum Speichern eines einzelnen Kindes
    }
  }

  // NEU: Methode, um alle Kinder einer
  Map<String, List<Kind>> gruppiereKinder({required List<Kind> ausDerListe}) {
    final Map<String, List<Kind>> gruppierteKinder = {};

    for (var kind in ausDerListe) {
      final key = '${kind.geschlecht}_${kind.jahrgang}';

      if (!gruppierteKinder.containsKey(key)) {
        gruppierteKinder[key] = [];
      }

      gruppierteKinder[key]!.add(kind);
    }

    return gruppierteKinder;
  }
}
