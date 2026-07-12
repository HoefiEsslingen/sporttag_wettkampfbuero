// import 'dart:convert';
// import 'package:flutter/services.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

enum RouteEntscheidung { vorabAnmeldung, wettkampfbuero }
class SporttagConfig {
  final String name;
  final DateTime datum;
  final String uhrzeit;
  final String ort;
  final double gebuehr;
  final DateTime anmeldungBis;
  final int kindAlterMin; // Mindestalter für die Anmeldung
  final int kindAlterMax; // Maximalalter für die Anmeldung
  final int fuenfkampfMaxAlter; // Maximalalter für den Fünfkampf

  SporttagConfig._({
    required this.name,
    required this.datum,
    required this.uhrzeit,
    required this.ort,
    required this.gebuehr,
    required this.anmeldungBis,
    required this.kindAlterMin,
    required this.kindAlterMax,
    required this.fuenfkampfMaxAlter,
  });

  static Future<SporttagConfig> laden() async {
  final query = QueryBuilder<ParseObject>(ParseObject('AppSetting'));
  final response = await query.query();

   if (!response.success ||
      response.results == null ||
      response.results!.isEmpty) {
    throw Exception('Konfiguration nicht ladbar.');
  }

   // Einziger Datensatz (ein Objekt enthält alle Felder)
  final obj = response.results!.first as ParseObject;

  return SporttagConfig._(
    // Date-Typ: get<DateTime> statt String-Parsing
    anmeldungBis: obj.get<DateTime>('AnmeldeDatum')  ?? DateTime.now(),
    datum:        obj.get<DateTime>('VeranstaltungsZeit') ?? DateTime.now(),
    // String-Typ: direkt lesbar
    ort:          obj.get<String>('Ort')     ?? '',
    // Number-Typ: als num lesen, dann nach double konvertieren
    gebuehr:      (obj.get<num>('Gebuehr')   ?? 0).toDouble(),
    // Kein 'name'-Feld in Back4App → Fallback-Wert
    name:         'Sporttag',
    // Uhrzeit aus VeranstaltungsZeit extrahieren
    uhrzeit:
        '${obj.get<DateTime>('VeranstaltungsZeit')?.hour.toString().padLeft(2, '0')}:'
        '${obj.get<DateTime>('VeranstaltungsZeit')?.minute.toString().padLeft(2, '0')}',
    kindAlterMin: (obj.get<num>('MinAlterKind')   ?? 0).toInt(),
    kindAlterMax: (obj.get<num>('MaxAlterKind')   ?? 0).toInt(),
    fuenfkampfMaxAlter: (obj.get<num>('MaxAlterFuenfkampf') ?? 0).toInt(),
  );
}

  /// Entscheidet anhand des aktuellen Datums welche Seite gezeigt wird:
  ///   - Vor  'anmeldung_bis' → Vorab-Anmeldung
  ///   - Ab   'anmeldung_bis' bis Veranstaltungsdatum → Wettkampfbüro
  ///   - Nach Veranstaltungsdatum → Auswertung 
  RouteEntscheidung routeEntscheiden() {
    final heute = DateTime.now();
    final tagHeute = DateTime(heute.year, heute.month, heute.day, heute.hour, heute.minute);
    final tagAnmeldungBis = DateTime(
      anmeldungBis.year, anmeldungBis.month, anmeldungBis.day,18,0
    );

    if (tagHeute.isAfter(tagAnmeldungBis)) {
      return RouteEntscheidung.wettkampfbuero;
    } else {
      return RouteEntscheidung.vorabAnmeldung;
    }
  }
}