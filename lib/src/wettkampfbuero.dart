import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/icon_widget.dart';
import 'package:sporttag/src/tools/sporttag_config.dart';

class Wettkampfbuero extends StatefulWidget {
  const Wettkampfbuero({super.key});

  /// Aktivität vorbereiten
  @override
  WettkampfbueroState createState() => WettkampfbueroState();
}

class WettkampfbueroState extends State<Wettkampfbuero> {
  late SporttagConfig config;
  Map<String, Map<String, dynamic>> seitenInfo = {
    'anmeldeSeite': {
      'iconColor': Colors.white,
      'aktiv': true,
    },
    'riegenEinteilung': {
      'iconColor': Colors.white,
      'aktiv': true,
    },
    'riegenZuordnung': {
      'iconColor': Colors.grey,
      'aktiv': false,
    },
    'auswertung': {
      'iconColor': Colors.grey,
      'aktiv': false,
    },
  };
 @override
  void initState() {
    super.initState();
    // Zugriff über context.read, da initState synchron ist
    config = context.read<SporttagConfig>();
  }
// Methode, die Status von gerufender Seite zurückgibt
// kommt 'false' zurück, dann wird der entsprechende aufrufende Button disabled
  Future<void> navigateAndPossiblyDisableButton(
      {required String zuSeite}) async {
    var resultat = await Navigator.pushNamed(context, zuSeite);

    if (!mounted) return; // Widget bereits disposed → abbrechen

    setState(() {
      if (resultat == false) {
        // aktuelle Seite inaktiv setzen
        seitenInfo[zuSeite]!['iconColor'] = Colors.grey;
        seitenInfo[zuSeite]!['aktiv'] = false;
      }

      // Lineare Fortschaltung
      switch (zuSeite) {
        case 'riegenEinteilung':
          // Riegeneinteilung abgeschlossen: eigenen Button abschalten
          // (Anmeldung ist danach eigentlich vorbei, siehe Nachmeldung
          // weiter unten), Riegenzuordnung freischalten.
          seitenInfo['riegenEinteilung']!
            ..['iconColor'] = Colors.grey
            ..['aktiv'] = false;
          seitenInfo['anmeldeSeite']!
            ..['iconColor'] = Colors.grey
            ..['aktiv'] = false;
          seitenInfo['riegenZuordnung']!
            ..['iconColor'] = Colors.white
            ..['aktiv'] = true;
          break;

        case 'riegenZuordnung':
          // Auswertung freischalten
          seitenInfo['auswertung']!
            ..['iconColor'] = Colors.white
            ..['aktiv'] = true;
          break;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Nachmeldung nach bereits durchgeführter Riegeneinteilung
  //
  // Regulär ist die Anmeldeseite nach der Riegeneinteilung deaktiviert.
  // In der Praxis kommt es trotzdem vor, dass noch ein Kind nachgemeldet
  // werden muss (z. B. Restarter geändert eine Situation vor Ort). Das wird
  // hier zugelassen, aber nur nach ausdrücklicher Bestätigung – und im
  // Anschluss wird automatisch erneut die Riegeneinteilung angestoßen,
  // damit das nachgemeldete Kind einer bestehenden Riege zugeteilt wird
  // (siehe Bestandsschutz-Logik in RiegenEinteilung).
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _nachmeldungBestaetigenUndStarten() async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nachmeldung nach Riegeneinteilung'),
        content: const Text(
          'Die Riegeneinteilung wurde bereits durchgeführt. Eine Nachmeldung '
          'ist danach eigentlich nicht mehr vorgesehen.\n\n'
          'Wird trotzdem fortgefahren, wird im Anschluss automatisch erneut '
          'die Riegeneinteilung gestartet, damit das nachgemeldete Kind '
          'einer Riege zugeteilt wird.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Trotzdem fortfahren'),
          ),
        ],
      ),
    );

    if (bestaetigt != true || !mounted) return;

    // Nachmeldung öffnen – bewusst bestätigt, daher unabhängig vom
    // aktiv-Status der Anmeldeseite.
    await navigateAndPossiblyDisableButton(zuSeite: 'anmeldeSeite');

    if (!mounted) return;

    // Automatisch erneut die Riegeneinteilung anstoßen, damit das
    // nachgemeldete Kind einer bestehenden Riege zugeteilt wird.
    await navigateAndPossiblyDisableButton(zuSeite: 'riegenEinteilung');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(titel: 'Wettkampf-Büro'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16.0,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text:
                            'Hier erfolgen die Bezahlung der Vorab-Anmeldungen sowie\ndie Nachmeldungen.\n',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 26.0,
                        ),
                      ),
                      TextSpan(
                        text:
                            '''\nFür die vorabangemeldeten Kinder müssen noch\ndie Startgebühr von € ${config.gebuehr.toStringAsFixed(2).replaceAll('.', ',')} bezahlt werden.\nNach Abschluss der Anmeldung werden die Riegen automaiisch eingeteilt.\nHier erscheint dann eine Kontrollausgabe.\nAm Ende des Tages erfolgt die Auswertung und der Urkundendruck.\n''',
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  if (seitenInfo['anmeldeSeite']!['aktiv']) {
                    navigateAndPossiblyDisableButton(zuSeite: 'anmeldeSeite');
                  } else {
                    // Anmeldeseite ist nach der Riegeneinteilung eigentlich
                    // gesperrt – eine Nachmeldung ist aber mit Bestätigung
                    // weiterhin möglich (siehe _nachmeldungBestaetigenUndStarten).
                    _nachmeldungBestaetigenUndStarten();
                  }
                },
                icon: KartenIcon(
                  key: UniqueKey(),
                  icon: Icons.edit_note,
                  color: seitenInfo['anmeldeSeite']!['iconColor'],
                  derText: 'Anmeldung',
                ),
              ),
              IconButton(
                onPressed: () => seitenInfo['riegenEinteilung']!['aktiv']
                    ? navigateAndPossiblyDisableButton(
                        zuSeite: 'riegenEinteilung')
                    : null,
                icon: KartenIcon(
                  key: UniqueKey(),
                  icon: Icons.format_list_numbered,
                  color: seitenInfo['riegenEinteilung']!['iconColor'],
                  derText: 'Riegen einteilen',
                ),
              ),
              IconButton(
                onPressed: () => seitenInfo['riegenZuordnung']!['aktiv']
                    ? navigateAndPossiblyDisableButton(
                        zuSeite: 'riegenZuordnung')
                    : null,
                icon: KartenIcon(
                  key: UniqueKey(),
                  icon: Icons.arrow_circle_right,
                  color: seitenInfo['riegenZuordnung']!['iconColor'],
                  derText: 'Riegen den Riegenführern zuordnen',
                ),
              ),
              IconButton(
                onPressed: () => seitenInfo['auswertung']!['aktiv']
                    ? navigateAndPossiblyDisableButton(zuSeite: 'auswertung')
                    : null,
                icon: KartenIcon(
                  key: UniqueKey(),
                  icon: Icons.list_alt,
                  color: seitenInfo['auswertung']!['iconColor'],
                  derText: 'Auswertung',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
