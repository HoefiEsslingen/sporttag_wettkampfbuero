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
          // Anmeldung abschalten, Riegenzuordnung aktivieren
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
                  seitenInfo['anmeldeSeite']!['aktiv']
                      ? navigateAndPossiblyDisableButton(
                          zuSeite: 'anmeldeSeite')
                      : null;
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
