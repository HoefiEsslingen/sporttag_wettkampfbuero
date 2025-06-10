import 'logger.util.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../klassen/riegen_klasse.dart';

class RiegenRepository {
  // Erstellt ein Riegen-Objekt aus der Datenbank-Daten (ParseObject)
  Riege holeRiegeVonDatabase({required ParseObject parseObject}) {
    return Riege(
      objectId: parseObject.get<String>('objectId') ?? '',
      riegenNummer: parseObject.get<int>('RiegenNr') ?? 0,
      fuenfKampf: parseObject.get<bool>('FuenfKampf') ?? false,
      anzStationen: parseObject.get<int>('AnzWettbewerbe') ?? 0,
      ausgewertet: parseObject.get<bool>('ausgewertet') ?? false,
    );
  }

  // Logger einrichten
  final log = getLogger();

  // Speichert ein Kind-Objekt in die Back4App-Datenbank
  Future<void> saveRiegeToDatabase({required Riege riege}) async {
    final ParseObject parseRiege = ParseObject('Riege')
      ..set('FuenfKampf', riege.fuenfKampf)
      ..set('AnzWettbewerbe', riege.anzStationen)
      ..set('ausgewertet', riege.ausgewertet);

    if (riege.objectId.isNotEmpty) {
      // Wenn die objectID existiert, setze sie, um das bestehende Objekt zu aktualisieren
      parseRiege.objectId = riege.objectId;
    }

    // Speichere das Kind-Objekt in die Datenbank
    final ParseResponse response = await parseRiege.save();

    if (response.success) {
      log.i('Riege erfolgreich gespeichert.');
    } else {
      log.i('Fehler beim Speichern der Riege: ${response.error?.message}');
    }
  }

  // Methode zum Laden einer Riege anhand deren Nummer aus der Datenbank
  Future<Riege?> loadRiegeFromDatabase({required int riegenNummer}) async {
    final QueryBuilder<ParseObject> query =
        QueryBuilder<ParseObject>(ParseObject('Riege'))
          ..whereEqualTo('RiegenNr', riegenNummer);

    final ParseResponse response = await query.query();

    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      return holeRiegeVonDatabase(parseObject: response.results!.first);
    } else {
      log.i('Keine Riege gefunden mit der Nummer: $riegenNummer');
      return null;
    }
  }

  // Methode zum Laden einer Riege anhand deren Art aus der Datenbank
  Future<Riege?> loadRiegeFromDatabaseNachArt({required bool fuenfKampf}) async {
    final QueryBuilder<ParseObject> query =
        QueryBuilder<ParseObject>(ParseObject('Riege'))
          ..whereEqualTo('FuenfKampf', fuenfKampf);

    final ParseResponse response = await query.query();

    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      return holeRiegeVonDatabase(parseObject: response.results!.first);
    } else {
      log.i('Keine FuenfKampf-Riegen gefunden');
      return null;
    }
  }

  // NEU: Methode um alle Datensätze der Kind-Tabelle zu laden
  Future<List<Riege>> loadAllRiegen() async {
    final query = QueryBuilder<ParseObject>(ParseObject('Riege'));

    final response = await query.query();

    if (response.success && response.results != null) {
      return (response.results!
          .map(
              (parseObject) => holeRiegeVonDatabase(parseObject: parseObject as ParseObject))
          .toList());
    } else {
      return []; // Bei Fehler oder keinem Ergebnis beenden
    }
  }

  // NEU: Methode um alle Datensätze der Kind-Tabelle zu laden
  Future<List<Riege>> loadAllAuszuwertendeRiegen() async {
    // Filtert alle Fünfkampf-Riegen
    final queryFuenfkampf = QueryBuilder<ParseObject>(ParseObject('Riege'))
      ..whereEqualTo('FuenfKampf', true)
      ..whereEqualTo('AnzWettbewerbe', 5);
    // Filtert alle Zehnkampf-Riegen
    final queryZehnkampf = QueryBuilder<ParseObject>(ParseObject('Riege'))
      ..whereEqualTo('FuenfKampf', false)
      ..whereEqualTo('AnzWettbewerbe', 10);

    // Kombiniert die beiden Abfragen mit einem OR-Operator
    // und filtert alle noch nicht ausgewerteten Riegen
    final combinedQuery = QueryBuilder.or(
      ParseObject('Riege'),
      [queryFuenfkampf, queryZehnkampf],
    )..whereEqualTo('ausgewertet', false);

    final response = await combinedQuery.query();

    if (response.success && response.results != null) {
      return (response.results!
          .map(
              (parseObject) => holeRiegeVonDatabase(parseObject: parseObject as ParseObject))
          .toList());
    } else {
      return []; // Bei Fehler oder keinem Ergebnis beenden
    }
  }

  // NEU: Methode um alle Fünfkampf-Datensätze der Riegen-Tabelle zu laden
  Future<List<Riege>> loadAllRiegenNachArt(bool istFuenfKampf) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Riege'))
      ..whereEqualTo('FuenfKampf', istFuenfKampf);

    final response = await query.query();

    if (response.success && response.results != null) {
      return (response.results!
          .map(
              (parseObject) => holeRiegeVonDatabase(parseObject: parseObject as ParseObject))
          .toList());
    } else {
      return []; // Bei Fehler oder keinem Ergebnis beenden
    }
  }

  // NEU: Methode, um eine Liste von Riegen als Ganzes in die Datenbank zu speichern
  Future<void> saveRiegenListeToDatabase(List<Riege> riegenListe) async {
    for (var riege in riegenListe) {
      await saveRiegeToDatabase(riege: riege); // Verwendet die vorhandene Methode zum Speichern eines einzelnen Kindes
    }
  }

  // NEU: Methode, um für eine Riege die Art (Fünf- oder Zehnkampf) zu setzen und zu speichern
  Future<void> saveRiegeNachArt(
      {required int riegenNummer, required bool fuenfKampf}) async {
    final riege = await loadRiegeFromDatabase(riegenNummer: riegenNummer);
    if (riege != null) {
      riege.fuenfKampf = fuenfKampf;
      riege.anzStationen = 0; // Setze die Anzahl der Stationen auf 0
      await saveRiegeToDatabase(riege: riege);
    } else {
      log.i('Riege mit Nummer $riegenNummer nicht gefunden.');
    }
  }

  // NEU: Methode, um in einer Riege die Anzahl der Stationen zu erhöhen
  Future<void> erhoeheAnzahlStationenBeiRiege(
      {required int riegenNummer}) async {
    final riege = await loadRiegeFromDatabase(riegenNummer: riegenNummer);
    if (riege != null) {
      riege.anzStationen++;
      await saveRiegeToDatabase(riege: riege);
    } else {
      log.i('Riege mit Nummer $riegenNummer nicht gefunden.');
    }
  }
}
