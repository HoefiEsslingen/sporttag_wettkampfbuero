import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sporttag/src/hilfs_widgets/kinder_bestaetigen_dialog.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/tools/sporttag_config.dart';
// import 'package:sporttag/src/tools/sporttag_config.dart';

import 'klassen/kind_klasse.dart';
import 'tools/kind_repository.dart';

class AnmeldenVorher extends StatefulWidget {
  const AnmeldenVorher({super.key, this.title});
  final String? title;

  /// Aktivität vorbereiten
  @override
  AnmeldenVorherState createState() => AnmeldenVorherState();
}

class AnmeldenVorherState extends State<AnmeldenVorher> {
  /// Systemvariable verwendet
  final _formKey = GlobalKey<FormState>();
  late KindRepository kindRepository;
  late FocusNode myFocusNode;
  late List<int> _jahrgangListe;
  late int _jahrgang;
  late SporttagConfig config;

  /// Controller für die TextFormField-Widgets
  final _vorName = TextEditingController();
  final _nachName = TextEditingController();
  static const List<String> _geschlechtListe = ['w', 'm'];
  String _geschlecht = _geschlechtListe.first;

  @override
  void initState() {
    super.initState();
    // Konfiguration laden und Startroute bestimmen
    // final config = await SporttagConfig.laden();
    // final startRoute = switch (config.routeEntscheiden()) {
    //   RouteEntscheidung.vorabAnmeldung => 'vorabAnmeldung',
    //   RouteEntscheidung.wettkampfbuero => 'home',
    // };
    myFocusNode = FocusNode();
    kindRepository = KindRepository();
    // Zugriff über context.read, da initState synchron ist
    config = context.read<SporttagConfig>();

    _jahrgang = _zulaessigeJahrgaenge(config).first;
  }

