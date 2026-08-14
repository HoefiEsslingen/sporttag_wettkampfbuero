import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';
import 'package:sporttag/src/mixins/stop_uhr_auswertung_mixin.dart';
import 'package:sporttag/src/tools/disziplin_kinder_liste.dart';
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
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed:
                    (selectedKinder.isNotEmpty && !wertungWirdVerarbeitet)
                        ? () => starteStopUhr(
                              context,
                              builder: (context) => MyStopUhr(
                                teilNehmer: selectedKinder,
                                rufendeStation: stationsName,
                                auswertenDerWerte: stopUhrAuswerten,
                                onAbgebrochen: stopUhrAbgebrochen,
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
                child: DisziplinKinderListe(
                  kinder: _kinderFuerAnzeige,
                  selectedKinder: selectedKinder,
                  ausgewerteteKinder: ausgewerteteKinder,
                  kinderMitZeiten: kinderMitZeiten,
                  onSelectionChanged: (kind, istSelektiert) {
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
                  trailingBuilder: (context, kind) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: DropdownButton<int>(
                      value: gewaehlteHuetchen[kind],
                      items: [1, 2, 3, 4]
                          .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                'Hütchen $v',
                                style: TextStyle(color: Colors.green),
                              )))
                          .toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() => gewaehlteHuetchen[kind] = newValue);
                        }
                      },
                    ),
                  ),
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
