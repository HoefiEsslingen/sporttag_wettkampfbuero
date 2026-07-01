// ignore_for_file: unnecessary_getters_setters

/// Entspricht der Back4App-Klasse "Riege"
/// Felder laut Schema: riegenNummer, fuenfKampf, wetttkampfBeendet, version
///
/// NICHT mehr in Riege gespeichert (eigene Klassen):
///   - Kinderzuordnung       → kinderDerRiege
///   - Stationsfortschritt   → riegenLogging (Pointer auf Riege + Station)
class Riege {
  String _objectId;
  final int  _riegenNummer;    // DB-Feld: riegenNummer
  bool   _fuenfKampf;          // DB-Feld: fuenfKampf
  bool   _wettkampfBeendet;   // DB-Feld: wettkampfBeendet (Tippfehler im Schema beibehalten)
  int    _version;             // DB-Feld: version (Optimistic Locking)

  // Transienter Zähler – wird aus riegenLogging.anzAbsolvierterStationen geladen
  int    _anzStationen;

  Riege({
    String objectId           = '',
    required int riegenNummer,
    bool   fuenfKampf         = false,
    bool   wetttkampfBeendet  = false,
    int    version            = 1,
    int    anzStationen       = 0,
  })  : _objectId            = objectId,
        _riegenNummer        = riegenNummer,
        _fuenfKampf          = fuenfKampf,
        _wettkampfBeendet   = wetttkampfBeendet,
        _version             = version,
        _anzStationen        = anzStationen;

  // Getter
  String get objectId            => _objectId;
  int    get riegenNummer        => _riegenNummer;
  bool   get fuenfKampf          => _fuenfKampf;
  bool   get wetttkampfBeendet   => _wettkampfBeendet;
  int    get version             => _version;
  int    get anzStationen        => _anzStationen;

  // Rückwärtskompatibilität: urkunden.dart nutzt noch 'ausgewertet'
  bool   get ausgewertet         => _wettkampfBeendet;

  // Setter
  set objectId(String v)           => _objectId = v;
  set fuenfKampf(bool v)           => _fuenfKampf = v;
  set wetttkampfBeendet(bool v)    => _wettkampfBeendet = v;
  set ausgewertet(bool v)          => _wettkampfBeendet = v; // Alias
  set version(int v)               => _version = v;
  set anzStationen(int v)          => _anzStationen = v;
}
