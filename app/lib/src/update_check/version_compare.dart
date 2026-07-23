/// Compares two "major.minor.patch" versions numerically.
///
/// Returns 1 if [a] is newer than [b], -1 if older, 0 if equal. Tolerates a
/// leading "v" and a missing patch segment; a non-numeric segment counts as 0.
int compareVersions(String a, String b) {
  final List<int> pa = _parts(a);
  final List<int> pb = _parts(b);
  for (int i = 0; i < 3; i++) {
    final int diff = pa[i].compareTo(pb[i]);
    if (diff != 0) return diff > 0 ? 1 : -1;
  }
  return 0;
}

List<int> _parts(String v) {
  final String cleaned = v.startsWith('v') ? v.substring(1) : v;
  final List<String> segs = cleaned.split('.');
  final List<int> out = <int>[0, 0, 0];
  for (int i = 0; i < 3 && i < segs.length; i++) {
    out[i] = int.tryParse(segs[i].trim()) ?? 0;
  }
  return out;
}
