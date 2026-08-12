import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/mixins/beste_zwei_auswertung_mixin.dart';
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
    with StationenBasisMixin<Zonenweitsprung>, BesteZweiAuswertungMixin<Zonenweitsprung> {

  @override
  void initState() {
    super.initState();
    // widget.toString() der Variable zuweisen
    stationsName = 'Zonenweitsprung';
    riegenPointer = widget.riegenPointer;
    ladeStationsdaten();
  }

  @override
  void dispose() {
    resetStationsdaten();
    super.dispose();
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
              style: Theme.of(context).textTheme.bodySmall, // Verwenden des Themes
            ),
            // Abstandshalter
            const SizedBox(height: 10),
            Text(
              'Jetzt in einen Probedurchgang starten.\n Danach:',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.white),
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
                            onErgebnisseAbschliessen: besteZweiAuswerten,
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
              ZurueckButton(
                  label: 'Nächste Disziplin steht an',
                  riegenPointer: riegenPointer,
                  stationsPointer: station),
          ],
        ),
      ),
    );
  }
}
