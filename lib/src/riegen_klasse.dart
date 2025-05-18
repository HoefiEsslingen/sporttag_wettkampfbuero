// ignore_for_file: unnecessary_getters_setters

class Riege {
  String _objectId;
  final int _riegenNummer;
  bool _fuenfKampf;
  int _anzStationen;

  // Konstruktor
  Riege({
    String objectId = '',
    required int riegenNummer,
    required bool fuenfKampf,
    int anzStationen = 0,
  })  : _objectId = objectId,
        _riegenNummer = riegenNummer,
        _fuenfKampf = fuenfKampf,
        _anzStationen = anzStationen;

  // Getter-Methoden
  String get objectId => _objectId;
  int get riegenNummer => _riegenNummer;
  bool get fuenfKampf => _fuenfKampf;
  int get anzStationen => _anzStationen;

  // Setter-Methoden
  set objectId(String value) => _objectId = value;
  // Riegennummern sind bereits vorbelegt ==> keine Setter-Methode  --> set riegenNummer(int value) => _riegenNummer = value;
  set fuenfKampf(bool value) => _fuenfKampf = value;
  set anzStationen(int value) => _anzStationen = value;

  // Methode zur Ausgabe von Riegen-Details
/* void printDetails() {
    print('RiegeNnummer: $_riegenNummer, Wettkampf-Art: $_fuenfKampf ? FünfKampf : ZehnKampf, Anzahl bereits absolvierter Stationen: $_anzStationen');
  }
  */
}
