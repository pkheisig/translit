# Translit Mac

A lightweight macOS menu bar utility that transliterates Latin text in your clipboard to Cyrillic using a custom phonetic mapping.

## How it works

1. Copy some Latin text to your clipboard (e.g., `no ja esch'e ne znaju`).
2. Press **⌘ + ⌥ + T**.
3. Your clipboard now contains the Cyrillic version: `но я ещё не знаю`.
4. Paste the result anywhere!

## Mapping Highlights

- `'e` -> `ё`
- `e'` -> `э`
- `shch` -> `щ`
- `ja` / `ya` -> `я`
- `sh` -> `ш`
- `ch` -> `ч`
- `zh` -> `ж`

## Installation

This is a Swift project. You can compile it using Swift Package Manager or simply run it with `swift run` if configured, but it is best built as a proper `.app` bundle to respect the `LSUIElement` setting.

## License

MIT
