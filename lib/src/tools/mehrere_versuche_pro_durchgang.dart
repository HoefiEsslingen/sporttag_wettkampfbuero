import 'package:flutter/material.dart';
import '../hilfs_widgets/rueck_sprung_button.dart';
import '../hilfs_widgets/meine_appbar.dart';
import '../klassen/kind_klasse.dart';
import 'logger.util.dart';

class VersucheInDurchgaengen extends StatefulWidget {
  final List<Kind> teilnehmer;
  final int anzahlVersuche;
  final Function(Map<Kind, int>) onErgebnisseAbschliessen;
  final Widget iconWidget;

  const VersucheInDurchgaengen({
    super.key,
    required this.teilnehmer,
    required this.anzahlVersuche,
    required this.onErgebnisseAbschliessen,
    required this.iconWidget,
  });

  @override
  State<VersucheInDurchgaengen> createState() => _VersucheInDurchgaengenWidgetState();
}

class _VersucheInDurchgaengenWidgetState extends State<VersucheInDurchgaengen> {
  final Map<Kind, int> punktestand = {};
  // Für jedes Kind existiert eine Liste, Länge = widget.anzahlVersuche.
  // Die Liste enthält den Status des jeweiligen Versuchs: gerissen = 0, überquert = 1
// auskommentiert:  final Map<Kind, List<String>> versucheImDurchgang = {};
  final Set<Kind> weitererVersuch = {};
  // zu Beginn sind alle Kinder im aktuellen Durchgang
  final Set<Kind> aktuellerDurchgang = {};
  // haben sie den Status "überquert" erreicht, werden sie in den weiteren Durchgang verschoben
  final Set<Kind> weitererDurchgang = {};
  // Kinder, die zweimal den Status "gerissen" erreicht haben, werden in diese Liste verschoben
  // und sind aus dem Wettbewerb ausgeschieden
  final Set<Kind> stationBeendet = {};
  int zaehlerDurchgang = 1;
  int zaehlerVersuch = 1;
  Kind? aktivBearbeitetesKind;
  String? versuchStatus;


  final log = getLogger();

  @override
  void initState() {
    super.initState();
    // Teilnehmer in den aktuellen Durchgang hinzufügen
    aktuellerDurchgang.addAll(widget.teilnehmer);
    // Der Punktestand für alle Kinder auf 0 initialisieren
    for (final kind in widget.teilnehmer) {
      punktestand[kind] = 0;
//      versucheImDurchgang[kind] = []; // leere Liste für jeden Teilnehmer
    }
  }

bool alleKinderHabenGleichvieleVersucheUndMindestensEinen(Map<Kind, List<String>> versucheImDurchgang) {
  if (versucheImDurchgang.isEmpty) return false;
  // values: jeweils die Liste der Versuche für jedes Kind
  // map: Länge der Liste der Versuche für jedes Kind = anzahl der Versuche
  // toSet: wandelt die Längen in eine Menge der verschiedenen Längen ...
  final anzahlVersuche = versucheImDurchgang.values.map((liste) => liste.length).toSet();
  // ... und prüft, ob es nur eine anzahlVersuche gibt (Länge des Sets ist 1) und diese anzahlVersuche größer als 0 ist
  return anzahlVersuche.length == 1 && anzahlVersuche.first > 0;
}

  void _bestaetigeWert() {
    if (aktivBearbeitetesKind == null) return;

    setState(() {
      // WENN der Status des aktuellen Versuchs "überquert" (egal in welchem Versuch),
      if(versuchStatus == 'überquert') {
        // wird der Punktestand um 1 erhöht, ...
        punktestand[aktivBearbeitetesKind!] = (punktestand[aktivBearbeitetesKind!] ?? 0) + 1;
        // die Versuchsstati des aktuellen Versuchs zurück gesetzt, ...
//        versucheImDurchgang[aktivBearbeitetesKind!]= [];
        // und das Kind in die Liste weitererDurchgang verschoben...
        weitererDurchgang.add(aktivBearbeitetesKind!);
        // sowie aus aktuellerDurchgang entfernt
        aktuellerDurchgang.remove(aktivBearbeitetesKind);
      // SONST WENN handelt es sich bereits um den letzen Versuch im aktuellen Durchgang
      } else if (versuchStatus == 'gerissen' && zaehlerVersuch == widget.anzahlVersuche) {
        // das Kind hat bisher nur den Status "gerissen" erreicht,
        // wird das Kind in die Liste stationBendet verschoben...
        stationBeendet.add(aktivBearbeitetesKind!);
        // sowie aus aktuellerDurchgang entfernt
        aktuellerDurchgang.remove(aktivBearbeitetesKind);
      // SONST das aktiv bearbeitete Kind wird, im aktuellenDurchgang, für den nächsten Versuch ans Ende der Liste verschoben
      } else {
        // das Kind hat gerissen; Status im aktuellen Versuch auf "gerissen" setzen
//        versucheImDurchgang[aktivBearbeitetesKind!]!.add('gerissen');
        aktuellerDurchgang.remove(aktivBearbeitetesKind);
//        aktuellerDurchgang.add(aktivBearbeitetesKind!);
        weitererVersuch.add(aktivBearbeitetesKind!);
      }
      aktivBearbeitetesKind = null;
      versuchStatus = null;

      // WENN alle Kinder den aktuellen Durchgang absolviert haben,
      if (aktuellerDurchgang.isEmpty) {
        // WENN es einen weiteren Versuch gibt
        if (weitererVersuch.isNotEmpty) {
          // dann werden die Kinder in den aktuellen Durchgang verschoben
          aktuellerDurchgang.addAll(weitererVersuch);
          // und die Liste weitererVersuch geleert
          weitererVersuch.clear();
          // sowie den Versuchszähler zu erhöhen
          zaehlerVersuch++;
        // WENN es einen weiteren Durchgang gibt
        }else if (weitererDurchgang.isNotEmpty) {
          // dann werden die Kinder in den aktuellen Durchgang verschoben
          aktuellerDurchgang.addAll(weitererDurchgang);
          // und die Liste weitererDurchgang geleert
          weitererDurchgang.clear();
          // den Versuchszähler zurücksetzen
          zaehlerVersuch = 1;
        // Durchgangsnummer erhöhen
          zaehlerDurchgang++;
        // SONST ist die Station abgeschlossen
        } else {
          setState(() {}); // <- Das triggert den ZurueckButton im build()
        }
      }
    });
  }

