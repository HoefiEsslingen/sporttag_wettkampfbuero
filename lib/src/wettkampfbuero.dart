import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/icon_widget.dart';

class Wettkampfbuero extends StatefulWidget {
  const Wettkampfbuero({super.key});

  /// Aktivität vorbereiten
  @override
  WettkampfbueroState createState() => WettkampfbueroState();
}

class WettkampfbueroState extends State<Wettkampfbuero> {

Map<String , Map<String, dynamic>> seitenInfo = {
  'anmeldeSeite': {
    'iconColor': Colors.white,
    'aktiv': true,
  },
  'riegenEinteilung': {
    'iconColor': Colors.white,
    'aktiv': true,
  },
    'riegenZuordnung': {
    'iconColor': Colors.white,
    'aktiv': true,
  },
  'auswertung': {
    'iconColor': Colors.white,
    'aktiv': true,
  },
};
// Methode, die Status von gerufender Seite zurückgibt
// kommt 'false' zurück, dann wird der entsprechende aufrufende Button disabled
  Future<void> navigateAndPossiblyDisableButton({required String zuSeite}) async {
    var resultat = await Navigator.pushNamed(context, zuSeite);

    if (resultat == false) {
      setState(() {
        seitenInfo[zuSeite]!['iconColor'] = Colors.grey;
        seitenInfo[zuSeite]!['aktiv'] = resultat;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(titel: 'Wettkampf-Büro'),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 16.0,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text:
                          'Hier erfolgen die Anmeldungen und\nBezahlung der Vorab-Anmeldungen.\n',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 26.0,
                      ),
                    ),
                    TextSpan(
                      text:
                          '''\nFür die vorabangemeldeten Kinder müssen noch\ndie Startgebühr von € 2,-- bezahlt werden.\nNach Abschluss der Anmeldung werden die Riegen automaiisch eingeteilt.\nHier erscheint dann eine Kontrollausgabe.\nAm Ende des Tages erfolgt die Auswertung und der Urkundendruck.\n''',
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                seitenInfo['anmeldeSeite']!['aktiv'] ? 
                  navigateAndPossiblyDisableButton(zuSeite: 'anmeldeSeite') : null;
              },
              icon: KartenIcon(
                key: UniqueKey(),
                icon: Icons.edit_note,
                color: seitenInfo['anmeldeSeite']!['iconColor'],
                derText: 'Anmeldung',
              ),
            ),
            IconButton(
              onPressed: () => seitenInfo['riegenEinteilung']!['aktiv'] ? 
                  navigateAndPossiblyDisableButton(zuSeite:'riegenEinteilung') : null,
              icon: KartenIcon(
                key: UniqueKey(),
                icon: Icons.format_list_numbered,
                color: seitenInfo['riegenEinteilung']!['iconColor'],
                derText: 'Riegen einteilen',
              ),
            ),
            IconButton(
              onPressed: () => seitenInfo['riegenZuordnung']!['aktiv'] ? 
                  navigateAndPossiblyDisableButton(zuSeite:'riegenZuordnung') : null,
              icon: KartenIcon(
                key: UniqueKey(),
                icon: Icons.arrow_circle_right,
                color: seitenInfo['riegenZuordnung']!['iconColor'],
                derText: 'Riegen den Riegenführern zuordnen',
              ),
            ),
            IconButton(
              onPressed: () => seitenInfo['auswertung']!['aktiv'] ? 
                  navigateAndPossiblyDisableButton(zuSeite:'auswertung') : null,
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
    );
  }
}