  List<int> _zulaessigeJahrgaenge(SporttagConfig config) {
    // Die Logik um die zulässigen Jahrgänge zu bestimmen:
    // basierend auf dem aktuellen Datum und dem festegelegten minAlter bzw. maxAlter
    // wird die Liste der zulässigen Jahrgänge erstellt.
    int currentYear = DateTime.now().year;
    int maxAlter = config.kindAlterMax;
    int minAlter = config.kindAlterMin;
    // int maxAlter = 14; // Maximales Alter für die Anmeldung
    // int minAlter = 3; // Minimales Alter für die Anmeldung
    _jahrgangListe = [];
    for (int i = minAlter; i <= maxAlter; i++) {
      _jahrgangListe.add(currentYear - i);
    }
    _jahrgangListe
        .sort((a, b) => b.compareTo(a)); // Jahrgänge absteigend sortieren
    return _jahrgangListe;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: MeineAppBar(titel: 'Vorab - Anmeldung Sporttag'),
        body: Center(
          child: SingleChildScrollView(
            // ein Formular erstellen
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 32.0),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16.0,
                        ),
                        children: <TextSpan>[
                          const TextSpan(
                            text: 'Herzlich Willkommen\n',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 26.0,
                            ),
                          ),
                          TextSpan(
                            text: '\nHier können Sie Ihr Kind\n'
                                '(im Alter zwischen ${config.kindAlterMin} und ${config.kindAlterMax} Jahren)\n'
                                'vorab für den Sporttag anmelden.\n'
                                'Kinder in Alter bis ${config.fuenfkampfMaxAlter} Jahre absolvieren fünf,\n'
                                'die älteren zehn  Disziplinen.\n\n'
                                'Am Sporttag selbst bezahlen Sie lediglich noch\n'
                                'die Startgebühr von € ${config.gebuehr.toStringAsFixed(2).replaceAll('.', ',')},\n'
                                'damit die Anmeldung aktiv wird.\n',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    // Eingabefeld für den Vornamen
                    TextFormField(
                      controller: _vorName,
                      focusNode: myFocusNode,
                      autofocus: true,
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Vorname',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Bitte einen Vornamen eingeben';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Eingabefeld für den Nachnamen
                    TextFormField(
                      controller: _nachName,
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Nachname',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Bitte einen Nachnamen eingeben';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Auswahl-Menü für das Geschlecht
                    DropdownButtonFormField<String>(
                      initialValue: _geschlecht,
                      onChanged: (newValue) =>
                          setState(() => _geschlecht = newValue!),
                      items: [
                        for (String i in _geschlechtListe)
                          DropdownMenuItem(
                            value: i,
                            child: Text(i),
                          )
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Geschlecht',
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Auswahl-Menü für den Jahrgang
                    DropdownButtonFormField<int>(
                      initialValue: _jahrgang,
                      onChanged: (newValue) =>
                          setState(() => _jahrgang = newValue!),
                      items: [
                        for (int i in _jahrgangListe)
                          DropdownMenuItem(
                            value: i,
                            child: Text('$i'),
                          )
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Jahrgang',
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        // Button um die Eingaben rückgängig zu machen, d.h. die Felder zu leeren,
                        // um neue, korrekte Eingaben machen zu können und den Fokus wieder auf das erste Eingabefeld zu setzen.
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () {
                            // reset() setzt alle Felder wieder auf den Initalwert zurück.
                            resetFelder();
                            myFocusNode.requestFocus();
                          },
                          child: const Text('Löschen'),
                        ),
                        const SizedBox(width: 25),
                        // Button um die Eingaben zu speichern.
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.green,
                          ),
                          onPressed: () async {
                            // Wenn alle Validatoren der Felder des Formulars gültig sind.
                            if (_formKey.currentState!.validate()) {
                              if (kDebugMode) {
                                print(
                                    "Formular ist gültig und kann verarbeitet werden");
                              }
                              // Vor dem eigentlichen Speichern die Eingaben noch
                              // einmal zur Bestätigung anzeigen.
                              await pruefeUndSpeichere();
                              // doSaveData();
                              // // Namensfelder leeren und Fokus zurücksetzen
                              // resetFelder();
                              // myFocusNode.requestFocus();
                            } else {
                              if (kDebugMode) {
                                print("Formular ist nicht gültig");
                              }
                            }
                          },
                          child: const Text('Speichern'),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  /// Zeigt den Bestätigungsdialog mit den erfassten Angaben an. Nur wenn der
  /// Anwender bestätigt, wird tatsächlich gespeichert; bei Abbruch kommt der
  /// Anwender zurück zum (noch ausgefüllten) Eingabeformular.
  Future<void> pruefeUndSpeichere() async {
    final vorschauKind = Kind(
      vorname: _vorName.text.trim(),
      nachname: _nachName.text.trim(),
      jahrgang: _jahrgang,
      geschlecht: _geschlecht,
      bezahlt: false,
    );

    final bestaetigt = await KinderBestaetigenDialog.zeigen(
      context: context,
      kinder: [vorschauKind],
      titel: 'Anmeldung bestätigen',
      hinweisText: 'Soll diese Person tatsächlich angemeldet werden?',
      bestaetigenText: 'Ja, anmelden',
      abbrechenText: 'Abbrechen',
    );

    if (!bestaetigt) {
      // Anwender möchte die Angaben noch korrigieren -> zurück zum Formular,
      // die bereits eingegebenen Werte bleiben erhalten.
      return;
    }

    await doSaveData(vorschauKind);
    // Namensfelder leeren und Fokus zurücksetzen
    resetFelder();
    myFocusNode.requestFocus();
  }

  Future<void> doSaveData(Kind neuAngemeldet) async {
    // Kind neuAngemeldet = Kind(
    //   vorname: _vorName.text.trim(),
    //   nachname: _nachName.text.trim(),
    //   jahrgang: _jahrgang,
    //   geschlecht: _geschlecht,
    //   bezahlt: false,
    // );
    if (await kindRepository.saveKind(kind: neuAngemeldet)) {
      showSuccess();
    } else {
      showError(
          "Die Anmeldung Ihres Kindes war nicht erfolgreich. Bitte versuchen Sie es später erneut.");
    }
  }

  void showSuccess() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Anmeldung erfolgreich!"),
          content: const Text(
              "Ihr Kind ist hiermit für den Sporttag registriert!\nGültig wird die Anmeldung erst, wenn Sie am Sporttag die Startgebühr von € 2,50 bezahlt haben."),
          actions: <Widget>[
            Row(children: [
              Expanded(
                child: TextButton(
                  child: const Text("Fertig"),
                  onPressed: () {
                    Navigator.of(context).popAndPushNamed('dankeschoen');
                  },
                ),
              ),
              Expanded(
                child: TextButton(
                  child: const Text("Weitere Anmeldung"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ])
          ],
        );
      },
    );
  }

  void showError(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Fehler beim Speichern!"),
          content: Text(errorMessage),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void resetFelder() {
    _vorName.text = "";
    _nachName.text = "";
  }
}
