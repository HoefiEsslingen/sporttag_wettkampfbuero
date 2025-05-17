import 'package:flutter/material.dart';
//import 'package:qr_flutter/qr_flutter.dart';
import 'package:sporttag/src/kind_repository.dart';

import 'kind_klasse.dart';
import 'logger.util.dart';

class UrkundenDruck extends StatefulWidget {
  const UrkundenDruck({super.key, required this.titel});
  final String? titel;

  /// Aktivität vorbereiten
  @override
  UrkundenDruckState createState() => UrkundenDruckState();
}

class UrkundenDruckState extends State<UrkundenDruck> {
  final KindRepository kindRepository = KindRepository(); // Repository-Objekt
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
  }

  // Methode für die Anzeige der einzelnen Riege
  Future<void> _filterKinderNachRiege(int riegenNummer) async {
    alleKinder = await kindRepository.loadAllKinder();
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
    // Sortiere die Liste absteigend nach erreichtePunkte
    gefilterteKinder
        .sort((a, b) => b.erreichtePunkte.compareTo(a.erreichtePunkte));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titel ?? 'Urkunden Druck'),
      ),
      body: Center(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 72.0),
          children: [
            // Dropdown zur Auswahl der Riegennummer
            DropdownButton<int>(
              hint: const Text('Wähle eine Riege'),
              value: ausgewaehlteRiegenNummer,
              items: List.generate(riegenAnzahl, (index) => index + 1)
                  .map((int value) {
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
                }
              },
            ),
            const SizedBox(height: 16.0),
            // Liste der gefilterten Kinder
            ...gefilterteKinder.map(
              (kind) {
                return ListTile(
                  title: Text(
                      '${kind.vorname} ${kind.nachname} ${kind.jahrgang} ${kind.geschlecht}'),
                  subtitle: Text('erreichte Punkte: ${kind.erreichtePunkte}'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
// Rechte Spalte: QR-Code
/*    
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (ausgewaehlteRiegenNummer != null){

                            QrImageView(
                              data:
                                  _updateQrCodeUrl(), // hier muss eine Methode hin, die einen QR-Code generiert abhängig von der Riege
                              version: QrVersions.auto,
                              size: 200.0,
                            ),

                            //                      const SizedBox(height: 20),
                            TextButton(
                              onPressed: () {
                                _entferneRiegeAusDropDownListe();
                                if (riegenListe.isEmpty) {
                                  Navigator.pop(context, false);
                                }
                              },
                              child: Text(
                                "Riege Nr. ${ausgewaehlteRiegenNummer ?? ''} zugeordnet",
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
*/
