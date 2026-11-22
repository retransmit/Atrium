/// Session state for a Technitium instance.
class TechnitiumSession {
  TechnitiumSession();

  int _refusals = 0;
  DateTime? _lastRefusedAt;

  int get refusals => _refusals;
  DateTime? get lastRefusedAt => _lastRefusedAt;

  void recordAuthRefusal() {
    _refusals++;
    _lastRefusedAt = DateTime.now();
  }

  void resetAuthRefusal() {
    _refusals = 0;
    _lastRefusedAt = null;
  }
}
