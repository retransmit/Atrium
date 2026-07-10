/// Circular sizes driven by outer diameter.
enum CircularProgressM3ESize { s, m }

extension CircularM3ESizeExtension on CircularProgressM3ESize {
  double get diameterWavy {
    switch (this) {
      case CircularProgressM3ESize.s:
        return 48.0; // wavy small
      case CircularProgressM3ESize.m:
        return 52.0; // wavy medium
    }
  }

  double get diameterFlat {
    switch (this) {
      case CircularProgressM3ESize.s:
        return 40.0; // flat small
      case CircularProgressM3ESize.m:
        return 44.0; // flat medium
    }
  }
}

/// Linear sizes and shapes
enum LinearProgressM3ESize { s, m }

enum ProgressM3EShape { flat, wavy }
