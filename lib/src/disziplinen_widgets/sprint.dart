import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/mein_listen_eintrag.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/station_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/tools/kind_repository.dart';
import 'package:sporttag/src/tools/logger.util.dart';
import 'package:sporttag/src/tools/station_repository.dart';
import 'package:sporttag/src/tools/stop_uhr.dart';

class Sprint extends StatefulWidget {
  final Riege riegenPointer;

  const Sprint({super.key, required this.riegenPointer});

  /// Aktivität vorbereiten
  @override
  SprintState createState() => SprintState();
}

class SprintState extends State<Sprint> {
  late String stationsName; // Variable für die zugewiesene Ausgabe

  // Repository-Objekte
  final KindRepository kindRepository = KindRepository();
  final StationRepository stationRepository = StationRepository();
  bool testLauf = true; // Kinder dürfen zuerst ihre Entscheidung testen

  late Riege riegenPointer;
  List<Kind> riegenKinder = [];
  List<Kind> selectedKinder = [];
  List<Kind> kinderZurAnzeige = []; // Speichert anzuzeigende Teilnehmer
  Set<Kind> ausgewerteteKinder = {}; // Speichert ausgewertete Teilnehmer
  Map<Kind, int> kinderMitZeiten = {}; // Speichert gestoppte Zeiten
  Map<Kind, int> gewaehlteHuetchen =
      {}; // Speichert die gewählte Hütchen-Nummer
  Station? station; // Speichert die Station
  
  final log = getLogger();

  @override
  initState() {
    super.initState();
    // widget.toString() der Variable zuweisen
    stationsName = "Sprint";
    riegenPointer = widget.riegenPointer;
    _loadData();
  }

