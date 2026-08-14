import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';
import 'package:sporttag/src/mixins/versuche_auswertung_mixin.dart';
import 'package:sporttag/src/tools/disziplin_kinder_liste.dart';
import 'package:sporttag/src/tools/mehrere_versuche_pro_durchgang.dart';

class HochWeitSprung extends StatefulWidget {
  final Riege riegenPointer;

  const HochWeitSprung({super.key, required this.riegenPointer});

  @override
  HochWeitSprungState createState() => HochWeitSprungState();
}

class HochWeitSprungState extends State<HochWeitSprung>
    with
        StationenBasisMixin<HochWeitSprung>,
        VersucheAuswertungMixin<HochWeitSprung> {
  // Ersetzt die frühere manuelle "* 2" beim Speichern in
  // _auswertungAbschliessen() -- dort wurden die Punkte durch
  // "kinderMitErreichtenPunkten[dasKind] = punkte" (bereits *2) UND
  // zusätzlich "punkte: punkte * 2" beim Speichern jeweils verdoppelt,
  // macht in Summe *4 statt *2. Der Multiplikator wird jetzt genau EINMAL
  // angewendet, zentral im Mixin (versucheAuswerten()).
  @override
  int get punkteMultiplikator => 2;

  @override
  void initState() {
    super.initState();
    stationsName = 'Hochsprung';
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
      body: riegenKinder.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Text(
                  'Jedes Kind hat pro Durchgang zwei Versuche.\nBestandene Versuche erhöhen den Punktestand um 1.\nKinder mit zwei Fehlversuchen dürfen dann anfeuern.\nEs wird so lange gesprungen, bis alle Kinder anfeuern dürfen.\nAm Ende werden die Punkte verdoppelt.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 10),
                // Liste der Kinder in der ausgewählten Riege. HochWeitSprung
                // ist wie Zonenweitsprung/Stabfliegen ein "alle gemeinsam"-
                // Muster (eine einzige Durchgangsserie für die ganze Riege)
                // -> anders als bei Drehwurf/Schlagwurf ist "if (!istAusgewertet)"
                // hier korrekt: nach der einen Auswertung gibt es nichts
                // mehr zu starten.
                if (!istAusgewertet)
                  ElevatedButton(
                      onPressed: !wertungWirdVerarbeitet
                          ? () => starteVersuche(
                                context,
                                builder: (context) => VersucheInDurchgaengen(
                                  teilnehmer: riegenKinder,
                                  anzahlVersuche: 2,
                                  onErgebnisseAbschliessen: versucheAuswerten,
                                  onAbgebrochen: versucheAbgebrochen,
                                  iconWidget: Image.asset(
                                    'assets/icons/hochsprung.png',
                                    width: 30,
                                    height: 30,
                                  ),
                                ),
                              )
                          : null,
                      child: wertungWirdVerarbeitet
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
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
