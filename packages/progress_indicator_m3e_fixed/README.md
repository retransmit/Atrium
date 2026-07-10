
# progress_indicator_m3e (spec build)

**Visual rules implemented**
- Active and track never overlap.
- Circular ring is *broken* around the active sweep.
- Squiggle variants (48/52) draw a sine-like stroke inside the ring with 2dp clearance.
- Linear shows two lanes (active above, track below) with fixed gap and end-dot, per table.

**Linear variants**
- `flatXS` — track 4, gap 4, dot Ø4, dotOffset 4, trailing 4
- `flatS`  — track 8, gap 4, dot Ø4, dotOffset 2, trailing 8
- `wavyM`  — track 4, wave amp 3, period 40, gap 4, dot Ø4, dotOffset 2, trailing 10
- `wavyL`  — track 8, wave amp 3, period 40, gap 4, dot Ø4, dotOffset 2, trailing 14


---

## Live demo (Gallery)

Explore this component in the M3E Gallery (GitHub Pages):

https://<your-github-username>.github.io/material_3_expressive/

To run the Gallery locally:

```sh
cd apps/gallery
flutter run -d chrome
```

_Last updated: 2025-10-23_


---

## Detailed Guide

### What this package provides
Material 3 Expressive progress indicators with token-aligned colors and shapes, providing circular and linear variants with determinate and indeterminate modes.

### Installation
- Monorepo (local path): already configured alongside m3e_design.
- Pub (when published):
```yaml
dependencies:
  progress_indicator_m3e: ^0.3.0
  m3e_design: ^0.1.0
```

Minimum SDK: Dart >=3.3.0; Flutter >=3.19.0.

### Dependencies
- flutter
- m3e_design

### Quick start
```dart
// Indeterminate
const CircularProgressIndicatorM3E()

// Determinate
const LinearProgressIndicatorM3E(value: 0.6)
```

### Key parameters
- value: double? — 0.0..1.0 for determinate; null for indeterminate.
- semanticsLabel: String? — Describe progress for screen readers.
- backgroundColor / color: Color? — Override token colors.

### Theming with m3e_design
Colors, track heights, and indicator shapes are driven by M3E tokens.

### Accessibility
- Always provide semanticsLabel when indeterminate; ensure sufficient contrast.

### Links
- Repository: https://github.com/EmilyMoonstone/material_3_expressive/tree/main/packages/progress_indicator_m3e
- Issue tracker: https://github.com/EmilyMonestone/material_3_expressive/issues
- Changelog: ./CHANGELOG.md
