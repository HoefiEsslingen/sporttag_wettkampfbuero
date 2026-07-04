import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/tools/logger.util.dart';

class StationenInDurchgaengen extends StatefulWidget {
  final List<Kind> teilnehmer;
  final int anzahlDurchgaenge;
  final Function(Map<Kind, List<int>>) onErgebnisseAbschliessen;
  final Widget iconWidget;

  const StationenInDurchgaengen({
    super.key,
    required this.teilnehmer,
    required this.anzahlDurchgaenge,
    required this.onErgebnisseAbschliessen,
    required this.iconWidget,
  });

  @override
  State<StationenInDurchgaengen> createState() =>
      _MehrfacheEingabeDialogWidgetState();
}

class _MehrfacheEingabeDialogWidgetState
    extends State<StationenInDurchgaengen> {
  int aktuellerDurchgang = 1;
  final Map<Kind, List<int>> ergebnisse = {};
  final Map<Kind, int> aktuellerWert = {};
  final Set<Kind> bearbeitet = {};
  List<Kind> teilnehmerReihenfolge = [];

  Kind? aktivBearbeitetesKind;
  int selectedValue = 1;

  final log = getLogger();

  late int anzahlDurchgaenge;
  late Widget iconWidget;
  late Function(Map<Kind, List<int>>) onErgebnisseAbschliessen;

  @override
  void initState() {
    super.initState();
    anzahlDurchgaenge = widget.anzahlDurchgaenge;
    iconWidget = widget.iconWidget;
    onErgebnisseAbschliessen = widget.onErgebnisseAbschliessen;
    teilnehmerReihenfolge = List.from(widget.teilnehmer);
    for (final kind in teilnehmerReihenfolge) {
      ergebnisse[kind] = List<int>.filled(anzahlDurchgaenge, 0);
      aktuellerWert[kind] = 0;
    }
  }

  bool alleBearbeitet() => bearbeitet.length == teilnehmerReihenfolge.length;

  void _bestaetigeWert() {
    if (aktivBearbeitetesKind == null) return;

    setState(() {
      aktuellerWert[aktivBearbeitetesKind!] = selectedValue;
      ergebnisse[aktivBearbeitetesKind!]![aktuellerDurchgang - 1] =
          selectedValue;
      bearbeitet.add(aktivBearbeitetesKind!);
      teilnehmerReihenfolge.remove(aktivBearbeitetesKind);
      teilnehmerReihenfolge.add(aktivBearbeitetesKind!);
      aktivBearbeitetesKind = null;

      if (alleBearbeitet()) {
        if (aktuellerDurchgang < anzahlDurchgaenge) {
          aktuellerDurchgang++;
          log.i(
              'aktueller Durchgang: $aktuellerDurchgang und alleBearbeitet() ${alleBearbeitet()} ');
          bearbeitet.clear();
        } else {
          setState(() {}); // <- Das triggert den ZurueckButton im build()
          // widget.onErgebnisseAbschliessen(ergebnisse); // falls gewünscht später
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(
        titel: 'Durchgang $aktuellerDurchgang von $anzahlDurchgaenge',
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          if (aktivBearbeitetesKind != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${aktivBearbeitetesKind!.vorname} ${aktivBearbeitetesKind!.nachname}: erreichte Zone',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: selectedValue.toDouble(),
                    min: 1,
                    max: 6,
                    divisions: 5,  // divisions = max-min
                    label: 'Zone $selectedValue',
                    onChanged: (double value) {
                      setState(() {
                        selectedValue = value.toInt();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _bestaetigeWert,
                    child: const Text('Bestätigen'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: teilnehmerReihenfolge.length,
              itemBuilder: (context, index) {
                final kind = teilnehmerReihenfolge[index];
                return ListTile(
                  title: Text('${kind.vorname} ${kind.nachname}'),
                  subtitle:
                      Text('Bisher erreicht: ${ergebnisse[kind]!.join(' | ')}'),
                  trailing: bearbeitet.contains(kind)
                      ? const Icon(Icons.check, color: Colors.green, size: 40)
                      : IconButton(
                          icon:
                              iconWidget, // <-- Bild-Icon nutzen  //auskommentiert:  const Icon(Icons.sports_handball),
                          tooltip:
                              'Nachdem die erzielten Punkte erfasst und bestätigt wurden, wird der Teilnehmer an das Ende der Liste verschoben.',
                          iconSize: 40,
                          onPressed: () {
                            setState(() {
                              aktivBearbeitetesKind = kind;
                              selectedValue =
                                  1 /* auskommentiert: aktuellerWert[kind] ?? 1*/;
                            });
                          },
                        ),
                );
              },
            ),
          ),
          if (aktuellerDurchgang == anzahlDurchgaenge && alleBearbeitet())
            ZurueckButton(
              label: 'Ergebnisse auswerten und zurück',
              auswertenDerErgebnisse: () =>
                  onErgebnisseAbschliessen(ergebnisse),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
