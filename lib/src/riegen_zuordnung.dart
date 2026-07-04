import 'package:sporttag/src/tools/riegen_repository.dart';

import 'hilfs_widgets/meine_appbar.dart';
import 'klassen/riegen_klasse.dart';
import 'tools/logger.util.dart';
import 'package:flutter/material.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/tools/kind_repository.dart';
import 'package:qr_flutter/qr_flutter.dart';

//import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class RiegenZuordnung extends StatefulWidget {
  const RiegenZuordnung({super.key, required this.titel});
  final String? titel;

  /// Aktivität vorbereiten
  @override
  RiegenZuordnungState createState() => RiegenZuordnungState();
}

class RiegenZuordnungState extends State<RiegenZuordnung> {
  final KindRepository kindRepository = KindRepository(); // Repository-Objekt
  final RiegenRepository riegeRepository = RiegenRepository();
  List<Riege> alleRiegen = []; // Liste aller Riegen
  List<Kind> alleKinder = [];
  final int riegenAnzahl = 8;
  List<int> riegenListe = [];
  int? ausgewaehlteRiegenNummer;
  List<Kind> gefilterteKinder = [];
  String? wettbewerb;
  String qrCodeUrl =
      ''; //= 'https://gs-gp.eu'; // Platzhalter für die URL des QR-Codes
  // Logger einrichten
  final log = getLogger();

  @override
  void initState() {
    super.initState();
    riegenListe = List.generate(riegenAnzahl, (index) => index + 1);
    // Lädt die Riegen aus der Datenbank
    ladeRiegen();
  }

  Future<void> ladeRiegen() async {
    alleRiegen = await riegeRepository.ladeAlleRiegen();
  }

  // Methode für die Anzeige der einzelnen Riege
  Future<void> _filterKinderNachRiege(int riegenNummer) async {
    alleKinder = await kindRepository.ladeAlleKinder();
   if (!mounted) return; // Widget bereits disposed → abbrechen
   setState(() {
      gefilterteKinder = alleKinder
          .where((kind) => kind.riegenNummer == riegenNummer)
          .toList()
        // sortiert die Kinder nach Geschlecht unnerhalb des gleichen Jahrgangs
        ..sort((a, b) {
          int jahrgangsVergleich = b.jahrgang.compareTo(a.jahrgang);
          if (jahrgangsVergleich != 0) {
            // gleicher Jahrgang
            return jahrgangsVergleich;
          }
          return b.geschlecht.compareTo(a.geschlecht);
        });
    });
  }

  String _updateQrCodeUrl() {
    if (ausgewaehlteRiegenNummer != null) {
      // Wettbewerb für ausgewählte Riege bestimmen
      for (var riege in alleRiegen) {
        if (riege.riegenNummer == ausgewaehlteRiegenNummer) {
          wettbewerb = riege.fuenfKampf ? 'Fuenfkampf' : 'Zehnkampf';
          break;
        }
      }
      qrCodeUrl =
          'https://hoefiesslingen.github.io/#/wettkampf/$ausgewaehlteRiegenNummer/$wettbewerb'; //?wettbewerb=$wettbewerb';
    } else {
      qrCodeUrl = '';
    }
    return qrCodeUrl;
  }

  void _entferneRiegeAusDropDownListe() {
    if (ausgewaehlteRiegenNummer != null) {
      setState(() {
        riegenListe.remove(
            ausgewaehlteRiegenNummer); // Entfernt die ausgewählte Riege aus der Liste
        ausgewaehlteRiegenNummer = null; // Setzt die Auswahl zurück
        gefilterteKinder.clear(); // Löscht die Liste der angezeigten Kinder
        qrCodeUrl =
            ''; // Kommentar entfernen, wenn Qr-Code generiert werden kann
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(titel: widget.titel ?? 'Riegen Zuordnung', thema: 'Riegen Zuordnung'),
      body: Center(
        child: Column(
          children: [
            Padding(
              // ein Widget, um leeren Raum um ein inneres Widget zu schaffen
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButton<int>(
                    hint: const Text('Wähle eine Riege'),
                    value: ausgewaehlteRiegenNummer,
                    items: riegenListe.map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('Riege $value'),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        ausgewaehlteRiegenNummer = newValue;
                      });
                      if (newValue != null) {
                        _filterKinderNachRiege(newValue);
                        // Aktualisiert die URL des QR-Codes
                        _updateQrCodeUrl();
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ListView.builder(
                        itemCount: gefilterteKinder.length,
                        itemBuilder: (context, index) {
                          final kind = gefilterteKinder[index];
                          return ListTile(
                            title: Text(
                                '${kind.vorname} ${kind.nachname} ${kind.jahrgang} ${kind.geschlecht}'),
                          );
                        },
                      ),
                    ),
                    // Rechte Spalte: QR-Code
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (ausgewaehlteRiegenNummer != null) ...[
                            QrImageView(
                              data:
                                  _updateQrCodeUrl(), // hier muss eine Methode hin, die einen QR-Code generiert abhängig von der Riege
                              version: QrVersions.auto,
                              size: 200.0,
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () {
                                _entferneRiegeAusDropDownListe();
                                if (riegenListe.isEmpty) {
                                  Navigator.pop(context, false);
                                }
                              },
                              child: Text(
                                "Riege Nr. ${ausgewaehlteRiegenNummer ?? ''}\n${wettbewerb == "Fuenfkampf" ? 5 : 10} Disziplinen",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
