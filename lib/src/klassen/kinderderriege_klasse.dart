// ──────────────────────────────────────────────
// KindDerRiege  →  Back4App-Klasse "kinderDerRiege"
// Verknüpft Kind (Pointer) mit Riege (Pointer)
// ──────────────────────────────────────────────
class KindDerRiege {
  String _objectId;
  String _kindObjectId;    // Pointer → Kind
  String _riegenObjectId;  // Pointer → Riege
  int    _position;        // Reihenfolge innerhalb der Riege
  int    _version;

  KindDerRiege({
    String objectId      = '',
    required String kindObjectId,
    required String riegenObjectId,
    required int    position,
    int    version       = 1,
  })  : _objectId      = objectId,
        _kindObjectId  = kindObjectId,
        _riegenObjectId= riegenObjectId,
        _position      = position,
        _version       = version;

  String get objectId       => _objectId;
  String get kindObjectId   => _kindObjectId;
  String get riegenObjectId => _riegenObjectId;
  int    get position       => _position;
  int    get version        => _version;

  set objectId(String v)       => _objectId = v;
  set kindObjectId(String v)   => _kindObjectId = v;
  set riegenObjectId(String v) => _riegenObjectId = v;
  set position(int v)          => _position = v;
  set version(int v)           => _version = v;
}