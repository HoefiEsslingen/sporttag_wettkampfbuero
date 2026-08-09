import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/mein_karten_eintrag.dart';
import 'package:sporttag/src/hilfs_widgets/mein_listen_eintrag.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';
import 'package:sporttag/src/mixins/stop_uhr_auswertung_mixin.dart';
import 'package:sporttag/src/tools/stop_uhr.dart';

class Sprint extends StatefulWidget {
  final Riege riegenPointer;

  const Sprint({super.key, required this.riegenPointer});

  @override
  SprintState createState() => SprintState();
}

class SprintState extends State<Sprint>
    with StationenBasisMixin<Sprint>, StopUhrAuswertungMixin<Sprint> {
  // Sprint-spezifisch: gewählte Hütchen-Nummer pro Kind
  Map<Kind, int> gewaehlteHuetchen = {};

  @override
  void initState() {
    super.initState();
    stationsName = 'Sprint';
    riegenPointer = widget.riegenPointer;
    testLauf = true; // Sprint ist zweiphasig: erst Testlauf, dann Wertung
    ladeStationsdaten();
  }

  @override
  void dispose() {
    resetStationsdaten();
    gewaehlteHuetchen.clear();
    super.dispose();
  }

  /// Stationsspezifische Formel: die gewählte Hütchen-Nummer ist die
  /// Punktzahl, sofern überhaupt eine Zeit gestoppt wurde.
  @override
  int berechnePunkte(int zeitInMillis, Kind kind) {
    return zeitInMillis > 0 ? (gewaehlteHuetchen[kind] ?? 0) : 0;
  }

  /// Nach abgeschlossenem Wertungslauf zurück in die Testlauf-Phase
  /// wechseln (Button-Reset). Läuft im SELBEN setState()-Aufruf wie die
  /// übrigen Änderungen in stopUhrAuswerten() -> kein separater,
  /// zeitlich versetzter Rebuild, der einen falschen Zwischenzustand
  /// zeigen könnte.
  @override
  void nachAuswertungHook() {
    testLauf = true;
  }

  /// Liefert die Kinder, die aktuell in der Liste angezeigt werden sollen.
  /// - Testlauf: alle Kinder der Riege.
  /// - Wertungslauf: nur die zuvor ausgewählten Kinder (Teilnahme steht
  ///   fest, nur die Hütchen-Wahl darf noch geändert werden).
  List<Kind> get _kinderFuerAnzeige {
    if (testLauf) return kinderZurAnzeige;
    return kinderZurAnzeige
        .where((kind) => selectedKinder.contains(kind))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: MeineAppBar(titel: stationsName, stationsName: stationsName),
        body: Center(
          child: Column(
            children: [
              Text(
                'Die Kinder führen nach Wahl der Hütchen einen Probedurchgang durch. \nDanach kann die Hütchenwahl geändert werden.\nBitte selektieren Sie die an der nächsten Runde teilnehmenden Kinder,\nwählen Sie die gewünschten Hütchen aus.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: (selectedKinder.isNotEmpty && !wertungWirdVerarbeitet)
                    ? () => starteStopUhr(
                          context,
                          builder: (context) => MyStopUhr(
                            teilNehmer: selectedKinder,
                            rufendeStation: stationsName,
                            auswertenDerWerte: stopUhrAuswerten,
                          ),
                        )
                    : null,
                child: wertungWirdVerarbeitet
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        testLauf
                            ? 'Testlauf mit ausgewählten Namen'
                            : 'Wertungslauf mit ausgewählten Namen',
                        textAlign: TextAlign.center,
                      ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _kinderFuerAnzeige.length,
                  itemBuilder: (context, index) {
                    final kind = _kinderFuerAnzeige[index];
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
                          // Nach dem Testlauf steht die Teilnehmerliste fest.
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
              if (riegenKinder.length == ausgewerteteKinder.length)
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


// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:sporttag/src/hilfs_widgets/mein_listen_eintrag.dart';
// import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
// import 'package:sporttag/src/hilfs_widgets/mein_karten_eintrag.dart';
// import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
// import 'package:sporttag/src/klassen/kind_klasse.dart';
// import 'package:sporttag/src/klassen/station_klasse.dart';
// import 'package:sporttag/src/klassen/riegen_klasse.dart';
// import 'package:sporttag/src/repositories/kind_repository.dart';
// import 'package:sporttag/src/repositories/riegen_repository.dart';
// import 'package:sporttag/src/tools/logger.util.dart';
// import 'package:sporttag/src/repositories/station_repository.dart';
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
//   final RiegenRepository riegenRepository = RiegenRepository();
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
//   // NEU: signalisiert, wann eine laufende Auswertung (Wertungslauf) fertig ist
//   Completer<void>? _auswertungAbgeschlossen;

//   final log = getLogger();

//   @override
//   initState() {
//     super.initState();
//     // widget.toString() der Variable zuweisen
//     stationsName = "Sprint";
//     riegenPointer = widget.riegenPointer;
//     _loadData();
//   }

// Future<void> _loadData() async {
//   // 1. Kinder der Riege + Station laden
//   riegenKinder = await kindRepository.ladeKinderDerRiege(riege: riegenPointer);
//   station = await stationRepository.ladeStationNachName(
//       stationsName: stationsName);

//   // 2. Exakter Check: wurde GENAU diese Station ("Sprint") für diese Riege
//   //    laut riegenLogging bereits abgeschlossen? Relevant z.B. nach einem
//   //    Abbruch/Neustart der Web-App mitten im Wettkampf.
//   final stationBereitsAbgeschlossen =
//       await riegenRepository.istStationBereitsProtokolliert(
//     riege: riegenPointer,
//     station: station!,
//   );

//   if (stationBereitsAbgeschlossen) {
//     // Alle Kinder der Riege gelten für diese Station als bereits
//     // ausgewertet -> sie dürfen an dieser Station nicht nochmal antreten.
//     ausgewerteteKinder.addAll(riegenKinder);
//   }

//   if (!mounted) return;
//   setState(() {
//     kinderZurAnzeige = kindRepository.zurAnzeigeSortieren(
//         alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
//   });
// }
//   /// Liefert die Kinder, die aktuell in der Liste angezeigt werden sollen.
//   /// - Vor dem Testlauf (testLauf == true): alle Kinder der Riege
//   ///   (bereits ausgewertete Kinder stehen dank zurAnzeigeSortieren hinten).
//   /// - Nach dem Testlauf, bis der Wertungslauf abgeschlossen ist
//   ///   (testLauf == false): nur die für diesen Wettbewerb ausgewählten
//   ///   Kinder – die Teilnahme steht fest, nur die Hütchen-Wahl darf noch
//   ///   geändert werden.
//   List<Kind> get _kinderFuerAnzeige {
//     if (testLauf) {
//       return kinderZurAnzeige;
//     }
//     return kinderZurAnzeige
//         .where((kind) => selectedKinder.contains(kind))
//         .toList();
//   }

// Future<void> auswerten(Map<Kind, int> resultate) async {
//   log.i(
//       'in auswerten -> Ergebniss erstes Kind: ${resultate.values.first.toString()}');

//   // Auswertung nur zulassen, falls der Testlauf beendet ist
//   if (testLauf) return;

//   _auswertungAbgeschlossen = Completer<void>();

//   try {
//     // 1. Punkte berechnen (synchron)
//     final Map<Kind, int> punkteProKind = {
//       for (final entry in resultate.entries)
//         entry.key: _werteZeitenAus(entry.value, entry.key)
//     };

//     // 2. Punkte in 'resultate' speichern. speichereResultat() hat bereits
//     //    einen eigenen Idempotenz-Guard (_resultatVorhanden) -> auch bei
//     //    versehentlichem Doppelaufruf kein doppelter Eintrag.
//     for (final entry in punkteProKind.entries) {
//       log.i('in auswerten ${entry.value} für ${entry.key.nachname}');
//       await kindRepository.speichereResultat(
//           kind: entry.key, station: station!, punkte: entry.value);
//     }

//     // 3. State synchron aktualisieren -> löst Rebuild aus
//     if (!mounted) return;
//     setState(() {
//       kinderMitZeiten.addAll(punkteProKind);
//       ausgewerteteKinder.addAll(resultate.keys);
//       selectedKinder.clear();
//       kinderZurAnzeige = kindRepository.zurAnzeigeSortieren(
//           alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
//     });

//     // 4. Kind-Objekte abschließend speichern
//     for (final kind in resultate.keys) {
//       await kindRepository.saveKind(kind: kind);
//     }

//     // 5. NEU: Wenn jetzt ALLE Kinder der Riege an dieser Station
//     //    ausgewertet sind, gilt die Station für die Riege als
//     //    abgeschlossen -> riegenLogging-Eintrag erhöhen. Idempotent:
//     //    ein zweiter Aufruf für dieselbe Riege+Station wird intern
//     //    ignoriert (siehe _loggingEintragVorhanden).
//     if (ausgewerteteKinder.length == riegenKinder.length) {
//       final erhoeht = await riegenRepository.erhoeheStationszaehler(
//         riege: riegenPointer,
//         station: station!,
//       );
//       if (!erhoeht) {
//         log.w(
//             'Stationszähler für ${station!.stationsName} war bereits erhöht.');
//       }
//     }
//   } finally {
//     _auswertungAbgeschlossen?.complete();
//   }
// }
//   int _werteZeitenAus(int zeitInMillis, Kind kind) {
//     int punkte;
//     zeitInMillis > 0
//         ? punkte = gewaehlteHuetchen[kind] ?? 0
//         : punkte =
//             0; // Wenn 'kind' nicht in der Map enthalten ist, dann 0 zurückgeben
//     // Punkte werden aufgrund der erreichten Zeit berechnet
//     return punkte;
//   }

//   bool alleHuetchenGewaehlt() {
//     return selectedKinder.every((kind) => gewaehlteHuetchen[kind] != null);
//   }

//   @override
//   Widget build(BuildContext context) {
//     // PopScope verhindert den Rücksprung über den Browser-/System-Zurück-Button,
//     // solange die Station aktiv ist.
//     return PopScope(
//       canPop: false,
//       child: Scaffold(
//         appBar: MeineAppBar(
//           titel: stationsName,
//           stationsName: stationsName,
//         ),
//         body: Center(
//           child: Column(
//             children: [
//               Text(
//                 'Die Kinder führen nach Wahl der Hütchen einen Probedurchgang durch. \nDanach kann die Hütchenwahl geändert werden.\nBitte selektieren Sie die an der nächsten Runde teilnehmenden Kinder,\nwählen Sie die gewünschten Hütchen aus.',
//                 textAlign: TextAlign.center,
//                 style: Theme.of(context)
//                     .textTheme
//                     .bodySmall, // Verwenden des Themes
//               ),
//               // Abstandshalter
//               const SizedBox(height: 10),
//               // Liste der Kinder in der ausgewählten Riege
//               ElevatedButton(
//                 onPressed: (selectedKinder.isNotEmpty)
//                     // Wenn selektierte Kinder vorhanden sind, dann die StopUhr aufrufen
//                     ? () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => MyStopUhr(
//                               teilNehmer: selectedKinder,
//                               rufendeStation: stationsName,
//                               auswertenDerWerte:
//                                   auswerten, // Ergebnisse verarbeiten)
//                             ),
//                           ),
//                         ).then((_) async {
//                           // NEU: Falls eine Auswertung (Wertungslauf) läuft, erst darauf
//                           // warten, dass sie inkl. setState() fertig ist – sonst toggelt
//                           // testLauf zu früh und die Liste zeigt den alten Stand.
//                           if (_auswertungAbgeschlossen != null) {
//                             await _auswertungAbgeschlossen!.future;
//                             _auswertungAbgeschlossen =
//                                 null; // für nächsten Durchlauf zurücksetzen
//                           }
//                           if (!mounted) return;
//                           setState(() {
//                             testLauf = !testLauf; // Jetzt toggeln
//                           });
//                         });
//                       }
//                     : null,
//                 child: Text(
//                   testLauf
//                       ? 'Testlauf mit ausgewählten Namen'
//                       : 'Wertungslauf mit ausgewählten Namen',
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//               // Zeigt die Liste der Kinder als Karten
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: _kinderFuerAnzeige
//                       .length, // NEU: statt riegenKinder.length
//                   itemBuilder: (context, index) {
//                     final kind = _kinderFuerAnzeige[
//                         index]; // NEU: statt kinderZurAnzeige[index]
//                     final zeit = kinderMitZeiten[kind];
//                     final istAusgewertet = ausgewerteteKinder.contains(kind);
//                     final istSelektiert = selectedKinder.contains(kind);

//                     return MeinKartenEintrag(
//                       istSelektiert: istSelektiert,
//                       istAusgewertet: istAusgewertet,
//                       trailing: (istSelektiert && !istAusgewertet)
//                           ? Padding(
//                               padding:
//                                   const EdgeInsets.symmetric(horizontal: 10.0),
//                               child: DropdownButton<int>(
//                                 value: gewaehlteHuetchen[kind],
//                                 items: [1, 2, 3, 4]
//                                     .map((v) => DropdownMenuItem(
//                                         value: v, child: Text('Hütchen $v')))
//                                     .toList(),
//                                 onChanged: (newValue) {
//                                   // Hütchen-Wahl bleibt in beiden Phasen änderbar
//                                   if (newValue != null) {
//                                     setState(() =>
//                                         gewaehlteHuetchen[kind] = newValue);
//                                   }
//                                 },
//                               ),
//                             )
//                           : null,
//                       child: MeinListenEintrag(
//                         kind: kind,
//                         istAusgewertet: istAusgewertet,
//                         istSelektiert: istSelektiert,
//                         erreichtePunkte: zeit,
//                         onSelectionChanged: (Kind kind, bool istSelektiert) {
//                           // NEU: Nach dem Testlauf steht die Teilnehmerliste fest –
//                           // die Auswahl darf dann nicht mehr verändert werden,
//                           // nur noch die Hütchen-Wahl (siehe Dropdown unten).
//                           if (!testLauf) return;

//                           setState(() {
//                             if (istSelektiert) {
//                               selectedKinder.add(kind);
//                               gewaehlteHuetchen.putIfAbsent(kind, () => 1);
//                             } else {
//                               selectedKinder.remove(kind);
//                               gewaehlteHuetchen.remove(kind);
//                             }
//                           });
//                         },
//                       ),
//                     );
//                   },
//                 ),
//               ),
//               // Unterhalb der Liste wird der Beenden-Button angezeigt,
//               // wenn alle Kinder in der Liste die Station absolviert haben
//               if (riegenKinder.length ==
//                   ausgewerteteKinder.length) // Beenden-Button anzeigen
//                 // wenn alle Kinder ausgewertet sind wird
//                 // zur Disziplinen-Übersicht weitergeleitet und zuvor
//                 // die Anzahl der absolvierten Disziplinen für die aktuelle Riege erhöht
//                 ZurueckButton(
//                   label: 'Nächste Disziplin steht an',
//                   riegenPointer: riegenPointer,
//                   stationsPointer: station,
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }