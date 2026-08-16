import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/mein_karten_eintrag.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/tools/logger.util.dart';

class VersucheInDurchgaengen extends StatefulWidget {
  final List<Kind> teilnehmer;
  final int anzahlVersuche;
  final Function(Map<Kind, int>) onErgebnisseAbschliessen;
  final Widget iconWidget;

  /// Wird aufgerufen, wenn der Nutzer eine laufende Durchgangsserie über
  /// die Zurück-Bestätigung abbricht, OHNE dass onErgebnisseAbschliessen
  /// je aufgerufen wurde. Die aufrufende Station nutzt dies typischerweise,
  /// um einen "wertungWirdVerarbeitet"-Sperrzustand zurückzusetzen, der
  /// sonst dauerhaft hängen bliebe (siehe StationenInDurchgaengen.onAbgebrochen
  /// bzw. MyStopUhr.onAbgebrochen).
  final VoidCallback? onAbgebrochen;

  const VersucheInDurchgaengen({
    super.key,
    required this.teilnehmer,
    required this.anzahlVersuche,
    required this.onErgebnisseAbschliessen,
    required this.iconWidget,
    this.onAbgebrochen,
  });

  @override
  State<VersucheInDurchgaengen> createState() =>
      _VersucheInDurchgaengenWidgetState();
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

  // Wird true, sobald mindestens ein Versuch bestätigt wurde -> ab dann
  // würde ein Verlassen echten Fortschritt vernichten.
  bool _hatFortschritt = false;

  // Wird true gesetzt, nachdem der Nutzer das Verlassen im Dialog
  // bestätigt hat ODER wenn der reguläre Abschluss-Button gedrückt wurde
  // -> lässt den (nächsten) Pop-Versuch tatsächlich durch.
  bool _erzwingeVerlassen = false;

  bool get _kannGefahrlosVerlassenWerden =>
      _erzwingeVerlassen || !_hatFortschritt;

  Future<void> _handlePopVersuch(BuildContext context) async {
    if (_kannGefahrlosVerlassenWerden) {
      // Nichts zu verlieren -> ohne Rückfrage verlassen. Trotzdem über
      // denselben expliziten Navigator.pop()-Pfad wie im bestätigten Fall,
      // NICHT über canPop:true/Plattform-Navigation direkt -- nur so ist
      // garantiert, dass onAbgebrochen zuverlässig aufgerufen wird und
      // Navigator.push(...).then() im aufrufenden Mixin sicher feuert.
      widget.onAbgebrochen?.call();
      if (!mounted) return;
      setState(() => _erzwingeVerlassen = true);
      Navigator.of(context).pop();
      return;
    }
    await _zeigeVerlassenBestaetigung(context);
  }

