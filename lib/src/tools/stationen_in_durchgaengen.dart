import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/mein_karten_eintrag.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/tools/logger.util.dart';

class StationenInDurchgaengen extends StatefulWidget {
  final List<Kind> teilnehmer;
  final int anzahlDurchgaenge;
  final Function(Map<Kind, List<int>>) onErgebnisseAbschliessen;
  final Widget iconWidget;

  /// Wird aufgerufen, wenn der Nutzer eine laufende Durchgangsserie über
  /// die Zurück-Bestätigung abbricht, OHNE dass onErgebnisseAbschliessen
  /// je aufgerufen wurde. Die aufrufende Station nutzt dies typischerweise,
  /// um einen "wertungWirdVerarbeitet"-Sperrzustand zurückzusetzen, der
  /// sonst dauerhaft hängen bliebe (siehe MyStopUhr.onAbgebrochen).
  final VoidCallback? onAbgebrochen;

  const StationenInDurchgaengen({
    super.key,
    required this.teilnehmer,
    required this.anzahlDurchgaenge,
    required this.onErgebnisseAbschliessen,
    required this.iconWidget,
    this.onAbgebrochen,
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
  final Set<Kind> vollstaendigFertig =
      {}; // ← NEU: dauerhaft, nicht pro Durchgang geleert
  List<Kind> teilnehmerReihenfolge = [];

  Kind? aktivBearbeitetesKind;
  int selectedValue = 1;

  final log = getLogger();

  late int anzahlDurchgaenge;
  late Widget iconWidget;
  late Function(Map<Kind, List<int>>) onErgebnisseAbschliessen;

  // Wird true, sobald mindestens ein Wert bestätigt wurde -> ab dann
  // würde ein Verlassen echten Fortschritt vernichten.
  bool _hatFortschritt = false;
  bool alleBearbeitet() => bearbeitet.length == teilnehmerReihenfolge.length;

  // Wird true gesetzt, nachdem der Nutzer das Verlassen im Dialog
  // bestätigt hat ODER wenn der reguläre Abschluss-Button gedrückt wurde
  // -> lässt den (nächsten) Pop-Versuch tatsächlich durch.
  bool _erzwingeVerlassen = false;

  bool get _kannGefahrlosVerlassenWerden =>
      _erzwingeVerlassen || !_hatFortschritt;

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
            'Es wurden bereits Werte erfasst. Beim Verlassen gehen diese verloren.'),
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

    if (bestaetigt == true && mounted) {
      // Caller benachrichtigen, BEVOR gepoppt wird -> der Reset des
      // Sperrzustands passiert noch auf dieser (noch existierenden) Seite,
      // unabhängig vom Navigator-Timing.
      widget.onAbgebrochen?.call();
      setState(() => _erzwingeVerlassen = true);
      Navigator.of(context).pop();
    }
  }

  void _bestaetigeWert() {
    if (aktivBearbeitetesKind == null) return;

    setState(() {
      _hatFortschritt = true;
      aktuellerWert[aktivBearbeitetesKind!] = selectedValue;
      ergebnisse[aktivBearbeitetesKind!]![aktuellerDurchgang - 1] =
          selectedValue;
      bearbeitet.add(aktivBearbeitetesKind!);
      // NEU: Wenn dies der letzte Durchgang war, ist das Kind endgültig fertig
      if (aktuellerDurchgang == anzahlDurchgaenge) {
        vollstaendigFertig.add(aktivBearbeitetesKind!);
      }

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
                      'Zonen 1 bis 6 \n${aktivBearbeitetesKind!.vorname} ${aktivBearbeitetesKind!.nachname}',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    SliderTheme(
                      data: SliderThemeData(
                        showValueIndicator:
                            ShowValueIndicator.onDrag, // ← IMMER anzeigen
                      ),
                      child: Slider(
                        value: selectedValue.toDouble(),
                        min: 1,
                        max: 6,
                        divisions: 5,
                        label: 'Zone $selectedValue',
                        onChanged: (double value) {
                          setState(() {
                            selectedValue = value.toInt();
                          });
                        },
                      ),
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
                  final istBearbeitet = bearbeitet.contains(kind);
                  final istFertig = vollstaendigFertig.contains(kind); // ← NEU

                  return MeinKartenEintrag(
                    key: ValueKey(kind),
                    trailingFullWidth: true,
//                    istAusgewertet: istBearbeitet,
                    trailing: Tooltip(
                      message: istFertig
                          ? 'Alle Durchgänge für dieses Kind sind abgeschlossen.'
                          : 'Nachdem die erzielten Punkte erfasst und bestätigt wurden, wird der Teilnehmer an das Ende der Liste verschoben.',
                      child: InkWell(
                        onTap: istFertig
                            ? null
                            : () {
                                setState(() {
                                  aktivBearbeitetesKind = kind;
                                  selectedValue = 1;
                                });
                              },
                        child: Center(
                          child: istFertig
                              ? const Icon(Icons.check,
                                  color: Colors.green, size: 40)
                              : istBearbeitet
                                  ? const Icon(Icons.check,
                                      color: Colors.orange,
                                      size:
                                          40) // optischer Unterschied: "diese Runde erledigt" vs. "endgültig fertig"
                                  : SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: iconWidget, // ← Bild-Icon
                                    ),
                        ),
                      ),
                    ),
                    child: ListTile(
                      title: Text('${kind.vorname} ${kind.nachname}'),
                      subtitle: Text(
                          'Bisher erreicht: ${ergebnisse[kind]!.join(' | ')}'),
                    ),
                  );
                },
              ),
            ),
            if (aktuellerDurchgang == anzahlDurchgaenge && alleBearbeitet())
              ZurueckButton(
                label: 'Ergebnisse auswerten und zurück',
                auswertenDerErgebnisse: () {
                  // WICHTIG: den bevorstehenden Pop freigeben, BEVOR
                  // ZurueckButton ihn auslöst. Sonst würde auch der
                  // normale, gewollte Abschluss fälschlich als Abbruch
                  // erkannt und der Bestätigungsdialog gezeigt.
                  setState(() => _erzwingeVerlassen = true);
                  onErgebnisseAbschliessen(ergebnisse);
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
