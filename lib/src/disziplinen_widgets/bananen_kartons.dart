import 'package:sporttag/src/hilfs_widgets/mein_listen_eintrag.dart';
import 'package:sporttag/src/tools/kind_repository.dart';
import 'package:sporttag/src/tools/stationen_repository.dart';
import 'package:sporttag/src/tools/logger.util.dart';
import 'package:flutter/material.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/tools/stop_uhr.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';

import '../hilfs_widgets/meine_appbar.dart';

class Bananenkartons extends StatefulWidget {
  final int riegenNummer;

  const Bananenkartons({super.key, required this.riegenNummer});

  /// Aktivität vorbereiten
  @override
  BananenkartonsState createState() => BananenkartonsState();
}

class BananenkartonsState extends State<Bananenkartons> {
  late String stationsName; // Variable für die zugewiesene Ausgabe

  // Repository-Objekte
  final KindRepository kindRepository = KindRepository();
  final StationenRepository stationenRepository = StationenRepository();

  late int riegenNummer;
  List<Kind> riegenKinder = [];
  List<Kind> selectedKinder = [];
  List<Kind> kinderZurAnzeige = []; // Speichert anzuzeigende Teilnehmer
  Set<Kind> ausgewerteteKinder = {}; // Speichert ausgewertete Teilnehmer
  Map<Kind, int> kinderMitZeiten = {}; // Speichert gestoppte Zeiten

  final log = getLogger();

  @override
  initState() {
    super.initState();
    // widget.toString() der Variable zuweisen
    stationsName = "30m-Bananenkartons";
    riegenNummer = widget.riegenNummer;
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
    riegenKinder.clear();
    selectedKinder.clear();
    kinderZurAnzeige.clear();
    ausgewerteteKinder.clear();
    kinderMitZeiten.clear();
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
        final zeit = entry.value;

        kinderMitZeiten[kind] = zeit; // Zeit speichern
log.i('in auswerten $zeit für ${kind.nachname}');
        // Punkte werden aufrund der erreichten Zeit berechnet
        final punkte = _werteZeitenAus(zeit); // Punkte berechnen
        // die an dieser Station erreichten Punkte werden gespeichert
        kinderMitZeiten[kind] = punkte;
        kind.erreichtePunkte += punkte; // Punkte zuweisen
      }

      // Teilnehmer als ausgewertet markieren
      ausgewerteteKinder.addAll(resultate.keys);

      // Auswahl nach der Auswertung zurücksetzen
      selectedKinder.clear();

      // Liste zur Anzeige aufbereiten -> nicht ausgewertete Kinder oben
      kinderZurAnzeige =
          kindRepository.zurAnzeigeSortieren(alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
    });

    // Speichern der ausgewerteten Kinder in der Datenbank
    final zuSpeicherndeKinder = resultate.keys.toList();
    for (var dasKind in zuSpeicherndeKinder) {
      await kindRepository.saveKindToDatabase(kind: dasKind);
    }
  }

  int _werteZeitenAus(int zeitInMillis) {
    // Beispielhafte Bewertung basierend auf Zeit
    final seconds = zeitInMillis ~/ 1000;
    if (seconds > 17) {
      return 0;
    } else if (seconds > 16) {
      return 1;
    } else if (seconds > 15) {
      return 2;
    } else if (seconds > 14) {
      return 3;
    } else if (seconds > 13) {
      return 4;
    } else {
      return 5;
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
              'Bitte selektieren Sie die an der nächsten Runde teilnehmenden Kinder.',
              textAlign: TextAlign.center,
              style:
                  Theme.of(context).textTheme.bodySmall, // Verwenden des Themes
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
                'Starte Timer mit ausgewählten Namen',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: riegenKinder.length,
                itemBuilder: (context, index) {
                  final kind = kinderZurAnzeige[index];
                  final zeit = kinderMitZeiten[kind]; // Gestoppte Zeit abrufen
                  final istAusgewertet = ausgewerteteKinder.contains(kind);
                  log.i('in ListViewBuilder ${kind.nachname} ist selektiert? -> ${selectedKinder.contains(kind).toString()}');
                  final istSelektiert = selectedKinder.contains(kind);
                  return MeinListenEintrag(
                    kind: kind,
                    istAusgewertet: istAusgewertet,
                    istSelektiert: istSelektiert,
                    erreichtePunkte: zeit,
                    onSelectionChanged: (Kind kind, bool istSelektiert) {
                      setState(() {
                        if (istSelektiert) {
                          selectedKinder
                              .add(kind); // Hinzufügen, wenn ausgewählt
                        } else {
                          selectedKinder
                              .remove(kind); // Entfernen, wenn abgewählt
                        }
                      });
                    },
                  );
                },
              ),
            ),
            if (riegenKinder.length ==
                ausgewerteteKinder.length) // Beenden-Button anzeigen
              const ZurueckButton(label: 'Nächste Disziplin steht an'),
          ],
        ),
      ),
    );
  }
}
