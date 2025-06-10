import 'hilfs_widgets/meine_appbar.dart';
import 'tools/logger.util.dart';
import 'package:flutter/material.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/tools/kind_repository.dart';
import 'package:sporttag/src/tools/riegen_repository.dart';

//import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class RiegenEinteilung extends StatefulWidget {
  const RiegenEinteilung({super.key, required this.titel});
  final String? titel;

  /// Aktivität vorbereiten
  @override
  RiegenEinteilungState createState() => RiegenEinteilungState();
}

class RiegenEinteilungState extends State<RiegenEinteilung> {
  final KindRepository kindRepository = KindRepository(); // Repository-Objekt
  final RiegenRepository riegenRepository =
      RiegenRepository(); // Repository-Objekt für Riegen
  List<Kind> alleKinder = [];
  int kinderGesamt = 0;
  List<Kind> gefilterteKinder = [];
  final int riegenAnzahl = 8;
  List<List<Kind>> alleRiegen = [];
  int? ausgewaehlteRiegenNummer;
  Map<String, List<Kind>> jahrUgeschlechtMap =
      {}; // Geschlecht + Jahrgang als Key
  List<MapEntry<String, List<Kind>>> sortierteJahrUgeschlechtListen = [];
  final int aktuellesJahr = DateTime.now().year;

  // Logger einrichten
  final log = getLogger();

  @override
  initState() {
    super.initState();

    // Riegenlisten generieren
    alleRiegen = List.generate(riegenAnzahl, (index) => []);
    _kinderRiegenZuordnen();
  }

  Future<void> _kinderRiegenZuordnen() async {
    alleKinder = await kindRepository.loadAllKinder();
    kinderGesamt = alleKinder.length;
    setState(() {
      _generiereSortierteJahrgangsListen();
      _verteileKinderAufRiegen();
      _weiseKindernRiegennummerZu();
    });
    // Kinderliste mit aktualiserter Riegennummer speichern
    await kindRepository.saveKinderListeToDatabase(alleKinder);
  }

