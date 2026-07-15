import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sporttag/src/hilfs_widgets/kinder_bestaetigen_dialog.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/tools/sporttag_config.dart';

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
  bool _istAmSpeichern = false; // NEU: Sperr-Flag während Prüfen/Speichern

  /// Controller für die TextFormField-Widgets
  final _vorName = TextEditingController();
  final _nachName = TextEditingController();
  static const List<String> _geschlechtListe = ['w', 'm'];
  String _geschlecht = _geschlechtListe.first;

  @override
  void initState() {
    super.initState();
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
    return PopScope(
      canPop: !_istAmSpeichern, // Sperrt das Zurückgehen während des Speicherns
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Die Anmeldung wird gerade verarbeitet – bitte warten.')),
        );
      },
      child: Stack(
        children: [
          Scaffold(
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
                                onPressed: _istAmSpeichern
                                    ? null
                                    : () {
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
                                onPressed: _istAmSpeichern
                                    ? null // während des Speicherns deaktiviert
                                    : () async {
                                        if (_formKey.currentState!.validate()) {
                                          if (kDebugMode) {
                                            print(
                                                "Formular ist gültig und kann verarbeitet werden");
                                          }
                                          setState(
                                              () => _istAmSpeichern = true);
                                          try {
                                            await pruefeUndSpeichere();
                                          } finally {
                                            if (mounted) {
                                              setState(() =>
                                                  _istAmSpeichern = false);
                                            }
                                          }
                                        } else {
                                          if (kDebugMode) {
                                            print("Formular ist nicht gültig");
                                          }
                                        }
                                      },
                                child: const Text('Speichern'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                            onPressed: _istAmSpeichern
                                ? null
                                : () {
                                    resetFelder();
                                    Navigator.of(context)
                                        .pushNamedAndRemoveUntil(
                                      'dankeschoen',
                                      (route) => false,
                                    );
                                  },
                            child: const Text('Abbrechen'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
          if (_istAmSpeichern)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black45,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
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
    if (await kindRepository.saveKind(kind: neuAngemeldet)) {
      showSuccess();
    } else {
      showError(
          "Die Anmeldung Ihres Kindes war nicht erfolgreich. Bitte versuchen Sie es später erneut.");
    }
  }

  void showSuccess() {
    _zeigeGesperrtenDialog(
      AlertDialog(
        title: const Text("Anmeldung erfolgreich!"),
        content: Text('Ihr Kind ist hiermit für den Sporttag registriert!\n'
            'Gültig wird die Anmeldung erst, wenn Sie am Sporttag die Startgebühr von € ${config.gebuehr.toStringAsFixed(2).replaceAll('.', ',')} bezahlt haben.'),
        actions: <Widget>[
          Row(children: [
            Expanded(
              child: TextButton(
                child: const Text("Fertig"),
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    'dankeschoen',
                    (route) => false, // entfernt ALLE vorherigen Routen)
                  );
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
      ),
    );
  }

  void showError(String errorMessage) {
    _zeigeGesperrtenDialog(
      AlertDialog(
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
      ),
    );
  }

  void resetFelder() {
    _vorName.text = "";
    _nachName.text = "";
  }

  Future<T?> _zeigeGesperrtenDialog<T>(Widget dialogInhalt) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        opaque: false, // Hintergrund bleibt sichtbar (wie bei showDialog)
        barrierDismissible: false,
        barrierColor: Colors.black54, // wie der Standard-Dialog-Hintergrund
        pageBuilder: (context, animation, secondaryAnimation) {
          return PopScope(
            canPop: false, // Browser-Zurück wird hier zuverlässig abgefangen
            child: Center(child: dialogInhalt),
          );
        },
      ),
    );
  }
}
