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
