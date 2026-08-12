import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';
import 'package:sporttag/src/tools/disziplin_kinder_liste.dart';
import 'package:sporttag/src/tools/mehrere_versuche_pro_durchgang.dart';

class HochWeitSprung extends StatefulWidget {
  final Riege riegenPointer;

  const HochWeitSprung({super.key, required this.riegenPointer});

  @override
  HochWeitSprungState createState() => HochWeitSprungState();
}

class HochWeitSprungState extends State<HochWeitSprung>
    with StationenBasisMixin<HochWeitSprung> {
  // Wie Zonenweitsprung/Schlagwurf: eigener Flag statt riegenKinder.length
  // == ausgewerteteKinder.length, da alle Kinder gemeinsam in einer
  // Durchgangsserie antreten.
  var istAusgewertet = false;

  // Speichert die (verdoppelten) Punkte je Kind.
  Map<Kind, int> kinderMitErreichtenPunkten = {};

  @override
  void initState() {
    super.initState();
    stationsName = 'Hoch-Weitsprung';
    riegenPointer = widget.riegenPointer;
    ladeStationsdaten();
  }

  @override
  void dispose() {
    resetStationsdaten();
    kinderMitErreichtenPunkten.clear();
    istAusgewertet = false;
    super.dispose();
  }

  Future<void> _auswertungAbschliessen(Map<Kind, int> ergebnisse) async {
    for (var dasKind in riegenKinder) {
      // ergebnisse[dasKind]! durch Null-Safe-Zugriff ersetzt:
      //fehlt ein Kind im Ergebnis (z. B. nicht angetreten),
      //gab es sonst einen Crash statt einer sinnvollen 0-Punkte-Wertung.
      final punkte = (ergebnisse[dasKind] ?? 0) * 2;
      kinderMitErreichtenPunkten[dasKind] = punkte;
      await kindRepository.speichereResultat(
          kind: dasKind, station: station!, punkte: punkte * 2);
      await kindRepository.saveKind(kind: dasKind);
    }
    ausgewerteteKinder.addAll(riegenKinder);
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
                Expanded(
                  child: DisziplinKinderListe(
                    kinder: kinderZurAnzeige,
                    selectedKinder: selectedKinder,
                    ausgewerteteKinder: ausgewerteteKinder,
                    kinderMitZeiten: kinderMitErreichtenPunkten,
                    onSelectionChanged: (Kind kind, bool istSelektiert) {
                      setState(() {
                        // Keine Aktion
                      });
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