  Future<void> _zeigeVerlassenBestaetigung(BuildContext context) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Durchgänge abbrechen?'),
        content: const Text(
            'Es wurden bereits Versuche erfasst. Beim Verlassen gehen diese verloren.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Weiter erfassen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Verlassen und neu starten'),
          ),
        ],
      ),
    );

    if (bestaetigt != true) return;
    if (!context.mounted) return;

    // Caller benachrichtigen, BEVOR gepoppt wird -> der Reset des
    // Sperrzustands passiert noch auf dieser (noch existierenden) Seite,
    // unabhängig vom Navigator-Timing.
    widget.onAbgebrochen?.call();
    setState(() => _erzwingeVerlassen = true);
    Navigator.of(context).pop();
  }

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

  bool alleKinderHabenGleichvieleVersucheUndMindestensEinen(
      Map<Kind, List<String>> versucheImDurchgang) {
    if (versucheImDurchgang.isEmpty) return false;
    // values: jeweils die Liste der Versuche für jedes Kind
    // map: Länge der Liste der Versuche für jedes Kind = anzahl der Versuche
    // toSet: wandelt die Längen in eine Menge der verschiedenen Längen ...
    final anzahlVersuche =
        versucheImDurchgang.values.map((liste) => liste.length).toSet();
    // ... und prüft, ob es nur eine anzahlVersuche gibt (Länge des Sets ist 1) und diese anzahlVersuche größer als 0 ist
    return anzahlVersuche.length == 1 && anzahlVersuche.first > 0;
  }

  void _bestaetigeWert() {
    if (aktivBearbeitetesKind == null) return;

    setState(() {
      _hatFortschritt = true;
      // WENN der Status des aktuellen Versuchs "überquert" (egal in welchem Versuch),
      if (versuchStatus == 'überquert') {
        // wird der Punktestand um 1 erhöht, ...
        punktestand[aktivBearbeitetesKind!] =
            (punktestand[aktivBearbeitetesKind!] ?? 0) + 1;
        // die Versuchsstati des aktuellen Versuchs zurück gesetzt, ...
//        versucheImDurchgang[aktivBearbeitetesKind!]= [];
        // und das Kind in die Liste weitererDurchgang verschoben...
        weitererDurchgang.add(aktivBearbeitetesKind!);
        // sowie aus aktuellerDurchgang entfernt
        aktuellerDurchgang.remove(aktivBearbeitetesKind);
        // SONST WENN handelt es sich bereits um den letzen Versuch im aktuellen Durchgang
      } else if (versuchStatus == 'gerissen' &&
          zaehlerVersuch == widget.anzahlVersuche) {
        // das Kind hat bisher nur den Status "gerissen" erreicht,
        // wird das Kind in die Liste stationBendet verschoben...
        stationBeendet.add(aktivBearbeitetesKind!);
        // sowie aus aktuellerDurchgang entfernt
        aktuellerDurchgang.remove(aktivBearbeitetesKind);
        // SONST das aktiv bearbeitete Kind wird, im aktuellenDurchgang, für den nächsten Versuch ans Ende der Liste verschoben
      } else {
        // das Kind hat gerissen; Status im aktuellen Versuch auf "gerissen" setzen
        aktuellerDurchgang.remove(aktivBearbeitetesKind);
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
        } else if (weitererDurchgang.isNotEmpty) {
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

  // die Station ist abgeschlossen, wenn alle Kinder der Riege in durchgangBeendet verschoben wurden,
  // d.h. alle Kinder haben in einem Durchgang in jedem Versuch den Status "gerissen" erreicht
  bool _stationAbgeschlossen() =>
      stationBeendet.length == widget.teilnehmer.length;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // IMMER false: jeder Pop-Versuch (Browser-Zurück, System-Geste,
      // AppBar-Pfeil) läuft dadurch zwingend über _handlePopVersuch() und
      // damit über einen expliziten Navigator.pop() -- nicht über
      // Plattform-Navigation außerhalb von Flutters Navigator. Das ist
      // nötig, damit Navigator.push(...).then() im aufrufenden
      // StopUhrAuswertungMixin zuverlässig feuert, auch bevor die Uhr
      // gestartet wurde (siehe _handlePopVersuch für den ungefragten Pop).
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return; // Pop wurde bereits zugelassen -> nichts zu tun
        _handlePopVersuch(context);
      },
      child: Scaffold(
        appBar: MeineAppBar(
          titel:
              '$zaehlerDurchgang. Höhe -- $zaehlerVersuch. Versuch von ${widget.anzahlVersuche}',
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
                          foregroundColor: versuchStatus == 'gerissen'
                              ? Colors.red
                              : Colors.indigo,
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
                          foregroundColor: versuchStatus == 'überquert'
                              ? Colors.green
                              : Colors.indigo,
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
                      (kind) => MeinKartenEintrag(
                        istSelektiert: aktivBearbeitetesKind == kind,
                        trailingFullWidth: true,
                        onTap: aktivBearbeitetesKind != kind
                            ? () {
                                setState(() {
                                  aktivBearbeitetesKind = kind;
                                });
                              }
                            : null,
                        trailing: SizedBox(
                          width: 40,
                          height: 40,
                          child: widget.iconWidget,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${kind.vorname} ${kind.nachname}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'bisher geschaffte Höhe: ${punktestand[kind]}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // konvertiert das Iterable (von ListTile) zurück in eine List<Widget> als erwartetes Format
                    )
                    .toList(),
              ),
            ),
            if (_stationAbgeschlossen())
              ZurueckButton(
                label: 'Ergebnisse auswerten und zurück',
                auswertenDerErgebnisse: () {
                  // WICHTIG: den bevorstehenden Pop freigeben, BEVOR
                  // ZurueckButton ihn auslöst. Sonst würde auch der
                  // normale, gewollte Abschluss fälschlich als Abbruch
                  // erkannt und der Bestätigungsdialog gezeigt.
                  setState(() => _erzwingeVerlassen = true);
                  widget.onErgebnisseAbschliessen(punktestand);
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
