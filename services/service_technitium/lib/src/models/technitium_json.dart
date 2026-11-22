/// Safe readers for Technitium JSON responses.
library;

int readInt(Object? value) => value is num ? value.toInt() : 0;

double readDouble(Object? value) => value is num ? value.toDouble() : 0.0;

bool readBool(Object? value) => value == true || value == 'true';

String readString(Object? value) =>
    value is String ? value : (value?.toString() ?? '');

List<String> readStrings(Object? value) => value is List
    ? <String>[
        for (final Object? item in value)
          if (item != null) item.toString(),
      ]
    : const <String>[];

List<int> readInts(Object? value) => value is List
    ? <int>[
        for (final Object? item in value)
          if (item is num) item.toInt(),
      ]
    : const <int>[];

DateTime? parseTechnitiumDate(Object? value) {
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } on FormatException {
      return null;
    }
  }
  return null;
}
