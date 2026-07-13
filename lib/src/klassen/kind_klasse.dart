// ignore_for_file: unnecessary_getters_setters

enum KindStatus { unveraendert, neu, geaendert, geloescht }

/// Entspricht der Back4App-Klasse "Kind"
/// Felder laut Schema: vorName, nachName, geschlecht, jahrgang, bezahlt, version
class Kind {
  String _objectId;
  String _vorname;
  String _nachname;
  String _geschlecht;
  int _jahrgang;
  bool _bezahlt;
  int _version;

  int _erreichtePunkte;
  int _riegenNummer;

  // NEU: transientes Tracking-Feld – nie an die DB gesendet
  KindStatus _status;

  Kind({
    String objectId = '',
    required String vorname,
    required String nachname,
    required String geschlecht,
    required int jahrgang,
    bool bezahlt = false,
    int version = 1,
    int erreichtePunkte = 0,
    int riegenNummer = 0,
    KindStatus? status,
  })  : _objectId = objectId,
        _vorname = vorname,
        _nachname = nachname,
        _geschlecht = geschlecht,
        _jahrgang = jahrgang,
        _bezahlt = bezahlt,
        _version = version,
        _erreichtePunkte = erreichtePunkte,
        _riegenNummer = riegenNummer,
        // Falls kein Status übergeben wird: anhand objectId ableiten
        _status = status ??
            (objectId.isEmpty ? KindStatus.neu : KindStatus.unveraendert);

  // Getter
  String get objectId => _objectId;
  String get vorname => _vorname;
  String get nachname => _nachname;
  String get geschlecht => _geschlecht;
  int get jahrgang => _jahrgang;
  String get jahrgangAlsText => _jahrgang.toString();
  bool get bezahlt => _bezahlt;
  int get version => _version;
  int get erreichtePunkte => _erreichtePunkte;
  int get riegenNummer => _riegenNummer;
  KindStatus get status => _status;

  bool get istNeu => _status == KindStatus.neu;
  bool get istGeaendert => _status == KindStatus.geaendert;
  bool get mussGespeichertWerden =>
      _status == KindStatus.neu || _status == KindStatus.geaendert;

  // Setter – markieren jetzt automatisch als 'geaendert', falls sich der Wert wirklich ändert
  set objectId(String v) =>
      _objectId = v; // wird i.d.R. nur von der DB gesetzt, nicht vom UI
  set vorname(String v) => _setzeUndMarkiere(() => _vorname = v, v != _vorname);
  set nachname(String v) =>
      _setzeUndMarkiere(() => _nachname = v, v != _nachname);
  set geschlecht(String v) =>
      _setzeUndMarkiere(() => _geschlecht = v, v != _geschlecht);
  set jahrgang(int v) => _setzeUndMarkiere(() => _jahrgang = v, v != _jahrgang);
  set bezahlt(bool v) => _setzeUndMarkiere(() => _bezahlt = v, v != _bezahlt);

  set version(int v) => _version = v; // wird von der DB gesetzt, nicht getrackt
  set erreichtePunkte(int v) =>
      _erreichtePunkte = v; // kommt aus resultate, nicht Teil von Kind-Save
  set riegenNummer(int v) => _riegenNummer = v; // kommt aus kinderDerRiege

  /// Setzt den Status manuell (z. B. für 'geloescht' oder zum Zurücksetzen nach dem Speichern)
  set status(KindStatus s) => _status = s;

  void _setzeUndMarkiere(void Function() zuweisung, bool hatSichGeaendert) {
    zuweisung();
    if (hatSichGeaendert && _status == KindStatus.unveraendert) {
      _status = KindStatus.geaendert;
    }
    // war es schon 'neu' oder 'geaendert', bleibt es das auch
  }

  /// Nach erfolgreichem Speichern aufrufen
  void markiereAlsGespeichert() {
    _status = KindStatus.unveraendert;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Kind && _objectId.isNotEmpty && _objectId == other._objectId);

  @override
  int get hashCode => _objectId.hashCode;
}
