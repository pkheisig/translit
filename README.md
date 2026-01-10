# Translit Mac

<img src="icon.png" width="128" alt="Translit Mac Icon">

A lightweight macOS menu bar utility for **real-time** Latin to Cyrillic transliteration. Type in Latin letters and they're instantly converted to Cyrillic as you type.

## Features

- **Real-time transliteration** — no copy/paste needed, just type!
- **Toggle on/off** with global hotkey **⌘ + ⌥ + T**
- **Menu bar app** — runs quietly in the background
- **Smart multi-character sequences** — `sh` → `ш`, `ch` → `ч`, etc.
- **Case-sensitive** — uppercase input produces uppercase Cyrillic
- **Blocks unused letters** — `w`, `x`, `q` produce no output when enabled

## How It Works

1. Launch the app (appears in menu bar as `Ⓣ`)
2. Start typing in any app — Latin letters are converted to Cyrillic in real-time
3. Press **⌘ + ⌥ + T** to toggle transliteration on/off
4. Click the menu bar icon to access settings or quit

## Complete Mapping

### Multi-character sequences (matched first)

| Latin | Cyrillic |
|-------|----------|
| `shch` | щ |
| `sch` | щ |
| `'e` | ё |
| `e'` | э |
| `zh` | ж |
| `ch` | ч |
| `sh` | ш |
| `kh` | х |
| `ts` | ц |
| `yu` | ю |
| `ya` | я |
| `ju` | ю |
| `ja` | я |
| `eh` | э |
| `''` | ъ |

### Single characters

| Latin | Cyrillic |
|-------|----------|
| `a` | а |
| `b` | б |
| `v` | в |
| `g` | г |
| `d` | д |
| `e` | е |
| `z` | з |
| `i` | и |
| `j` | й |
| `k` | к |
| `l` | л |
| `m` | м |
| `n` | н |
| `o` | о |
| `p` | п |
| `r` | р |
| `s` | с |
| `t` | т |
| `u` | у |
| `f` | ф |
| `y` | ы |
| `'` | ь |

### Blocked characters

The following Latin letters have no Cyrillic equivalent and are blocked (produce no output) when transliteration is enabled:
- `w`, `x`, `q`

## Installation

### Build from source

```bash
# Clone the repo
git clone https://github.com/pkheisig/translit-mac.git
cd translit-mac

# Compile
swiftc -o Translit.app/Contents/MacOS/Translit \
  TranslitApp.swift RealTimeEngine.swift \
  GlobalShortcutManager.swift Transliterater.swift \
  -framework Cocoa -framework Carbon

# Run
open Translit.app
```

### Grant Accessibility Permissions

The app requires **Accessibility permissions** to intercept keyboard events:

1. Go to **System Settings → Privacy & Security → Accessibility**
2. Add `Translit.app` and enable it
3. Restart the app if needed

## Requirements

- macOS 12.0 or later
- Accessibility permissions

## License

MIT
