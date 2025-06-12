import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';

import '../hilfs_widgets/mein_listen_eintrag.dart';
import '../klassen/kind_klasse.dart';
import '../tools/kind_repository.dart';
import '../tools/logger.util.dart';
import '../tools/stationen_repository.dart';
import '../tools/stop_uhr.dart';

class Lauf extends StatefulWidget {
  final int riegenNummer;

  const Lauf({super.key, required this.riegenNummer});

  /// Aktivität vorbereiten
  @override
  LaufState createState() => LaufState();
}

class LaufState extends State<Lauf> {
  late int riegenNummer;
  late String stationsName;

  // Repository-Objekte
  final KindRepository kindRepository = KindRepository();
  final StationenRepository stationenRepository = StationenRepository();

  List<Kind> riegenKinder = [];
  List<Kind> kinderZurAnzeige = []; // Speichert anzuzeigende Teilnehmer
  Set<Kind> ausgewerteteKinder = {}; // Speichert ausgewertete Teilnehmer
  List<Kind> selectedKinder = [];
  Map<Kind, int> kinderMitZeiten = {}; // Speichert gestoppte Zeiten

  final log = getLogger();

  @override
  void initState() {
    super.initState();
    stationsName = '30sec-Lauf';
    riegenNummer = widget.riegenNummer;
    _loadData();
  }

  Future<void> _loadData() async {
    riegenKinder = await kindRepository.loadKinderAusRiege(mitRiegenNummer: riegenNummer);
    // Liste zur Anzeige aufbereiten -> nicht ausgewertete Kinder oben
    kinderZurAnzeige =
        kindRepository.zurAnzeigeSortieren(alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
    setState(() {}); // UI aktualisieren
  }

  Future<void> auswerten(Map<Kind, int> resultate) async {
    log.i(
        'in auswerten -> Ergebniss erstes Kind: ${resultate.values.first.toString()}');
    setState(() {
      kinderMitZeiten.addAll(resultate); // Gestoppte Zeiten hinzufügen
      // Gestoppte Zeiten hinzufügen und Punkte berechnen
      for (var entry in resultate.entries) {
        final kind = entry.key;
        final runden = entry.value;

        kinderMitZeiten[kind] = runden; // erreichte Punkte (halbe Runden) speichern
        log.i('in auswerten $runden für ${kind.nachname}');
        kind.erreichtePunkte += runden; // Punkte zuweisen
      }

      // Teilnehmer als ausgewertet markieren
      ausgewerteteKinder.addAll(resultate.keys);

      // Auswahl nach der Auswertung zurücksetzen
      selectedKinder.clear();

      // Liste zur Anzeige aufbereiten -> nicht ausgewertete Kinder oben
      kinderZurAnzeige =
          kindRepository.zurAnzeigeSortieren(alleKinder:  riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
    });

    // Speichern der ausgewerteten Kinder in der Datenbank
    final zuSpeicherndeKinder = resultate.keys.toList();
    for (var dasKind in zuSpeicherndeKinder) {
      await kindRepository.saveKindToDatabase(kind: dasKind);
    }
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
              'In 30 sek laufen mehrere Kinder (empfohlen 3 oder 4)\nso viele Runden wie möglich. \nGezählt wird zu Beginn jeder halben Runde',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            // Abstandshalter
            const SizedBox(height: 10),
            // Liste der Kinder in der ausgewählten Riege
            ElevatedButton(
              onPressed: (selectedKinder.isNotEmpty)
                  // Wenn selektierte Kinder vorhanden sind, dann den Timer starten
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
                      );
                    }
                  : null,
              child: const Text(
                'Wertungslauf mit ausgewählten Namen',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: riegenKinder.length,
                itemBuilder: (context, index) {
                  final kind = kinderZurAnzeige[index];
                  final erreichtePunkte = kinderMitZeiten[kind]; // Gestoppte Zeit abrufen
                  final istAusgewertet = ausgewerteteKinder.contains(kind);
                  final istSelektiert = selectedKinder.contains(kind);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment
                        .spaceBetween, // Platzierung der Widgets
                    children: [
                      Expanded(
                        flex: 3, // 3 Teile für den Listeneintrag
                        child: MeinListenEintrag(
                          kind: kind,
                          istAusgewertet: istAusgewertet,
                          istSelektiert: istSelektiert,
                          erreichtePunkte: erreichtePunkte,
                          onSelectionChanged: (Kind kind, bool istSelektiert) {
                            setState(() {
                              if (istSelektiert) {
                                selectedKinder.add(kind);
                              } else {
                                selectedKinder.remove(kind);
                              }
                            });
                          }
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (riegenKinder.length == ausgewerteteKinder.length) // Beenden-Button anzeigen
              const ZurueckButton(label: 'Nächste Disziplin steht an'),
          ],
        ),
      ),
    );
  }
}
