import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';
import 'package:sporttag/src/tools/disziplin_kinder_liste.dart';
import 'package:sporttag/src/tools/stationen_in_durchgaengen.dart';

class Zonenweitsprung extends StatefulWidget {
  final Riege riegenPointer;

  const Zonenweitsprung({super.key, required this.riegenPointer});

  /// Aktivität vorbereiten
  @override
  ZonenweitsprungState createState() => ZonenweitsprungState();
}

class ZonenweitsprungState extends State<Zonenweitsprung>
    with StationenBasisMixin<Zonenweitsprung> {
  var istAusgewertet = false;
  Map<Kind, int> kinderMitErreichtenPunkten = {}; // Speichert die Summe der beiden besten Würfe

  @override
  void initState() {
    super.initState();
    // widget.toString() der Variable zuweisen
    stationsName = 'Zonenweitsprung';
    riegenPointer = widget.riegenPointer;
    ladeStationsdaten();
  }

  Future<void> auswerten(Map<Kind, List<int>> resultate) async {
    // Auswertung zulassen, falls der Testlauf beendet ist
    setState(() {
      // resultate ist eine Liste von int-Werten
      // aus dieser Liste sollen die besten zwei Werte ermittelt und addiert werden
      // --> die Liste wird absteigend sortiert
      resultate.forEach((kind, listeDerErreichtenZonen) async {
        listeDerErreichtenZonen
            .sort((a, b) => b.compareTo(a)); // Absteigend sortieren
        final besteZwei =
            listeDerErreichtenZonen.take(2).toList(); // Besten zwei Werte
        final summe = besteZwei.reduce((a, b) => a + b); // Addieren
        kinderMitErreichtenPunkten[kind] = summe; // Zeit speichern
        //kind.erreichtePunkte += summe; // Punkte zuweisen
        await kindRepository.speichereResultat(kind: kind, station: station!, punkte: summe);
      });

      // alle Teilnehmer als ausgewertet markieren --> resultate.keys sind die Kinder, die ausgewertet wurden
      ausgewerteteKinder.addAll(resultate.keys);
      // Auswahl nach der Auswertung zurücksetzen
      selectedKinder.clear();

      // Liste zur Anzeige aufbereiten -> nicht ausgewertete Kinder oben
      kinderZurAnzeige =
          kindRepository.zurAnzeigeSortieren(alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);

      // globale Variable 'istAusgewertet' setzen
      // damit die AppBar den Button "Nächste Disziplin steht an" anzeigen kann
      istAusgewertet = true;
    });

    // Speichern der ausgewerteten Kinder (hier: alle) in der Datenbank
    final zuSpeicherndeKinder = resultate.keys.toList();
    for (var dasKind in zuSpeicherndeKinder) {
      await kindRepository.saveKind(kind:dasKind);
    }
  }

  @override
  void dispose() {
    super.dispose();
    riegenKinder.clear();
    selectedKinder.clear();
    kinderZurAnzeige.clear();
    ausgewerteteKinder.clear();
    kinderMitErreichtenPunkten.clear();
    resetStationsdaten();
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
              'Aus einem definierten Anlauf sollen die Kinder mit einem Bein abspringen und beidbeinig in einem Reifen landen.\nNach einem Probedurchgang, der nicht protokolliert wird, werden für jedes Kind drei Durchgänge gewertet.\nJeder Reifen entspricht einer Zone.\nDie zwei besten Sprünge werden addiert.',
              textAlign: TextAlign.center,
              style:
                  Theme.of(context).textTheme.bodySmall, // Verwenden des Themes
            ),
            // Abstandshalter
            const SizedBox(height: 10),
            Text(
              'Jetzt in einen Probedurchgang starten.\n Danach:',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.green, fontWeight: FontWeight.bold, backgroundColor: Colors.white),
                  // Verwenden des Themes
            ),
            const SizedBox(height: 10),
            // Liste der Kinder in der ausgewählten Riege
            if (!istAusgewertet)
              ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StationenInDurchgaengen(
                            teilnehmer: kinderZurAnzeige,
                            anzahlDurchgaenge: 3,
                            onErgebnisseAbschliessen: auswerten,
                            iconWidget: Image.asset(
                              'assets/icons/weitsprung.png',
                              width: 30,
                              height: 30,
                            ),
                          ),
                        ));
                  },
                  child: const Text(
                    'In die Wertungsdurchgänge starten',
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
            if (riegenKinder.length ==
                ausgewerteteKinder.length) // Beenden-Button anzeigen
            // wenn alle Kinder ausgewertet sind wird 
            // zur Disziplinen-Übersicht weitergeleitet und zuvor
            // die Anzahl der absolvierten Disziplinen für die aktuelle Riege erhöht
              ZurueckButton(label: 'Nächste Disziplin steht an', 
                            riegenPointer: riegenPointer,
                            stationsPointer: station),  
          ],
        ),
      ),
    );
  }
}
