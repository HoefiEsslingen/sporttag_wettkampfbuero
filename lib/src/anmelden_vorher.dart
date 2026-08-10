import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sporttag/src/hilfs_widgets/kinder_bestaetigen_dialog.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/mixins/anmeldung/kind_pruef_ergebnis.dart';
import 'package:sporttag/src/tools/sporttag_config.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/repositories/kind_repository.dart';
// Import der Hilfsklassen für die Anmeldung
import 'package:sporttag/src/tools/anmeldung/geschlecht_optionen.dart';
import 'package:sporttag/src/tools/anmeldung/jahrgangs_helper.dart';
import 'package:sporttag/src/tools/anmeldung/kind_validator.dart';
import 'package:sporttag/src/mixins/anmeldung/anmelde_sperre_mixin.dart';
import 'package:sporttag/src/mixins/anmeldung/duplikat_pruefung_mixin.dart';

class AnmeldenVorher extends StatefulWidget {
  const AnmeldenVorher({super.key, this.title});
  final String? title;

  /// Aktivität vorbereiten
  @override
  AnmeldenVorherState createState() => AnmeldenVorherState();
}

class AnmeldenVorherState extends State<AnmeldenVorher>
    with
        DuplikatPruefungMixin<AnmeldenVorher>,
        AnmeldeSperreMixin<AnmeldenVorher> {
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
  String _geschlecht = GeschlechtOptionen.standard;

  @override
  void initState() {
    super.initState();
    myFocusNode = FocusNode();
    kindRepository = KindRepository();
    // Zugriff über context.read, da initState synchron ist
    config = context.read<SporttagConfig>();
    _jahrgangListe = JahrgangsHelper.zulaessigeJahrgaenge(config);
    _jahrgang = _jahrgangListe.first;
    _geschlecht = GeschlechtOptionen.standard;
  }

  @override
  Widget build(BuildContext context) {
    return sperrbaresPopScope(
      child: Scaffold(
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
                        errorStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      validator: KindValidator.validiereVorname,
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
                        errorStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      validator: KindValidator.validiereNachname,
                    ),
                    const SizedBox(height: 20),
                    // Auswahl-Menü für das Geschlecht
                    DropdownButtonFormField<String>(
                      initialValue: _geschlecht,
                      onChanged: (newValue) =>
                          setState(() => _geschlecht = newValue!),
                      items: [
                        for (String i in GeschlechtOptionen.alle)
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
                          onPressed: istGesperrt
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
                          onPressed: istGesperrt
                              ? null // während des Speicherns deaktiviert
                              : () async {
                                  if (_formKey.currentState!.validate()) {
                                    await fuehreGesperrtAus(
                                        () => pruefeUndSpeichere());
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
                      onPressed: istGesperrt
                          ? null
                          : () {
                              resetFelder();
                              Navigator.of(context).pushNamedAndRemoveUntil(
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
        ),
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

    final alleKinder = await kindRepository.ladeAlleKinder();

    final ergebnis = await pruefeKindVorSpeichern(vorschauKind, alleKinder);
    if (!context.mounted || !ergebnis.istGueltig) {
      return; // Fehlermeldung bzw. Rückfrage wurde bereits im Mixin gezeigt
    }

    // bestehender allgemeiner Bestätigungsdialog bleibt zusätzlich bestehen
    final bestaetigt = await KinderBestaetigenDialog.zeigen(
      context: context,
      kinder: [vorschauKind],
      titel: 'Anmeldung bestätigen',
      hinweisText: 'Soll diese Person tatsächlich angemeldet werden?',
      bestaetigenText: 'Ja, anmelden',
      abbrechenText: 'Abbrechen',
    );

    if (!bestaetigt) return;

    await doSaveData(vorschauKind);
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