  // Alle Kinder sind in die Liste weitererDurchgang verschoben worden
  // bzw die Liste aktuellerDurchgang ist leer
/*
  void _naechsterVersuch(Kind kind, bool ueberquert) {
    final versuche = versucheImDurchgang[kind] ?? 0;

    if (ueberquert) {
      punktestand[kind] = (punktestand[kind] ?? 0) + 1;
      weitererDurchgang.add(kind);
    } else {
      if (versuche == 1) {
        durchgaengeBeendet.add(kind);
      } else {
        versucheImDurchgang[kind] = versuche + 1;
        aktuellerDurchgang.add(kind);
        return;
      }
    }

//    versucheImDurchgang[kind] = 0;
    aktuellerDurchgang.remove(kind);
    setState(() {
      aktivBearbeitetesKind = null;
//      versuchStatus = null;
    });

    if (aktuellerDurchgang.isEmpty && !_stationBeendetAbgeschlossen     aktuellerDurchgang.addAll(weitererDurchgang);
      weitererDurchgang.clear();
    }
  }
*/
  // die Station ist abgeschlossen, wenn alle Kinder der Riege in durchgangBeendet verschoben wurden,
  // d.h. alle Kinder haben in einem Durchgang in jedem Versuch den Status "gerissen" erreicht
  bool _stationAbgeschlossen() => stationBeendet.length == widget.teilnehmer.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(
        titel: '$zaehlerDurchgang. Höhe -- $zaehlerVersuch. Versuch von ${widget.anzahlVersuche}',
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          if (aktivBearbeitetesKind != null)
            Column(
              children: [
                Text(
                  '${aktivBearbeitetesKind!.vorname} ${aktivBearbeitetesKind!.nachname}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  // Tooggle-Buttons für den Status der Versuche
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[50],
                        foregroundColor: versuchStatus == 'gerissen' ? Colors.red : Colors.indigo,
                      ),
                      onPressed: () {
                        setState(() {
                          versuchStatus = 'gerissen';
                        });
                      },
                      child: const Text('gerissen'),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[50],
                        foregroundColor: versuchStatus == 'überquert' ? Colors.green : Colors.indigo,
                      ),
                      onPressed: () {
                        setState(() {
                          versuchStatus = 'überquert';
                        });
                      },
                      child: const Text('überquert'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: versuchStatus == null
                      ? null
                      : () {
                          _bestaetigeWert();
                        },
                  child: const Text('Bestätigen'),
                ),
                 ],
            ),        
          Expanded(
            // alle Kinder, die ... 
            child: ListView(
              // ... im aktuellen Durchgang sind, werden gelistet, ... 
              children: aktuellerDurchgang
                  // Für jedes kind wird ein ListTile erzeugt (Iterabel von ListTile)
                  .map(
                    (kind) => ListTile(
                      title: Text('${kind.vorname} ${kind.nachname}'),
                      subtitle: Text('bisher geschaffte Höhe: ${punktestand[kind]}'),
                      trailing: IconButton(
                        icon: widget.iconWidget,
                        iconSize: 30,
                        // ... bei Klick des Buttons
                        onPressed: () {
                          setState(() {
                            // ... wird das Kind aktiv und die 
                            aktivBearbeitetesKind = kind;
                          });
                        },
                      ),
                    ),
                  )
                  // konvertiert das Iterable (von ListTile) zurück in eine List<Widget> als erwartetes Format
                  .toList(),
            ),
          ),
          if (_stationAbgeschlossen())
            ZurueckButton(
              label: 'Ergebnisse auswerten und zurück',
              auswertenDerErgebnisse: () =>
                  widget.onErgebnisseAbschliessen(punktestand),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
