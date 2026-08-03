
# Agent Rules
- Always commit using my official GitHub name/author (lxBlazarxl <quasarblazar1@gmail.com>).
- DO NOT PUSH TO THE REMOTE UNLESS I EXPLICITLY SAY SO.
- NEVER COMMIT UNLESS I EXPLICITLY SAY SO.
- NEVER alter or remove the `AspectRatio` poster display logic in Tracearr session cards (`_SessionCard`, used in both currently streaming cards and history tabs): music/audio albums MUST use a `1.0` (1:1 square) aspect ratio and movies/TV shows MUST use a `(2 / 3)` portrait aspect ratio. Never force hardcoded width/height server-side cropping on session card image proxy requests.
- DO NOT change established core UI layouts or image display logic without asking the user first. Always check and copy existing, proven implementations (such as `service_emby`'s session card and poster handling) rather than making assumptions or guessing fix implementations.
