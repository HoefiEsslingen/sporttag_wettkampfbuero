import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/mein_listen_eintrag.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/station_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/tools/kind_repository.dart';
import 'package:sporttag/src/tools/logger.util.dart';
import 'package:sporttag/src/tools/mehrere_versuche_pro_durchgang.dart';
import 'package:sporttag/src/tools/station_repository.dart';

class HochWeitSprung extends StatefulWidget {
  final Riege riegenPointer;

  const HochWeitSprung({super.key, required this.riegenPointer});

  @override
  HochWeitSprungState createState() => HochWeitSprungState();
}

class HochWeitSprungState extends State<HochWeitSprung> {
  late String stationsName; // Variable für die zugewiesene Ausgabe
  // Repository-Objekte
  final KindRepository kindRepository = KindRepository();
  final StationRepository stationRepository = StationRepository();

  late Riege riegenPointer;
  List<Kind> riegenKinder = [];
  List<Kind> selectedKinder = [];
  List<Kind> kinderZurAnzeige = []; // Speichert anzuzeigende Teilnehmer
  Set<Kind> ausgewerteteKinder = {}; // Speichert ausgewertete Teilnehmer
  var istAusgewertet = false;
  Map<Kind, int> kinderMitErreichtenPunkten =
      {}; // Speichert die Summe der beiden besten Würfe
  Station? station; // Speichert die Station

  final log = getLogger();

  @override
  void initState() {
    super.initState();
    stationsName = 'Hoch-Weitsprung';
    riegenPointer = widget.riegenPointer;
    _loadData();
  }

  Future<void> _loadData() async {
    riegenKinder =
        await kindRepository.ladeKinderDerRiege(riege: riegenPointer);
    station =
        await stationRepository.ladeStationNachName(stationsName: stationsName);
    // Liste zur Anzeige aufbereiten -> nicht ausgewertete Kinder oben
    kinderZurAnzeige = kindRepository.zurAnzeigeSortieren(
        alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
    setState(() {});
  }

  Future<void> _auswertungAbschliessen(Map<Kind, int> ergebnisse) async {
    for (var dasKind in riegenKinder) {
      final punkte = ergebnisse[dasKind];
      kinderMitErreichtenPunkten[dasKind] = punkte! * 2;
      // dasKind.erreichtePunkte += punkte * 2;
      // await kindRepository.saveKind(kind: dasKind);
      await kindRepository.speichereResultat(
          kind: dasKind, station: station!, punkte: punkte * 2);
    }
    if (!mounted) return; // Widget bereits disposed → abbrechen
    setState(() {
      istAusgewertet = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(
        titel: stationsName,
        stationsName: stationsName,
      ),
      body: riegenKinder.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Text(
                  'Jedes Kind hat pro Durchgang zwei Versuche.\nBestandene Versuche erhöhen den Punktestand um 1.\nEs gibt so viele Durchgänge, bis alle Kinder ausgeschieden sind.\nAm Ende werden die Punkte verdoppelt.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                // Liste der Kinder in der ausgewählten Riege
                if (!istAusgewertet)
                  ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VersucheInDurchgaengen(
                                teilnehmer: riegenKinder,
                                anzahlVersuche: 2,
                                onErgebnisseAbschliessen:
                                    _auswertungAbschliessen,
                                iconWidget: Image.asset(
                                  'assets/icons/hochsprung.png',
                                  width: 30,
                                  height: 30,
                                ),
                              ),
                            ));
                      },
                      child: const Text(
                        'In den ersten Durchgang starten',
                        textAlign: TextAlign.center,
                      )),
                // Abstandshalter
                const SizedBox(height: 10),
                // Zeigt die Liste der Kinder in der Riege an
                // Hier können die Kinder, welche an der nächsten Runde teilnehmen sollen ausgewählt werden
                Expanded(
                  child: ListView.builder(
                    itemCount: riegenKinder.length,
                    itemBuilder: (context, index) {
                      final kind = kinderZurAnzeige[index];
                      final zeit = kinderMitErreichtenPunkten[
                          kind]; // Gestoppte Zeit abrufen
                      final istAusgewertet = ausgewerteteKinder.contains(kind);
                      final istSelektiert = selectedKinder.contains(kind);
                      return MeinListenEintrag(
                        kind: kind,
                        istAusgewertet: istAusgewertet,
                        istSelektiert: istSelektiert,
                        erreichtePunkte: zeit,
                        onSelectionChanged: (Kind kind, bool istSelektiert) {
                          setState(() {
                            // Keine Aktion
                          });
                        },
                      );
                    },
                  ),
                ),
                if (istAusgewertet)
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
    );
  }
}
