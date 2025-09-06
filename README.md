# Matte, Boxy Keyboard — Flutter

A pixel-snapped, **matte “boxy” keycap** keyboard rendered in Flutter with smooth press/release animations, **hardware keyboard sync**, and a **Caps Lock LED** that tracks the real lock state. Includes **dark & light** themes with tuned shadows to match a chalky, soft-touch finish.

> Desktop-first (macOS/Windows/Linux). Works on web (browser limitations apply).

---

## Features

- **Boxy matte keycaps** (no gloss) with diffuse highlight, inner matte shadow, and micro-noise texture.
- **Pixel-snapped rows** for perfectly straight vertical edges at any width.
- **Smooth key animations** driven by `RawKeyboardListener`.
- **Caps Lock LED**
  - LED mirrors `HardwareKeyboard.lockModesEnabled` when available.
  - UI press is **momentary** (auto-releases) so Caps never looks “stuck”.
  - Fallback toggle on `RawKeyDownEvent` when lock modes aren’t exposed.
- **Function row** with icons + centered F-labels; **F1** has a soft Spartan-style glow.
- **Mac-like legends**: bottom-left labels (`esc`, `tab`, `capslock`, `shift`, …), bottom-right (`delete`, `return`, right `shift`), top-right glyphs (`⌘ ⌥ ⌃`).
- **Arrow cluster**: left | (up/down stacked) | right.
- **Board surface**: vignette, inner sheen, speckle; margins tuned to the reference look.
- **Dark/Light themes** with **different shadow models** and readable ink in light mode.

---
## Inspiration

![Gz1hKs2WEAACgzZ](https://github.com/user-attachments/assets/fbeaaa27-256a-4911-ba26-2bf1a9e45315)

Credit - https://x.com/uialexk/status/1962831914177315191

---
## Preview

https://github.com/user-attachments/assets/69c3bcdf-36da-441b-97eb-df03540454e0



Built with ❤️ flutter 
