/// Readers for AdGuard Home's JSON.
///
/// The server leaves properties out, and sends null where an empty list is
/// meant, often enough that every model reads through these rather than
/// casting. A value of the wrong type reads as the empty one.
library;

int readInt(Object? value) => value is num ? value.toInt() : 0;

double readDouble(Object? value) => value is num ? value.toDouble() : 0;

bool readBool(Object? value) => value == true;

String readString(Object? value) => value is String ? value : '';

List<String> readStrings(Object? value) => value is List
    ? <String>[
        for (final Object? item in value)
          if (item is String) item,
      ]
    : const <String>[];

List<int> readInts(Object? value) => value is List
    ? <int>[
        for (final Object? item in value)
          if (item is num) item.toInt(),
      ]
    : const <int>[];

/// Whether two values read from JSON, or built to be sent as it, hold the
/// same. The order of an object's properties does not count; a list's does.
bool adguardHomeJsonEquals(Object? a, Object? b) {
  if (a is Map<Object?, Object?> && b is Map<Object?, Object?>) {
    if (a.length != b.length) return false;
    for (final MapEntry<Object?, Object?> entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!adguardHomeJsonEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!adguardHomeJsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
