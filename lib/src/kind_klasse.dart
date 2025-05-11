// ignore_for_file: unnecessary_getters_setters

class Kind {
  String _objectId;
  String _vorname;
  String _nachname;
  String _jahrgang;
  String _geschlecht;
  int _erreichtePunkte;
  bool _bezahlt;
  int _riegenNummer;

  // Konstruktor
  Kind({
    String objectId = '',
    required String vorname,
    required String nachname,
    required String jahrgang,
    required String geschlecht,
    int erreichtePunkte = 0,
    required bool bezahlt,
    int riegenNummer = 0,
  })  : _objectId = objectId,
        _vorname = vorname,
        _nachname = nachname,
        _jahrgang = jahrgang,
        _geschlecht = geschlecht,
        _erreichtePunkte = erreichtePunkte,
        _bezahlt = bezahlt,
        _riegenNummer = riegenNummer;

  // Getter-Methoden
  String get objectId => _objectId;
  String get vorname => _vorname;
  String get nachname => _nachname;
  String get jahrgang => _jahrgang;
  String get geschlecht => _geschlecht;
  int get erreichtePunkte => _erreichtePunkte;
  bool get bezahlt => _bezahlt;
  int get riegenNummer => _riegenNummer;

  // Setter-Methoden
  set objectId(String value) => _objectId = value;
  set vorname(String value) => _vorname = value;
  set nachname(String value) => _nachname = value;
  set jahrgang(String value) => _jahrgang = value;
  set geschlecht(String value) => _geschlecht = value;
  set erreichtePunkte(int value) => _erreichtePunkte = value;
  set bezahlt(bool value) => _bezahlt = value;
  set riegenNummer(int value) => _riegenNummer = value;

  // Methode zur Ausgabe von Kind-Details
/* void printDetails() {
    print('Name: $_vorname $_nachname, Jahrgang: $_jahrgang, Geschlecht: $_geschlecht, Punkte: $_erreichtePunkte, Bezahlt: $_bezahlt, Riege: $_riegenNummer');
  }
  */
}
