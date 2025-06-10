import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../hilfs_widgets/rueck_sprung_button.dart';
import '../hilfs_widgets/meine_appbar.dart';
import '../klassen/kind_klasse.dart';
import 'logger.util.dart';

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

class _MehrfacheEingabeDialogWidgetState extends State<StationenInDurchgaengen> {
  int aktuellerDurchgang = 1;
  final Map<Kind, List<int>> ergebnisse = {};
  final Map<Kind, int> aktuellerWert = {};
  final Set<Kind> bearbeitet = {};
  List<Kind> teilnehmerReihenfolge = [];

  Kind? aktivBearbeitetesKind;
  int selectedValue = 1;

  final log = getLogger();

  @override
  void initState() {
    super.initState();
    teilnehmerReihenfolge = List.from(widget.teilnehmer);
    for (final kind in widget.teilnehmer) {
      ergebnisse[kind] = List<int>.filled(widget.anzahlDurchgaenge, 0);
      aktuellerWert[kind] = 0;
    }
  }

  bool alleBearbeitet() => bearbeitet.length == widget.teilnehmer.length;

  void _bestaetigeWert() {
    if (aktivBearbeitetesKind == null) return;

    setState(() {
      aktuellerWert[aktivBearbeitetesKind!] = selectedValue;
      ergebnisse[aktivBearbeitetesKind!]![aktuellerDurchgang - 1] = selectedValue;
      bearbeitet.add(aktivBearbeitetesKind!);
      teilnehmerReihenfolge.remove(aktivBearbeitetesKind);
      teilnehmerReihenfolge.add(aktivBearbeitetesKind!);
      aktivBearbeitetesKind = null;

      if (alleBearbeitet()) {
        if (aktuellerDurchgang < widget.anzahlDurchgaenge) {
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
        titel: 'Durchgang $aktuellerDurchgang von ${widget.anzahlDurchgaenge}',
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          if (aktivBearbeitetesKind != null)
            Container(
              color: Colors.white,
              height: 190,
              child: Expanded(
                child: Column(
                  children: [
                    Text(
                      '${aktivBearbeitetesKind!.vorname} ${aktivBearbeitetesKind!.nachname}: erreichte Zone',
                      style: const TextStyle(fontSize: 20),
                    ),
                    SizedBox(
                      height: 100,
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController:
                            FixedExtentScrollController(initialItem: 0),
                        onSelectedItemChanged: (value) {
                          setState(() {
                            selectedValue = value; // Werte ab 1
                          });
                        },
                        children: List<Widget>.generate(
                          7,
                          (index) => Center(child: Text('$index')),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      onPressed: _bestaetigeWert,
                      child: const Text('Bestätigen'),
                    ),
                  ],
                ),
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
                          icon: widget
                              .iconWidget, // <-- Bild-Icon nutzen  //auskommentiert:  const Icon(Icons.sports_handball),
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
          if (aktuellerDurchgang == widget.anzahlDurchgaenge &&
              alleBearbeitet())
            ZurueckButton(
              label: 'Ergebnisse auswerten und zurück',
              auswertenDerErgebnisse: () =>
                  widget.onErgebnisseAbschliessen(ergebnisse),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
