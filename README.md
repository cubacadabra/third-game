# Cubacadabra Third Game: Capability Probe

This is the preview conformance game for Developer Preview 0.3. It is a small
playable sensor loop whose purpose is to exercise the whole game-facing SDK in
one package:

- every lifecycle callback, including `on_launch`
- lobby and session controls
- retained shared state and transient network messages
- interaction state reads
- all retained UI mutations and UI event handling
- effect state, one-shot effects, and package audio
- a package-owned image rendered as a framed 3D billboard
- both bundled SDK helpers

It is intentionally less of a content showcase than first-game and second-game.
Those games demonstrate two finished game loops; this one verifies breadth and
helps keep the developer guide honest.

## Build

```sh
PYTHONPATH=../tools/src python3 -m cubacadabra build-game . \
  --output build/package --zip build/third-game-v0.3.0.zip
```

The authoritative reference is
[Cubacadabra Game Developer Guide — Developer Preview 0.3](../tools/docs/cubacadabra-game-developer-guide-preview-0.3.md).

### Licensing

Copyright (C) 2026 Andrew Arrow

Licensed under the GNU General Public License v3.0 or later.
See [LICENSE](LICENSE).
