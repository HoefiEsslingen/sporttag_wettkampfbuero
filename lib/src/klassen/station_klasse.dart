// ignore_for_file: unnecessary_getters_setters

// ──────────────────────────────────────────────
// Station  →  Back4App-Klasse "Station"
// ──────────────────────────────────────────────
class Station {
  String _objectId;
  String _stationsName;    // DB-Feld: stationsName
  int    _stationsNummer;  // DB-Feld: stationsNummer
  bool   _nurZehnKampf;   // DB-Feld: nurZehnKampf
  String? _beschreibungUrl; // NEU: DB-Feld "Beschreibung" (Parse File)
  int    _version;         // DB-Feld: version

  Station({
    String objectId       = '',
    required String stationsName,
    required int    stationsNummer,
    bool   nurZehnKampf   = false,
    String? beschreibungUrl,
    int    version        = 1,
  })  : _objectId       = objectId,
        _stationsName   = stationsName,
        _stationsNummer = stationsNummer,
        _nurZehnKampf   = nurZehnKampf,
        _beschreibungUrl = beschreibungUrl,
        _version        = version;

  String get objectId       => _objectId;
  String get stationsName   => _stationsName;
  int    get stationsNummer => _stationsNummer;
  bool   get nurZehnKampf   => _nurZehnKampf;
  String? get beschreibungUrl => _beschreibungUrl; // NEU
  int    get version        => _version;

  set objectId(String v)       => _objectId = v;
  set stationsName(String v)   => _stationsName = v;
  set stationsNummer(int v)    => _stationsNummer = v;
  set nurZehnKampf(bool v)     => _nurZehnKampf = v;
  set beschreibungUrl(String? v) => _beschreibungUrl = v;
  set version(int v)           => _version = v;
}

