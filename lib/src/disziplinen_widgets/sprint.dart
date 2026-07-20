import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/mein_listen_eintrag.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/meine_karten_eintrag.dart';
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
  // NEU: signalisiert, wann eine laufende Auswertung (Wertungslauf) fertig ist
  Completer<void>? _auswertungAbgeschlossen;

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
    station =
        await stationRepository.ladeStationNachName(stationsName: stationsName);
    // // Liste zur Anzeige aufbereiten -> nicht ausgewertete Kinder oben
    // kinderZurAnzeige = kindRepository.zurAnzeigeSortieren(
    //     alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
    setState(() {
      // Liste zur Anzeige aufbereiten -> nicht ausgewertete Kinder oben
      kinderZurAnzeige = kindRepository.zurAnzeigeSortieren(
          alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
    }); // UI aktualisieren
  }

  /// Liefert die Kinder, die aktuell in der Liste angezeigt werden sollen.
  /// - Vor dem Testlauf (testLauf == true): alle Kinder der Riege
  ///   (bereits ausgewertete Kinder stehen dank zurAnzeigeSortieren hinten).
  /// - Nach dem Testlauf, bis der Wertungslauf abgeschlossen ist
  ///   (testLauf == false): nur die für diesen Wettbewerb ausgewählten
  ///   Kinder – die Teilnahme steht fest, nur die Hütchen-Wahl darf noch
  ///   geändert werden.
  List<Kind> get _kinderFuerAnzeige {
    if (testLauf) {
      return kinderZurAnzeige;
    }
    return kinderZurAnzeige
        .where((kind) => selectedKinder.contains(kind))
        .toList();
  }

  Future<void> auswerten(Map<Kind, int> resultate) async {
    log.i(
        'in auswerten -> Ergebniss erstes Kind: ${resultate.values.first.toString()}');

    // Auswertung nur zulassen, falls der Testlauf beendet ist
    if (testLauf) return;

    // NEU: Completer anlegen, BEVOR die erste await-Stelle erreicht wird.
    // Da diese Methode synchron bis zum ersten "await" ausgeführt wird,
    // existiert der Completer garantiert schon, wenn der Aufrufer
    // (StopUhr / Navigator.pop) weiterläuft.
    _auswertungAbgeschlossen = Completer<void>();

    try {
      // 1. Punkte berechnen (synchron)
      final Map<Kind, int> punkteProKind = {
        for (final entry in resultate.entries)
          entry.key: _werteZeitenAus(entry.value, entry.key)
      };

      // 2. Punkte in der Datenbank speichern (asynchron, außerhalb von setState)
      for (final entry in punkteProKind.entries) {
        log.i('in auswerten ${entry.value} für ${entry.key.nachname}');
        await kindRepository.speichereResultat(
            kind: entry.key, station: station!, punkte: entry.value);
      }

      // 3. State synchron aktualisieren -> löst Rebuild aus
      if (!mounted) return;
      setState(() {
        kinderMitZeiten.addAll(punkteProKind);
        ausgewerteteKinder.addAll(resultate.keys);
        selectedKinder.clear();
        kinderZurAnzeige = kindRepository.zurAnzeigeSortieren(
            alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
      });

      // 4. Kind-Objekte abschließend speichern
      for (final kind in resultate.keys) {
        await kindRepository.saveKind(kind: kind);
      }
    } finally {
      // NEU: Signal geben, dass die Auswertung (inkl. setState) abgeschlossen ist
      _auswertungAbgeschlossen?.complete();
    }
  }

  int _werteZeitenAus(int zeitInMillis, Kind kind) {
    int punkte;
    zeitInMillis > 0
        ? punkte = gewaehlteHuetchen[kind] ?? 0
        : punkte =
            0; // Wenn 'kind' nicht in der Map enthalten ist, dann 0 zurückgeben
    // Punkte werden aufgrund der erreichten Zeit berechnet
    return punkte;
  }

  bool alleHuetchenGewaehlt() {
    return selectedKinder.every((kind) => gewaehlteHuetchen[kind] != null);
  }

  @override
  Widget build(BuildContext context) {
    // PopScope verhindert den Rücksprung über den Browser-/System-Zurück-Button,
    // solange die Station aktiv ist.
    return PopScope(
      canPop: false,
      child: Scaffold(
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
                style: Theme.of(context)
                    .textTheme
                    .bodySmall, // Verwenden des Themes
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
                        ).then((_) async {
                          // NEU: Falls eine Auswertung (Wertungslauf) läuft, erst darauf
                          // warten, dass sie inkl. setState() fertig ist – sonst toggelt
                          // testLauf zu früh und die Liste zeigt den alten Stand.
                          if (_auswertungAbgeschlossen != null) {
                            await _auswertungAbgeschlossen!.future;
                            _auswertungAbgeschlossen =
                                null; // für nächsten Durchlauf zurücksetzen
                          }
                          if (!mounted) return;
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
              // Zeigt die Liste der Kinder als Karten
              Expanded(
                child: ListView.builder(
                  itemCount: _kinderFuerAnzeige
                      .length, // NEU: statt riegenKinder.length
                  itemBuilder: (context, index) {
                    final kind = _kinderFuerAnzeige[
                        index]; // NEU: statt kinderZurAnzeige[index]
                    final zeit = kinderMitZeiten[kind];
                    final istAusgewertet = ausgewerteteKinder.contains(kind);
                    final istSelektiert = selectedKinder.contains(kind);

                    return MeinKartenEintrag(
                      istSelektiert: istSelektiert,
                      istAusgewertet: istAusgewertet,
                      trailing: (istSelektiert && !istAusgewertet)
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
                              child: DropdownButton<int>(
                                value: gewaehlteHuetchen[kind],
                                items: [1, 2, 3, 4]
                                    .map((v) => DropdownMenuItem(
                                        value: v, child: Text('Hütchen $v')))
                                    .toList(),
                                onChanged: (newValue) {
                                  // Hütchen-Wahl bleibt in beiden Phasen änderbar
                                  if (newValue != null) {
                                    setState(() =>
                                        gewaehlteHuetchen[kind] = newValue);
                                  }
                                },
                              ),
                            )
                          : null,
                      child: MeinListenEintrag(
                        kind: kind,
                        istAusgewertet: istAusgewertet,
                        istSelektiert: istSelektiert,
                        erreichtePunkte: zeit,
                        onSelectionChanged: (Kind kind, bool istSelektiert) {
                          // NEU: Nach dem Testlauf steht die Teilnehmerliste fest –
                          // die Auswahl darf dann nicht mehr verändert werden,
                          // nur noch die Hütchen-Wahl (siehe Dropdown unten).
                          if (!testLauf) return;

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
                    );
                  },
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
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:sporttag/src/hilfs_widgets/mein_listen_eintrag.dart';
// import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
// import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
// import 'package:sporttag/src/klassen/kind_klasse.dart';
// import 'package:sporttag/src/klassen/station_klasse.dart';
// import 'package:sporttag/src/klassen/riegen_klasse.dart';
// import 'package:sporttag/src/tools/kind_repository.dart';
// import 'package:sporttag/src/tools/logger.util.dart';
// import 'package:sporttag/src/tools/station_repository.dart';
// import 'package:sporttag/src/tools/stop_uhr.dart';

// class Sprint extends StatefulWidget {
//   final Riege riegenPointer;

//   const Sprint({super.key, required this.riegenPointer});

//   /// Aktivität vorbereiten
//   @override
//   SprintState createState() => SprintState();
// }

// class SprintState extends State<Sprint> {
//   late String stationsName; // Variable für die zugewiesene Ausgabe

//   // Repository-Objekte
//   final KindRepository kindRepository = KindRepository();
//   final StationRepository stationRepository = StationRepository();
//   bool testLauf = true; // Kinder dürfen zuerst ihre Entscheidung testen

//   late Riege riegenPointer;
//   List<Kind> riegenKinder = [];
//   List<Kind> selectedKinder = [];
//   List<Kind> kinderZurAnzeige = []; // Speichert anzuzeigende Teilnehmer
//   Set<Kind> ausgewerteteKinder = {}; // Speichert ausgewertete Teilnehmer
//   Map<Kind, int> kinderMitZeiten = {}; // Speichert gestoppte Zeiten
//   Map<Kind, int> gewaehlteHuetchen =
//       {}; // Speichert die gewählte Hütchen-Nummer
//   Station? station; // Speichert die Station

//   final log = getLogger();

//   @override
//   initState() {
//     super.initState();
//     // widget.toString() der Variable zuweisen
//     stationsName = "Sprint";
//     riegenPointer = widget.riegenPointer;
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     riegenKinder =
//         await kindRepository.ladeKinderDerRiege(riege: riegenPointer);
//     station = await stationRepository.ladeStationNachName(stationsName: stationsName);
//     // Liste zur Anzeige aufbereiten -> nicht ausgewertete Kinder oben
//     kinderZurAnzeige = kindRepository.zurAnzeigeSortieren(
//         alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
//     setState(() {}); // UI aktualisieren
//   }

//   Future<void> auswerten(Map<Kind, int> resultate) async {
//     log.i(
//         'in auswerten -> Ergebniss erstes Kind: ${resultate.values.first.toString()}');
//     // Auswertung zulassen, falls der Testlauf beendet ist
//     if (!testLauf) {
//       setState(() async {
//         kinderMitZeiten.addAll(resultate); // Gestoppte Zeiten hinzufügen
//         // Gestoppte Zeiten hinzufügen und Punkte berechnen
//         for (var entry in resultate.entries) {
//           final kind = entry.key;
//           final zeit = entry.value;

//           kinderMitZeiten[kind] = zeit; // Zeit speichern
//           // die eingestellten Hütchen werden als Punkt vergeben, wenn die Zeit > 0 ist
//           final punkte = _werteZeitenAus(zeit, kind);
//           // die an dieser Station erreichten Punkte werden gespeichert
//           kinderMitZeiten[kind] = punkte;
//           log.i('in auswerten $zeit für ${kind.nachname}');
//         //kind.erreichtePunkte += punkte; // Punkte zuweisen
//         await kindRepository.speichereResultat(kind: kind, station: station!, punkte: punkte);
//         }

//         // Teilnehmer als ausgewertet markieren
//         ausgewerteteKinder.addAll(resultate.keys);

//         // Auswahl nach der Auswertung zurücksetzen
//         selectedKinder.clear();

//         // Liste zur Anzeige aufbereiten -> nicht ausgewertete Kinder oben
//         kinderZurAnzeige = kindRepository.zurAnzeigeSortieren(
//             alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
//       });

//       // Speichern der ausgewerteten Kinder in der Datenbank
//       final zuSpeicherndeKinder = resultate.keys.toList();
//       for (var dasKind in zuSpeicherndeKinder) {
//         await kindRepository.saveKind(kind: dasKind);
//       }
//     }
//   }

//   int _werteZeitenAus(int zeitInMillis, Kind kind) {
//     int punkte;
//     zeitInMillis > 0
//         ? punkte = gewaehlteHuetchen[kind] ?? 0
//         : punkte =
//             0; // Wenn 'kind' nicht in der Map enthalten ist, dann 0 zurückgeben
//     // Punkte werden aufrund der erreichten Zeit berechnet
//     return punkte;
//   }

//   bool alleHuetchenGewaehlt() {
//     return selectedKinder.every((kind) => gewaehlteHuetchen[kind] != null);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: MeineAppBar(
//         titel: stationsName,
//         stationsName: stationsName,
//       ),
//       body: Center(
//         child: Column(
//           children: [
//             Text(
//               'Die Kinder führen nach Wahl der Hütchen einen Probedurchgang durch. \nDanach kann die Hütchenwahl geändert werden.\nBitte selektieren Sie die an der nächsten Runde teilnehmenden Kinder,\nwählen Sie die gewünschten Hütchen aus.',
//               textAlign: TextAlign.center,
//               style:
//                   Theme.of(context).textTheme.bodySmall, // Verwenden des Themes
//             ),
//             // Abstandshalter
//             const SizedBox(height: 10),
//             // Liste der Kinder in der ausgewählten Riege
//             ElevatedButton(
//               onPressed: (selectedKinder.isNotEmpty)
//                   // Wenn selektierte Kinder vorhanden sind, dann die StopUhr aufrufen
//                   ? () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => MyStopUhr(
//                             teilNehmer: selectedKinder,
//                             rufendeStation: stationsName,
//                             auswertenDerWerte:
//                                 auswerten, // Ergebnisse verarbeiten)
//                           ),
//                         ),
//                       ).then((_) {
//                         setState(() {
//                           testLauf = !testLauf; // Jetzt toggeln
//                         });
//                       });
//                     }
//                   : null,
//               child: Text(
//                 testLauf
//                     ? 'Testlauf mit ausgewählten Namen'
//                     : 'Wertungslauf mit ausgewählten Namen',
//                 textAlign: TextAlign.center,
//               ),
//             ),
//             // Zeigt die Liste der Kinder
//             Expanded(
//               child: ListView.builder(
//                 // Anzahl der Einträge in der Liste
//                 itemCount: riegenKinder.length,
//                 // Die einzelnen Einträge werden definiert
//                 itemBuilder: (context, index) {
//                   final kind = kinderZurAnzeige[index];
//                   final zeit = kinderMitZeiten[kind]; // Gestoppte Zeit abrufen
//                   final istAusgewertet = ausgewerteteKinder.contains(kind);
//                   final istSelektiert = selectedKinder.contains(kind);
//                   // der Listeneintrag wird erstellt
//                   return Row(
//                     mainAxisAlignment: MainAxisAlignment
//                         .spaceBetween, // Platzierung der Widgets
//                     children: [
//                       // erster Eintrag in der Zeile: Kind mit Zusatzangaben
//                       Expanded(
//                         flex: 3, // 3 Teile für den Listeneintrag
//                         child: MeinListenEintrag(
//                           kind: kind,
//                           istAusgewertet: istAusgewertet,
//                           istSelektiert: istSelektiert,
//                           erreichtePunkte: zeit,
//                           onSelectionChanged: (Kind kind, bool istSelektiert) {
//                             setState(() {
//                               if (istSelektiert) {
//                                 selectedKinder.add(kind);
//                                 gewaehlteHuetchen.putIfAbsent(kind, () => 1);
//                               } else {
//                                 selectedKinder.remove(kind);
//                                 gewaehlteHuetchen.remove(kind);
//                               }
//                             });
//                           },
//                         ),
//                       ),
//                       // zweiter Eintrag in der Zeile: DropDown für Auswahl der Hütchen
//                       if (istSelektiert &&
//                           !istAusgewertet) // Dropdown nur anzeigen, wenn Kind selektiert und nicht ausgewertet
//                         Expanded(
//                           flex: 1, // 1 Teil für das Dropdown-Menü
//                           child: Padding(
//                             padding:
//                                 const EdgeInsets.symmetric(horizontal: 10.0),
//                             child: DropdownButton<int>(
//                               value: gewaehlteHuetchen[kind],
//                               items: [1, 2, 3, 4].map((int value) {
//                                 return DropdownMenuItem<int>(
//                                   value: value,
//                                   child: Text('Hütchen $value'),
//                                 );
//                               }).toList(),
//                               onChanged: (int? newValue) {
//                                 if (newValue != null) {
//                                   setState(() {
//                                     gewaehlteHuetchen[kind] = newValue;
//                                   });
//                                 }
//                               },
//                             ),
//                           ),
//                         ),
//                     ],
//                   );
//                 }, // Ende itemBuilder
//               ),
//             ),
//             // Unterhalb der Liste wird der Beenden-Button angezeigt,
//             // wenn alle Kinder in der Liste die Station absolviert haben
//             if (riegenKinder.length ==
//                 ausgewerteteKinder.length) // Beenden-Button anzeigen
//               // wenn alle Kinder ausgewertet sind wird
//               // zur Disziplinen-Übersicht weitergeleitet und zuvor
//               // die Anzahl der absolvierten Disziplinen für die aktuelle Riege erhöht
//               ZurueckButton(
//                 label: 'Nächste Disziplin steht an',
//                 riegenPointer: riegenPointer,
//                 stationsPointer: station,
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
