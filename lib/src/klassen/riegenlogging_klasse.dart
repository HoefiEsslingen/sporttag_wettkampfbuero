// ──────────────────────────────────────────────
// RiegenLogging  →  Back4App-Klasse "riegenLogging"
// Protokolliert, welche Stationen eine Riege bereits absolviert hat
// ──────────────────────────────────────────────
class RiegenLogging {
  String   _objectId;
  String   _riegenObjectId;   // Pointer → Riege
  String   _stationsObjectId; // Pointer → Station (zuletzt absolviert)
  int      _anzAbsolvierterStationen;
  DateTime? _letzteStationUm;
  int      _version;

  RiegenLogging({
    String    objectId                 = '',
    required  String riegenObjectId,
    required  String stationsObjectId,
    int       anzAbsolvierterStationen = 0,
    DateTime? letzteStationUm,
    int       version                  = 1,
  })  : _objectId                  = objectId,
        _riegenObjectId            = riegenObjectId,
        _stationsObjectId          = stationsObjectId,
        _anzAbsolvierterStationen  = anzAbsolvierterStationen,
        _letzteStationUm           = letzteStationUm,
        _version                   = version;

  String    get objectId                  => _objectId;
  String    get riegenObjectId            => _riegenObjectId;
  String    get stationsObjectId          => _stationsObjectId;
  int       get anzAbsolvierterStationen  => _anzAbsolvierterStationen;
  DateTime? get letzteStationUm           => _letzteStationUm;
  int       get version                   => _version;

  set objectId(String v)                  => _objectId = v;
  set riegenObjectId(String v)            => _riegenObjectId = v;
  set stationsObjectId(String v)          => _stationsObjectId = v;
  set anzAbsolvierterStationen(int v)     => _anzAbsolvierterStationen = v;
  set letzteStationUm(DateTime? v)        => _letzteStationUm = v;
  set version(int v)                      => _version = v;
}