  Future<void> _loadData() async {
    riegenKinder =
        await kindRepository.ladeKinderDerRiege(riege: riegenPointer);
    station = await stationRepository.ladeStationNachName(stationsName: stationsName);
    // Liste zur Anzeige aufbereiten -> nicht ausgewertete Kinder oben
    kinderZurAnzeige = kindRepository.zurAnzeigeSortieren(
        alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
    setState(() {}); // UI aktualisieren
  }

  Future<void> auswerten(Map<Kind, int> resultate) async {
    log.i(
        'in auswerten -> Ergebniss erstes Kind: ${resultate.values.first.toString()}');
    // Auswertung zulassen, falls der Testlauf beendet ist
    if (!testLauf) {
      setState(() async {
        kinderMitZeiten.addAll(resultate); // Gestoppte Zeiten hinzufügen
        // Gestoppte Zeiten hinzufügen und Punkte berechnen
        for (var entry in resultate.entries) {
          final kind = entry.key;
          final zeit = entry.value;

          kinderMitZeiten[kind] = zeit; // Zeit speichern
          // die eingestellten Hütchen werden als Punkt vergeben, wenn die Zeit > 0 ist
          final punkte = _werteZeitenAus(zeit, kind);
          // die an dieser Station erreichten Punkte werden gespeichert
          kinderMitZeiten[kind] = punkte;
          log.i('in auswerten $zeit für ${kind.nachname}');
        //kind.erreichtePunkte += punkte; // Punkte zuweisen
        await kindRepository.speichereResultat(kind: kind, station: station!, punkte: punkte);
        }

        // Teilnehmer als ausgewertet markieren
        ausgewerteteKinder.addAll(resultate.keys);

        // Auswahl nach der Auswertung zurücksetzen
        selectedKinder.clear();

        // Liste zur Anzeige aufbereiten -> nicht ausgewertete Kinder oben
        kinderZurAnzeige = kindRepository.zurAnzeigeSortieren(
            alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
      });

      // Speichern der ausgewerteten Kinder in der Datenbank
      final zuSpeicherndeKinder = resultate.keys.toList();
      for (var dasKind in zuSpeicherndeKinder) {
        await kindRepository.saveKind(kind: dasKind);
      }
    }
  }

  int _werteZeitenAus(int zeitInMillis, Kind kind) {
    int punkte;
    zeitInMillis > 0
        ? punkte = gewaehlteHuetchen[kind] ?? 0
        : punkte =
            0; // Wenn 'kind' nicht in der Map enthalten ist, dann 0 zurückgeben
    // Punkte werden aufrund der erreichten Zeit berechnet
    return punkte;
  }

  bool alleHuetchenGewaehlt() {
    return selectedKinder.every((kind) => gewaehlteHuetchen[kind] != null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(
        titel: stationsName,
        stationsName: stationsName,
      ),
      body: Center(
        child: Column(
          children: [
            Text(
              'Die Kinder führen nach Wahl der Hütchen einen Probedurchgang durch. \nDanach kann die Hütchenwahl geändert werden.\nBitte selektieren Sie die an der nächsten Runde teilnehmenden Kinder,\nwählen Sie die gewünschten Hütchen aus.',
              textAlign: TextAlign.center,
              style:
                  Theme.of(context).textTheme.bodySmall, // Verwenden des Themes
            ),
            // Abstandshalter
            const SizedBox(height: 10),
            // Liste der Kinder in der ausgewählten Riege
            ElevatedButton(
              onPressed: (selectedKinder.isNotEmpty)
                  // Wenn selektierte Kinder vorhanden sind, dann die StopUhr aufrufen
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyStopUhr(
                            teilNehmer: selectedKinder,
                            rufendeStation: stationsName,
                            auswertenDerWerte:
                                auswerten, // Ergebnisse verarbeiten)
                          ),
                        ),
                      ).then((_) {
                        setState(() {
                          testLauf = !testLauf; // Jetzt toggeln
                        });
                      });
                    }
                  : null,
              child: Text(
                testLauf
                    ? 'Testlauf mit ausgewählten Namen'
                    : 'Wertungslauf mit ausgewählten Namen',
                textAlign: TextAlign.center,
              ),
            ),
            // Zeigt die Liste der Kinder
            Expanded(
              child: ListView.builder(
                // Anzahl der Einträge in der Liste
                itemCount: riegenKinder.length,
                // Die einzelnen Einträge werden definiert
                itemBuilder: (context, index) {
                  final kind = kinderZurAnzeige[index];
                  final zeit = kinderMitZeiten[kind]; // Gestoppte Zeit abrufen
                  final istAusgewertet = ausgewerteteKinder.contains(kind);
                  final istSelektiert = selectedKinder.contains(kind);
                  // der Listeneintrag wird erstellt
                  return Row(
                    mainAxisAlignment: MainAxisAlignment
                        .spaceBetween, // Platzierung der Widgets
                    children: [
                      // erster Eintrag in der Zeile: Kind mit Zusatzangaben
                      Expanded(
                        flex: 3, // 3 Teile für den Listeneintrag
                        child: MeinListenEintrag(
                          kind: kind,
                          istAusgewertet: istAusgewertet,
                          istSelektiert: istSelektiert,
                          erreichtePunkte: zeit,
                          onSelectionChanged: (Kind kind, bool istSelektiert) {
                            setState(() {
                              if (istSelektiert) {
                                selectedKinder.add(kind);
                                gewaehlteHuetchen.putIfAbsent(kind, () => 1);
                              } else {
                                selectedKinder.remove(kind);
                                gewaehlteHuetchen.remove(kind);
                              }
                            });
                          },
                        ),
                      ),
                      // zweiter Eintrag in der Zeile: DropDown für Auswahl der Hütchen
                      if (istSelektiert &&
                          !istAusgewertet) // Dropdown nur anzeigen, wenn Kind selektiert und nicht ausgewertet
                        Expanded(
                          flex: 1, // 1 Teil für das Dropdown-Menü
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10.0),
                            child: DropdownButton<int>(
                              value: gewaehlteHuetchen[kind],
                              items: [1, 2, 3, 4].map((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('Hütchen $value'),
                                );
                              }).toList(),
                              onChanged: (int? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    gewaehlteHuetchen[kind] = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                    ],
                  );
                }, // Ende itemBuilder
              ),
            ),
            // Unterhalb der Liste wird der Beenden-Button angezeigt,
            // wenn alle Kinder in der Liste die Station absolviert haben
            if (riegenKinder.length ==
                ausgewerteteKinder.length) // Beenden-Button anzeigen
              // wenn alle Kinder ausgewertet sind wird
              // zur Disziplinen-Übersicht weitergeleitet und zuvor
              // die Anzahl der absolvierten Disziplinen für die aktuelle Riege erhöht
              ZurueckButton(
                label: 'Nächste Disziplin steht an',
                riegenPointer: riegenPointer,
                stationsPointer: station,
              ),
          ],
        ),
      ),
    );
  }
}
