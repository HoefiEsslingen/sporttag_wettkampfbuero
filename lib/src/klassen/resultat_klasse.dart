// ──────────────────────────────────────────────
// Resultat  →  Back4App-Klasse "resultate"
// Speichert Punkte eines Kindes für eine Station
// ──────────────────────────────────────────────
class Resultat {
  String   _objectId;
  String   _kindObjectId;     // Pointer → Kind
  String   _stationsObjectId; // Pointer → Station
  int      _punkte;
  DateTime _erreichtUm;
  int      _version;

  Resultat({
    String   objectId         = '',
    required String   kindObjectId,
    required String   stationsObjectId,
    required int      punkte,
    DateTime? erreichtUm,
    int      version          = 1,
  })  : _objectId         = objectId,
        _kindObjectId     = kindObjectId,
        _stationsObjectId = stationsObjectId,
        _punkte           = punkte,
        _erreichtUm       = erreichtUm ?? DateTime.now(),
        _version          = version;

  String   get objectId         => _objectId;
  String   get kindObjectId     => _kindObjectId;
  String   get stationsObjectId => _stationsObjectId;
  int      get punkte           => _punkte;
  DateTime get erreichtUm       => _erreichtUm;
  int      get version          => _version;

  set objectId(String v)         => _objectId = v;
  set kindObjectId(String v)     => _kindObjectId = v;
  set stationsObjectId(String v) => _stationsObjectId = v;
  set punkte(int v)              => _punkte = v;
  set erreichtUm(DateTime v)     => _erreichtUm = v;
  set version(int v)             => _version = v;
}