  void _generiereSortierteJahrgangsListen() {
    String key = "";
    // Gruppiere Kinder nach Jahrgang und Geschlecht
    for (var kind in alleKinder) {
      key = '${kind.jahrgang}_${kind.geschlecht}';
      if (!jahrUgeschlechtMap.containsKey(key)) {
        jahrUgeschlechtMap[key] = [];
      }
      jahrUgeschlechtMap[key]!.add(kind);
    }
    // Sortiere die Gruppen nach Jahrgängen und Geschlecht absteigend
    // in eine Liste von Map von Key und Kinderliste
    sortierteJahrUgeschlechtListen = (jahrUgeschlechtMap.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)));
  } // Ende _generierejahrUgeschlechtListen()

  void _verteileKinderAufRiegen() {
    // Maps für die zwei Gruppen ...
    List<MapEntry<String, List<Kind>>> kinderFuenfkampf = [];
    List<MapEntry<String, List<Kind>>> kinderZehnkampf = [];
    int anzKinderFuenfkampf = 0;

    // trenne die Kinderlisten in je eine Map von Fünf- bzw. Zehnkampf-Kinderliste
    // - die Kinder bis fünf Jahre --> Fünfkampf
    // - sechsjährige und älter --> Zehnkampf
    for (var jahrGeschlecht in sortierteJahrUgeschlechtListen) {
      // Der Jahrgang ist im ersten Teil des Schlüssels, z.B. '2021_M' -> '2021'
      String jahrgangStr = jahrGeschlecht.key.split('_')[0];
      int jahrgang = int.parse(jahrgangStr);
      // bestimme das Alter, welches das Kind in aktuellen Jahr erreicht
      int alter = aktuellesJahr - jahrgang;

      // Unterscheide die Altersgruppen und ...
      if (alter >= 3 && alter <= 5) {
        // ... weise sie der jeweiligen Liste zu
        kinderFuenfkampf.add(jahrGeschlecht);
        // zähle wieviel Fünfkämpfer bzw. ...
        anzKinderFuenfkampf += jahrGeschlecht.value.length;
      } else if (alter >= 6) {
        // ... weise sie der jeweiligen Liste zu
        kinderZehnkampf.add(jahrGeschlecht);
      }
    }
    // Anteil der Kinder für den Fünfkampf bestimmen und ...
    double anteilFuenfkampf = anzKinderFuenfkampf / kinderGesamt;
    // ... damit den Anteil an den 8 Riegen bestimmen
    int anzRiegenFuenfkampf = (riegenAnzahl * anteilFuenfkampf).round();
    // setze die Art der Riegen in der Datenbank
    for (int i = 0; i < riegenAnzahl; i++) {
      if (i < anzRiegenFuenfkampf) {
        // Fünfkampf-Riegen
        riegenRepository.saveRiegeNachArt(
          riegenNummer: i + 1,
          fuenfKampf: true,
        );
      } else {
        // Zehnkampf-Riegen
        riegenRepository.saveRiegeNachArt(
          riegenNummer: i + 1,
          fuenfKampf: false,
        );
      }
    }

    // Initialisiere leere Riegen
    List<List<Kind>> fuenfkampfRiegen =
        List.generate(anzRiegenFuenfkampf, (index) => []);
    List<List<Kind>> zehnkampfRiegen =
        List.generate((riegenAnzahl - anzRiegenFuenfkampf), (index) => []);

    // Kinderlisten, gruppiert nach Jahrgang und Geschlecht, den Fünfkampfriegen zuordnen
    // ... und zur Verteilung
    List<MapEntry<String, List<Kind>>> aktiveMap = kinderFuenfkampf;
    // sortiere die aktiveMap absteigend so,
    // dass die größte Gruppe mit gleichem Jahrgang und Geschlecht zuerst kommt
    aktiveMap.sort((mapEntryA, mapEntryB) =>
        mapEntryB.value.length.compareTo(mapEntryA.value.length));
    List<List<Kind>> riegen = fuenfkampfRiegen;
    List<Kind> amWenigstenGefuellteRiege;

    for (var jahrGeschlecht in aktiveMap) {
      var jahrGeschlechtKinder = jahrGeschlecht.value;
      // Finde die Riege mit den aktuell wenigsten Kindern (bei gleicher Anzahl eine davon)
      amWenigstenGefuellteRiege = riegen.reduce(
          (riege1, riege2) => riege1.length <= riege2.length ? riege1 : riege2);

      // Füge die gesamte Gruppe zu dieser Riege hinzu
      amWenigstenGefuellteRiege.addAll(jahrGeschlechtKinder);
    }
    // die Fünkampfriegen der Liste für alle Riegen hinzufügen
    alleRiegen = riegen;

    // Kinderlisten den Zehnkampfriegen zuordnen
    aktiveMap = kinderZehnkampf;
    // sortiere die aktiveMap absteigend so,
    // dass die größte Gruppe mit gleichem Jahrgang und Geschlecht zuerst kommt
    aktiveMap.sort((mapEntryA, mapEntryB) =>
        mapEntryB.value.length.compareTo(mapEntryA.value.length));
    riegen = zehnkampfRiegen;
    for (var jahrGeschlecht in aktiveMap) {
      var jahrGeschlechtKinder = jahrGeschlecht.value;

      // Finde die Riege mit den wenigsten Kindern
      amWenigstenGefuellteRiege = riegen.reduce(
          (riege1, riege2) => riege1.length <= riege2.length ? riege1 : riege2);

      // Füge die gesamte Gruppe zu dieser Riege hinzu
      amWenigstenGefuellteRiege.addAll(jahrGeschlechtKinder);
    }
    // die resultierenden Zehnkampfriegen an 'alleRiegen'-anhängen
    for (int i = 0; i < (riegenAnzahl - anzRiegenFuenfkampf); i++) {
      alleRiegen.add(riegen[i]);
    }

    // Ausgabe der Verteilung (optional)
    for (int i = 0; i < alleRiegen.length; i++) {
      log.i('sortierte Riege ${i + 1}: ${alleRiegen[i].length} Kinder');
      for (var kind in alleRiegen[i]) {
        log.i(
            'sortierte Riege:  ${kind.vorname} ${kind.nachname}, Jahrgang ${kind.jahrgang}, Geschlecht ${kind.geschlecht}');
      }
    }
  }

  void _weiseKindernRiegennummerZu() {
    int i = 1; // erste Riege aht Index 0 aber die Nummer 1
    for (var riege in alleRiegen) {
      log.i('sortierte Riege Nr: $i mit ${riege.length} Kindern');
      int j = 1;
      for (var kind in riege) {
        kind.riegenNummer = i;
        log.i('sortiertes Kind ${kind.jahrgang} Nr. $j in Riege $i');
        j++;
      }
      i++;
    }
  }

  // Methode für die Anzeige der einzelnen Riege
  void _filterKinderNachRiege(int riegenNummer) {
    setState(() {
      gefilterteKinder = alleKinder
          .where((kind) => kind.riegenNummer == riegenNummer)
          .toList()
        // sortiert die Kinder nach Geschlecht unnerhalb des gleichen Jahrgangs
        ..sort((a, b) {
          int jahrgangsVergleich = b.jahrgang.compareTo(a.jahrgang);
          if (jahrgangsVergleich != 0) {
            // gleicher Jahrgang
            return jahrgangsVergleich;
          }
          return b.geschlecht.compareTo(a.geschlecht);
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(titel: widget.titel ?? 'Riegen Einteilung'),
      body: Center(
        child: Column(
          children: [
            // Dropdown zur Auswahl der Riegennummer
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButton<int>(
                hint: const Text('Wähle eine Riege'),
                value: ausgewaehlteRiegenNummer,
                items: List.generate(riegenAnzahl, (index) => index + 1)
                    .map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('Riege $value'),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    ausgewaehlteRiegenNummer = newValue;
                  });
                  if (newValue != null) {
                    _filterKinderNachRiege(newValue);
                  }
                },
              ),
            ),
            // Liste der Kinder in der ausgewählten Riege
            Expanded(
              child: ListView.builder(
                itemCount: gefilterteKinder.length,
                itemBuilder: (context, index) {
                  final kind = gefilterteKinder[index];
                  return ListTile(
                    title: Text(
                        '${kind.vorname} ${kind.nachname} ${kind.jahrgang} ${kind.geschlecht}'),
                    //subtitle: Text('Geschlecht: ${kind.geschlecht}'),
                  );
                },
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                "Riegeneinteilung abschließen",
                style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
