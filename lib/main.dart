// lib/main.dart
// Physical-keyboard synced matte keyboard with CapsLock LED:
// - RawKeyboardListener drives smooth press/release animations
// - CapsLock LED shows when uppercase mode is ON (via HardwareKeyboard lockModes)
// - CapsLock visual is momentary (auto-releases) so it never appears stuck
// - Dark + Light themes with tuned shadows

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const KeyboardApp());

class KeyboardApp extends StatelessWidget {
  const KeyboardApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const KeyboardDemo(),
      themeMode: ThemeMode.dark,
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                DEMO SCAFFOLD                               */
/* -------------------------------------------------------------------------- */

class KeyboardDemo extends StatefulWidget {
  const KeyboardDemo({super.key});
  @override
  State<KeyboardDemo> createState() => _KeyboardDemoState();
}

class _KeyboardDemoState extends State<KeyboardDemo> {
  bool dark = true;

  final FocusNode _focusNode = FocusNode();
  Set<LogicalKeyboardKey> _pressed = const {};
  bool _capsOn = false;

  // Keys to “pulse” (pressed briefly then auto-release) for UI
  final Set<LogicalKeyboardKey> _transientDown = {};

  static const _capsPulse = Duration(milliseconds: 120);

  @override
  void initState() {
    super.initState();
    _pressed = RawKeyboard.instance.keysPressed;

    // Read initial hardware caps state (if available)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hwCaps =
      HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
      setState(() => _capsOn = hwCaps);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _pulseKey(LogicalKeyboardKey key, Duration d) {
    _transientDown.add(key);
    setState(() {});
    Future.delayed(d, () {
      if (!mounted) return;
      _transientDown.remove(key);
      setState(() {});
    });
  }

  void _handleKey(RawKeyEvent e) {
    setState(() {
      // Update held keys from hardware
      _pressed = Set<LogicalKeyboardKey>.from(RawKeyboard.instance.keysPressed);

      // Prefer hardware-reported lock modes
      final hwCaps =
      HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
      if (hwCaps != _capsOn) {
        _capsOn = hwCaps;
      } else if (e.logicalKey == LogicalKeyboardKey.capsLock && e is RawKeyDownEvent) {
        // Fallback: toggle locally if platform doesn't expose lock modes
        _capsOn = !_capsOn;
      }

      // Always pulse CapsLock visually so it auto-releases in the UI
      if (e.logicalKey == LogicalKeyboardKey.capsLock && e is RawKeyDownEvent) {
        _pulseKey(LogicalKeyboardKey.capsLock, _capsPulse);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = dark ? KeyboardTheme.darkCloseUp() : KeyboardTheme.lightCloseUp();

    // Visual pressed state: remove caps from hardware set and replace with transient
    final visualPressed = Set<LogicalKeyboardKey>.from(_pressed)
      ..remove(LogicalKeyboardKey.capsLock)
      ..addAll(_transientDown.where((k) => k == LogicalKeyboardKey.capsLock));

    return Scaffold(
      backgroundColor: t.canvas,
      body: SafeArea(
        child: RawKeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKey: _handleKey,
          child: Column(
            children: [
              const SizedBox(height: 18),
              _ThemePill(
                dark: dark,
                onChanged: (v) => setState(() => dark = v),
                pillLabel: "Alex K @uialexk",
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 14 / 6.25,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
                      child: _BoardSurface(
                        t: t,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _Keyboard(t: t, pressed: visualPressed, capsOn: _capsOn),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                         KEY MAPPING HELPERS (LOGICAL)                      */
/* -------------------------------------------------------------------------- */

const Map<String, LogicalKeyboardKey> _letterKey = {
  'A': LogicalKeyboardKey.keyA,
  'B': LogicalKeyboardKey.keyB,
  'C': LogicalKeyboardKey.keyC,
  'D': LogicalKeyboardKey.keyD,
  'E': LogicalKeyboardKey.keyE,
  'F': LogicalKeyboardKey.keyF,
  'G': LogicalKeyboardKey.keyG,
  'H': LogicalKeyboardKey.keyH,
  'I': LogicalKeyboardKey.keyI,
  'J': LogicalKeyboardKey.keyJ,
  'K': LogicalKeyboardKey.keyK,
  'L': LogicalKeyboardKey.keyL,
  'M': LogicalKeyboardKey.keyM,
  'N': LogicalKeyboardKey.keyN,
  'O': LogicalKeyboardKey.keyO,
  'P': LogicalKeyboardKey.keyP,
  'Q': LogicalKeyboardKey.keyQ,
  'R': LogicalKeyboardKey.keyR,
  'S': LogicalKeyboardKey.keyS,
  'T': LogicalKeyboardKey.keyT,
  'U': LogicalKeyboardKey.keyU,
  'V': LogicalKeyboardKey.keyV,
  'W': LogicalKeyboardKey.keyW,
  'X': LogicalKeyboardKey.keyX,
  'Y': LogicalKeyboardKey.keyY,
  'Z': LogicalKeyboardKey.keyZ,
};

const Map<String, LogicalKeyboardKey> _digitKey = {
  '1': LogicalKeyboardKey.digit1,
  '2': LogicalKeyboardKey.digit2,
  '3': LogicalKeyboardKey.digit3,
  '4': LogicalKeyboardKey.digit4,
  '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6,
  '7': LogicalKeyboardKey.digit7,
  '8': LogicalKeyboardKey.digit8,
  '9': LogicalKeyboardKey.digit9,
  '0': LogicalKeyboardKey.digit0,
};

Set<LogicalKeyboardKey> letterSet(String s) => {_letterKey[s.toUpperCase()]!};
Set<LogicalKeyboardKey> digitSet(String d) => {_digitKey[d]!};

/* -------------------------------------------------------------------------- */
/*                               BOARD + TEXTURE                              */
/* -------------------------------------------------------------------------- */

class _BoardSurface extends StatelessWidget {
  const _BoardSurface({required this.t, required this.child});
  final KeyboardTheme t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = t.boardRadius;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: t.boardGradient,
        ),
        border: Border.all(color: t.boardEdge, width: 1),
        boxShadow: t.boardShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _NoisePainter(color: t.noiseColor, opacity: t.noiseOpacity)),
            // inner catch-light (top-left)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.center,
                  colors: [t.boardInnerSheen, Colors.transparent],
                  stops: const [.0, .45],
                ),
              ),
            ),
            // edge vignette
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-.2, -.1),
                  radius: 1.25,
                  colors: [Colors.transparent, t.vignette],
                  stops: const [.58, 1.0],
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                   KEYS                                     */
/* -------------------------------------------------------------------------- */

class _Keyboard extends StatelessWidget {
  const _Keyboard({required this.t, required this.pressed, required this.capsOn});
  final KeyboardTheme t;
  final Set<LogicalKeyboardKey> pressed;
  final bool capsOn;

  static const double _rowGap = 12;
  static const double _colGap = 8;

  @override
  Widget build(BuildContext context) {
    final rows = <List<KeyCapSpec>>[
      // Row 1 — Esc + Fn keys
      [
        KeyCapSpec.w(labelBottomLeft: 'esc', w: 1.12, triggers: {LogicalKeyboardKey.escape}),
        KeyCapSpec.fn(fLabel: 'F1', glow: true, triggers: {LogicalKeyboardKey.f1}),
        KeyCapSpec.fn(fLabel: 'F2', icon: Icons.brightness_low_rounded, triggers: {LogicalKeyboardKey.f2}),
        KeyCapSpec.fn(fLabel: 'F3', icon: Icons.brightness_high_rounded, triggers: {LogicalKeyboardKey.f3}),
        KeyCapSpec.fn(fLabel: 'F4', icon: Icons.play_arrow_rounded, triggers: {LogicalKeyboardKey.f4}),
        KeyCapSpec.fn(fLabel: 'F5', icon: Icons.stop_rounded, triggers: {LogicalKeyboardKey.f5}),
        KeyCapSpec.fn(fLabel: 'F6', icon: Icons.photo_size_select_small_rounded, triggers: {LogicalKeyboardKey.f6}),
        KeyCapSpec.fn(fLabel: 'F7', icon: Icons.fast_rewind_rounded, triggers: {LogicalKeyboardKey.f7}),
        KeyCapSpec.fn(fLabel: 'F8', icon: Icons.pause_rounded, triggers: {LogicalKeyboardKey.f8}),
        KeyCapSpec.fn(fLabel: 'F9', icon: Icons.fast_forward_rounded, triggers: {LogicalKeyboardKey.f9}),
        KeyCapSpec.fn(fLabel: 'F10', icon: Icons.volume_mute_rounded, triggers: {LogicalKeyboardKey.f10}),
        KeyCapSpec.fn(fLabel: 'F11', icon: Icons.volume_down_rounded, triggers: {LogicalKeyboardKey.f11}),
        KeyCapSpec.fn(fLabel: 'F12', icon: Icons.volume_up_rounded, triggers: {LogicalKeyboardKey.f12}),
      ],
      // Row 2 — number row (symbol above number)
      [
        KeyCapSpec.w(primary: '~', secondary: '`', triggers: {LogicalKeyboardKey.backquote}),
        KeyCapSpec.w(primary: '!', secondary: '1', triggers: digitSet('1')),
        KeyCapSpec.w(primary: '@', secondary: '2', triggers: digitSet('2')),
        KeyCapSpec.w(primary: '#', secondary: '3', triggers: digitSet('3')),
        KeyCapSpec.w(primary: '\$', secondary: '4', triggers: digitSet('4')),
        KeyCapSpec.w(primary: '%', secondary: '5', triggers: digitSet('5')),
        KeyCapSpec.w(primary: '^', secondary: '6', triggers: digitSet('6')),
        KeyCapSpec.w(primary: '&', secondary: '7', triggers: digitSet('7')),
        KeyCapSpec.w(primary: '*', secondary: '8', triggers: digitSet('8')),
        KeyCapSpec.w(primary: '(', secondary: '9', triggers: digitSet('9')),
        KeyCapSpec.w(primary: ')', secondary: '0', triggers: digitSet('0')),
        KeyCapSpec.w(primary: '_', secondary: '-', triggers: {LogicalKeyboardKey.minus}),
        KeyCapSpec.w(primary: '+', secondary: '=', triggers: {LogicalKeyboardKey.equal}),
        KeyCapSpec.w(labelTopRight: 'delete', w: 1.6, triggers: {LogicalKeyboardKey.backspace}),
      ],
      // Row 3
      [
        KeyCapSpec.w(labelBottomLeft: 'tab', w: 1.52, triggers: {LogicalKeyboardKey.tab}),
        ...'QWERTYUIOP'.split('').map((c) => KeyCapSpec.w(center: c, triggers: letterSet(c))),
        KeyCapSpec.w(center: '[', triggers: {LogicalKeyboardKey.bracketLeft}),
        KeyCapSpec.w(center: ']', triggers: {LogicalKeyboardKey.bracketRight}),
        KeyCapSpec.w(center: '\\', w: 1.28, triggers: {LogicalKeyboardKey.backslash}),
      ],
      // Row 4
      [
        KeyCapSpec.w(
          labelBottomLeft: 'capslock',
          dotLed: true,
          w: 1.92,
          triggers: {LogicalKeyboardKey.capsLock},
        ),
        ...'ASDFGHJKL'.split('').map((c) => KeyCapSpec.w(center: c, triggers: letterSet(c))),
        KeyCapSpec.w(center: ';', triggers: {LogicalKeyboardKey.semicolon}),
        KeyCapSpec.w(center: '\'', triggers: {LogicalKeyboardKey.quote}),
        KeyCapSpec.w(
          labelTopRight: 'return',
          w: 2.02,
          triggers: {LogicalKeyboardKey.enter, LogicalKeyboardKey.numpadEnter},
        ),
      ],
      // Row 5
      [
        KeyCapSpec.w(
          labelBottomLeft: 'shift',
          w: 2.22,
          triggers: {LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight},
        ),
        ...'ZXCVBNM'.split('').map((c) => KeyCapSpec.w(center: c, triggers: letterSet(c))),
        KeyCapSpec.w(center: ',', triggers: {LogicalKeyboardKey.comma}),
        KeyCapSpec.w(center: '.', triggers: {LogicalKeyboardKey.period}),
        KeyCapSpec.w(center: '/', triggers: {LogicalKeyboardKey.slash}),
        KeyCapSpec.w(
          labelTopRight: 'shift',
          w: 2.62,
          triggers: {LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight},
        ),
      ],
      // Row 6 — modifiers + space + arrow cluster
      [
        KeyCapSpec.w(labelBottomLeft: 'fn', w: 1.18),
        KeyCapSpec.w(
          labelBottomLeft: 'control',
          symbolTopRight: '⌃',
          w: 1.38,
          triggers: {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.controlRight},
        ),
        KeyCapSpec.w(
          labelBottomLeft: 'option',
          symbolTopRight: '⌥',
          w: 1.38,
          triggers: {LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight},
        ),
        KeyCapSpec.w(
          labelBottomLeft: 'command',
          symbolTopRight: '⌘',
          w: 1.58,
          triggers: {LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight},
        ),
        KeyCapSpec.space(5.42, triggers: {LogicalKeyboardKey.space}),
        KeyCapSpec.w(
          labelBottomLeft: 'command',
          symbolTopRight: '⌘',
          w: 1.58,
          triggers: {LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight},
        ),
        KeyCapSpec.w(
          labelBottomLeft: 'option',
          symbolTopRight: '⌥',
          w: 1.38,
          triggers: {LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight},
        ),
        KeyCapSpec.w(icon: Icons.keyboard_arrow_left_rounded, w: 1.0, triggers: {
          LogicalKeyboardKey.arrowLeft
        }),
        KeyCapSpec.arrowStack(),
        KeyCapSpec.w(icon: Icons.keyboard_arrow_right_rounded, w: 1.0, triggers: {
          LogicalKeyboardKey.arrowRight
        }),
      ],
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final row in rows) ...[
          _KeyRow(specs: row, t: t, hGap: _colGap, pressed: pressed, capsOn: capsOn),
          const SizedBox(height: _rowGap),
        ],
      ],
    );
  }
}

/// Pixel-snapped row so key edges are straight (no wavy fractions).
class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.specs,
    required this.t,
    required this.hGap,
    required this.pressed,
    required this.capsOn,
  });
  final List<KeyCapSpec> specs;
  final KeyboardTheme t;
  final double hGap;
  final Set<LogicalKeyboardKey> pressed;
  final bool capsOn;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final totalUnits = specs.fold<double>(0, (a, b) => a + b.w);
      final gaps = hGap * (specs.length - 1);
      final available = constraints.maxWidth - gaps;
      final unit = available / totalUnits;

      final widths = <double>[];
      double sum = 0;
      for (var i = 0; i < specs.length; i++) {
        final raw = unit * specs[i].w;
        final w = i == specs.length - 1 ? available - sum : raw.roundToDouble();
        widths.add(w);
        sum += w;
      }

      return Row(
        children: [
          for (var i = 0; i < specs.length; i++) ...[
            SizedBox(
              width: widths[i],
              child: KeyCap(spec: specs[i], t: t, pressed: pressed, capsOn: capsOn),
            ),
            if (i != specs.length - 1) SizedBox(width: hGap),
          ],
        ],
      );
    });
  }
}

/* -------------------------------------------------------------------------- */
/*                                KEYCAP WIDGET                               */
/* -------------------------------------------------------------------------- */

class KeyCapSpec {
  KeyCapSpec.w({
    this.center,
    this.primary,
    this.secondary,
    this.symbolTopRight,
    this.icon,
    this.labelBottomLeft,
    this.labelTopRight,
    this.bottomFnText,
    this.dotLed = false,
    this.glow = false,
    this.stackedArrows = false,
    this.triggers = const {},
    double? w,
  }) : w = w ?? 1.0;

  KeyCapSpec.fn({required String fLabel, this.icon, this.glow = false, this.triggers = const {}})
      : w = 1.0,
        center = null,
        primary = null,
        secondary = null,
        symbolTopRight = null,
        labelBottomLeft = null,
        labelTopRight = null,
        bottomFnText = fLabel,
        dotLed = false,
        stackedArrows = false;

  KeyCapSpec.space(double widthUnits, {Set<LogicalKeyboardKey> triggers = const {}})
      : w = widthUnits,
        center = null,
        primary = null,
        secondary = null,
        symbolTopRight = null,
        icon = null,
        labelBottomLeft = null,
        labelTopRight = null,
        bottomFnText = null,
        dotLed = false,
        glow = false,
        stackedArrows = false,
        triggers = triggers;

  KeyCapSpec.arrowStack()
      : w = 1.0,
        center = null,
        primary = null,
        secondary = null,
        symbolTopRight = null,
        icon = null,
        labelBottomLeft = null,
        labelTopRight = null,
        bottomFnText = null,
        dotLed = false,
        glow = false,
        stackedArrows = true,
        triggers = const {};

  final double w;
  final String? center;
  final String? primary;           // small, above
  final String? secondary;         // big, below
  final String? symbolTopRight;    // ⌘ ⌥ ⌃ top-right
  final IconData? icon;            // icon-only keys and Fn icons
  final String? labelBottomLeft;   // esc, tab, capslock, shift, fn, control...
  final String? labelTopRight;     // delete/return/right-shift — bottom-right in our layout
  final String? bottomFnText;      // F1..F12 legend
  final bool dotLed;
  final bool glow;
  final bool stackedArrows;        // up/down stack in one key slot
  final Set<LogicalKeyboardKey> triggers;

  bool isPressed(Set<LogicalKeyboardKey> pressed) =>
      triggers.isNotEmpty && triggers.any((k) => pressed.contains(k));
}

class KeyCap extends StatelessWidget {
  const KeyCap({
    super.key,
    required this.spec,
    required this.t,
    required this.pressed,
    required this.capsOn,
  });
  final KeyCapSpec spec;
  final KeyboardTheme t;
  final Set<LogicalKeyboardKey> pressed;
  final bool capsOn;

  @override
  Widget build(BuildContext context) {
    final r = t.keyRadius;

    if (spec.stackedArrows) {
      const g = 6.0;
      final isUp = pressed.contains(LogicalKeyboardKey.arrowUp);
      final isDown = pressed.contains(LogicalKeyboardKey.arrowDown);
      return SizedBox(
        height: t.keyHeight,
        child: Column(
          children: [
            Expanded(child: _MiniKeyFace(t: t, r: r, icon: Icons.keyboard_arrow_up_rounded, pressed: isUp)),
            const SizedBox(height: g),
            Expanded(child: _MiniKeyFace(t: t, r: r, icon: Icons.keyboard_arrow_down_rounded, pressed: isDown)),
          ],
        ),
      );
    }

    final isDown = spec.isPressed(pressed);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: isDown ? 1 : 0),
      builder: (context, depth, _) {
        final shadow = _lerpShadows(t.keyDrop, t.keyDropPressed, depth);
        return Transform.translate(
          offset: Offset(0, 1.2 * depth),
          child: SizedBox(
            height: t.keyHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r + 2),
                boxShadow: shadow,
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(r),
                  child: Stack(
                    children: [
                      // Matte face
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(r),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: t.keyGradient,
                            ),
                            border: Border.all(color: t.keyStroke, width: 1),
                          ),
                        ),
                      ),
                      // Top diffuse highlight
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          height: lerpDouble(10, 7, depth)!,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [t.keyTopHighlight, Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      // Edge burn
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(r),
                            gradient: LinearGradient(
                              begin: Alignment.bottomRight,
                              end: const Alignment(0.0, -0.1),
                              colors: [t.underLip, Colors.transparent],
                              stops: const [0.0, 0.78],
                            ),
                          ),
                        ),
                      ),
                      // Soft inner shadow + speckle
                      Positioned.fill(
                        child: CustomPaint(painter: _InnerMatteShadow(radius: r, color: t.innerMatteShadow)),
                      ),
                      Positioned.fill(child: _MatteNoiseOverlay(opacity: t.noiseOnKeyOpacity)),
                      // Press overlay
                      if (depth > 0)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: t.pressedOverlay.withOpacity(0.10 * depth),
                            ),
                          ),
                        ),

                      // Legends and icons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                        child: _KeyLegend(spec: spec, t: t),
                      ),

                      // Spartan glow for F1
                      if (spec.glow) _f1Glow(t),

                      // Caps LED only when capsOn is true
                      if (spec.dotLed && capsOn) _capsDot(t),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<BoxShadow> _lerpShadows(List<BoxShadow> a, List<BoxShadow> b, double t) {
    if (a.length != b.length) return b;
    return [for (int i = 0; i < a.length; i++) BoxShadow.lerp(a[i], b[i], t)!];
  }

  // Top-left green LED with bloom
  Widget _capsDot(KeyboardTheme t) {
    return Positioned(
      left: 14,
      top: 10,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: t.capsLed,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: t.capsLed.withOpacity(.75), blurRadius: 10, spreadRadius: 1.0),
            BoxShadow(color: t.capsLed.withOpacity(.45), blurRadius: 16, spreadRadius: 3.0),
          ],
        ),
      ),
    );
  }

  // Centered glow so it lines up with centered “F1”
  Widget _f1Glow(KeyboardTheme t) {
    return Align(
      alignment: const Alignment(0, -0.18),
      child: _HelmetGlow(size: 20, color: t.f1Glow),
    );
  }
}

class _MiniKeyFace extends StatelessWidget {
  const _MiniKeyFace({required this.t, required this.r, this.icon, required this.pressed});
  final KeyboardTheme t;
  final double r;
  final IconData? icon;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: pressed ? 1 : 0),
      builder: (context, depth, _) {
        final shadow = _lerpShadows(t.keyDrop, t.keyDropPressed, depth);
        return Transform.translate(
          offset: Offset(0, 1.2 * depth),
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(r + 2), boxShadow: shadow),
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(r),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: t.keyGradient,
                          ),
                          border: Border.all(color: t.keyStroke, width: 1),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: lerpDouble(10, 7, depth)!,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [t.keyTopHighlight, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r),
                          gradient: LinearGradient(
                            begin: Alignment.bottomRight,
                            end: const Alignment(0.0, -0.1),
                            colors: [t.underLip, Colors.transparent],
                            stops: const [0.0, 0.78],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(child: CustomPaint(painter: _InnerMatteShadow(radius: r, color: t.innerMatteShadow))),
                    Positioned.fill(child: _MatteNoiseOverlay(opacity: t.noiseOnKeyOpacity)),
                    if (depth > 0)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: t.pressedOverlay.withOpacity(0.10 * depth),
                          ),
                        ),
                      ),
                    if (icon != null)
                      Align(alignment: Alignment.center, child: Icon(icon, size: 18, color: t.iconColor)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<BoxShadow> _lerpShadows(List<BoxShadow> a, List<BoxShadow> b, double t) {
    if (a.length != b.length) return b;
    return [for (int i = 0; i < a.length; i++) BoxShadow.lerp(a[i], b[i], t)!];
  }
}

/* -------------------------------------------------------------------------- */
/*                         LEGEND LAYOUT & SPACING                            */
/* -------------------------------------------------------------------------- */

class _KeyLegend extends StatelessWidget {
  const _KeyLegend({required this.spec, required this.t});
  final KeyCapSpec spec;
  final KeyboardTheme t;

  @override
  Widget build(BuildContext context) {
    final letter = t.letterStyle;
    final small = t.smallStyle;

    return Stack(
      children: [
        if (spec.labelBottomLeft != null)
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 0, bottom: 2),
              child: Text(spec.labelBottomLeft!, style: small),
            ),
          ),
        if (spec.labelTopRight != null)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(spec.labelTopRight!, style: small),
            ),
          ),
        if (spec.symbolTopRight != null)
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(spec.symbolTopRight!, style: small),
            ),
          ),
        if (spec.icon != null)
          Align(
            alignment: spec.bottomFnText != null ? const Alignment(0, -0.18) : Alignment.center,
            child: Icon(spec.icon, size: 18, color: t.iconColor),
          ),
        if (spec.bottomFnText != null)
          Align(alignment: const Alignment(0, 0.82), child: Text(spec.bottomFnText!, style: small)),
        if (spec.primary != null || spec.secondary != null)
          Align(
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (spec.primary != null)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(spec.primary!, style: small)),
              if (spec.secondary != null) Text(spec.secondary!, style: letter),
            ]),
          ),
        if (spec.center != null) Align(alignment: Alignment.center, child: Text(spec.center!, style: letter)),
      ],
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                    THEME                                   */
/* -------------------------------------------------------------------------- */

class KeyboardTheme {
  KeyboardTheme({
    required this.canvas,
    required this.boardGradient,
    required this.boardEdge,
    required this.boardShadows,
    required this.boardInnerSheen,
    required this.boardRadius,
    required this.noiseColor,
    required this.noiseOpacity,
    required this.vignette,

    required this.keyHeight,
    required this.keyGradient,
    required this.keyStroke,
    required this.keyDrop,
    required this.keyDropPressed,
    required this.rimLight,
    required this.underLip,

    required this.keyTopHighlight,
    required this.innerMatteShadow,
    required this.pressedOverlay,

    required this.letterStyle,
    required this.smallStyle,
    required this.iconColor,
    required this.capsLed,
    required this.f1Glow,
    required this.keyRadius,

    required this.noiseOnKeyOpacity,
  });

  // canvas / board
  final Color canvas;
  final List<Color> boardGradient;
  final Color boardEdge;
  final List<BoxShadow> boardShadows;
  final Color boardInnerSheen;
  final double boardRadius;
  final Color noiseColor;
  final double noiseOpacity;
  final Color vignette;

  // keys
  final double keyHeight; // 72
  final List<Color> keyGradient;
  final Color keyStroke;
  final List<BoxShadow> keyDrop;
  final List<BoxShadow> keyDropPressed;
  final Color rimLight;
  final Color underLip;

  // per-theme surface treatments
  final Color keyTopHighlight;
  final Color innerMatteShadow;
  final Color pressedOverlay;

  // legends / accents
  final TextStyle letterStyle;
  final TextStyle smallStyle;
  final Color iconColor;
  final Color capsLed;
  final Color f1Glow;
  final double keyRadius;

  // noise on key surface
  final double noiseOnKeyOpacity;

  // DARK
  factory KeyboardTheme.darkCloseUp() {
    return KeyboardTheme(
      canvas: const Color(0xFF0A0B0D),
      boardGradient: const [Color(0xFF191B1F), Color(0xFF0F1114)],
      boardEdge: const Color(0xFF2B2F34),
      boardShadows: const [
        BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: -8, offset: Offset(0, 18)),
        BoxShadow(color: Color(0x33000000), blurRadius: 10, spreadRadius: -6, offset: Offset(-6, -6)),
      ],
      boardInnerSheen: const Color(0x14FFFFFF),
      boardRadius: 18,

      noiseColor: const Color(0xFF000000),
      noiseOpacity: .035,
      vignette: const Color(0x7A000000),

      keyHeight: 72,
      keyGradient: const [Color(0xFF212226), Color(0xFF15171A)],
      keyStroke: const Color(0xFF2C2F34),
      keyDrop: const [
        BoxShadow(color: Colors.black54, offset: Offset(0, 5), blurRadius: 10, spreadRadius: -1),
        BoxShadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 1),
      ],
      keyDropPressed: const [
        BoxShadow(color: Colors.black38, offset: Offset(0, 3), blurRadius: 6, spreadRadius: -1),
        BoxShadow(color: Colors.black26, offset: Offset(0, 0.5), blurRadius: 0.8),
      ],
      rimLight: const Color(0x33FFFFFF),
      underLip: const Color(0x23000000),

      keyTopHighlight: const Color(0x12FFFFFF),
      innerMatteShadow: const Color(0x2A000000),
      pressedOverlay: const Color(0xFF000000),

      letterStyle: const TextStyle(
        color: Color(0xFFE7EBF1),
        fontWeight: FontWeight.w600,
        letterSpacing: .15,
        fontSize: 18,
        height: 1.0,
      ),
      smallStyle: const TextStyle(
        color: Color(0xFFAEB5C0),
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: .2,
        height: 1.0,
      ),
      iconColor: const Color(0xFFDCE3EC),
      capsLed: const Color(0xFF7CFFA7),
      f1Glow: const Color(0xFFFF2B2B),

      keyRadius: 8,
      noiseOnKeyOpacity: .028,
    );
  }

  // LIGHT — airy, soft below, white lift top-left
  factory KeyboardTheme.lightCloseUp() {
    return KeyboardTheme(
      canvas: const Color(0xFFF6F7FA),
      boardGradient: const [Color(0xFFF4F6FA), Color(0xFFFFFFFF)],
      boardEdge: const Color(0xFFE1E6EE),
      boardShadows: const [
        BoxShadow(color: Color(0x1A000000), blurRadius: 22, spreadRadius: -10, offset: Offset(0, 16)),
        BoxShadow(color: Color(0x33FFFFFF), blurRadius: 10, spreadRadius: -8, offset: Offset(-8, -8)),
      ],
      boardInnerSheen: const Color(0x22FFFFFF),
      boardRadius: 18,

      noiseColor: const Color(0xFF000000),
      noiseOpacity: .02,
      vignette: const Color(0x14000000),

      keyHeight: 72,
      keyGradient: const [Color(0xFFFFFFFF), Color(0xFFF2F4F8)],
      keyStroke: const Color(0xFFE6EAF1),
      keyDrop: const [
        BoxShadow(color: Color(0x19000000), offset: Offset(0, 3), blurRadius: 6, spreadRadius: -1),
        BoxShadow(color: Color(0x66FFFFFF), offset: Offset(-2, -2), blurRadius: 5, spreadRadius: -3),
        BoxShadow(color: Color(0x0D000000), offset: Offset(0, 12), blurRadius: 20, spreadRadius: -6),
      ],
      keyDropPressed: const [
        BoxShadow(color: Color(0x14000000), offset: Offset(0, 2), blurRadius: 5, spreadRadius: -1),
        BoxShadow(color: Color(0x55FFFFFF), offset: Offset(-1.5, -1.5), blurRadius: 4, spreadRadius: -3),
        BoxShadow(color: Color(0x0D000000), offset: Offset(0, 10), blurRadius: 16, spreadRadius: -6),
      ],
      rimLight: const Color(0x88FFFFFF),
      underLip: const Color(0x16000000),

      keyTopHighlight: const Color(0x44FFFFFF),
      innerMatteShadow: const Color(0x14000000),
      pressedOverlay: const Color(0xFF000000),

      letterStyle: const TextStyle(
        color: Color(0xFF222A36),
        fontWeight: FontWeight.w700,
        letterSpacing: .1,
        fontSize: 18,
        height: 1.0,
      ),
      smallStyle: const TextStyle(
        color: Color(0xFF4B5567),
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: .15,
        height: 1.0,
      ),
      iconColor: const Color(0xFF273142),
      capsLed: const Color(0xFF2BD66B),
      f1Glow: const Color(0xFFFF2B2B),

      keyRadius: 8,
      noiseOnKeyOpacity: .018,
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               THEME SWITCH PILL                            */
/* -------------------------------------------------------------------------- */

class _ThemePill extends StatelessWidget {
  const _ThemePill({required this.dark, required this.onChanged, required this.pillLabel});
  final bool dark;
  final ValueChanged<bool> onChanged;
  final String pillLabel;

  @override
  Widget build(BuildContext context) {
    final onLight = !dark;

    Color textColor(bool active) {
      if (active) return onLight ? const Color(0xFF202733) : Colors.black;
      return onLight ? const Color(0xFF4B5563) : Colors.white70;
    }

    Color iconColor(bool active) {
      if (active) return const Color(0xFF2962FF);
      return onLight ? const Color(0xFF9CA3AF) : Colors.white70;
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onLight ? Colors.white : const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          if (onLight) const BoxShadow(blurRadius: 16, color: Color(0x22000000), offset: Offset(0, 4)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _seg('Light', !dark, () => onChanged(false), textColor, iconColor),
        _seg('Dark', dark, () => onChanged(true), textColor, iconColor),
      ]),
    );
  }

  Widget _seg(
      String label,
      bool active,
      VoidCallback onTap,
      Color Function(bool) textColor,
      Color Function(bool) iconColor,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: active
              ? const [BoxShadow(blurRadius: 10, color: Color(0x22000000), offset: Offset(0, 4))]
              : const [],
        ),
        child: Row(children: [
          Icon(
            active ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.circle,
            size: 16,
            color: iconColor(active),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: textColor(active))),
        ]),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                           MATTE SHADOWS & TEXTURE                          */
/* -------------------------------------------------------------------------- */

class _InnerMatteShadow extends CustomPainter {
  final double radius;
  final Color color;
  const _InnerMatteShadow({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.saveLayer(Offset.zero & size, Paint());
    final g = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.center,
        colors: [color, const Color(0x00000000)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, g);
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawRRect(rrect.deflate(1.0), clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InnerMatteShadow oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}

class _HelmetGlow extends StatelessWidget {
  const _HelmetGlow({super.key, required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.65), blurRadius: 16, spreadRadius: 2),
                  BoxShadow(color: color.withOpacity(0.25), blurRadius: 28, spreadRadius: 8),
                ],
              ),
            ),
          ),
          SizedBox(width: size, height: size, child: CustomPaint(painter: _HelmetPainter(color: color))),
        ],
      ),
    );
  }
}

class _HelmetPainter extends CustomPainter {
  final Color color;
  const _HelmetPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Path()
      ..moveTo(0.62 * w, 0.08 * h)
      ..quadraticBezierTo(0.28 * w, -0.02 * h, 0.16 * w, 0.34 * h)
      ..quadraticBezierTo(0.08 * w, 0.52 * h, 0.26 * w, 0.66 * h)
      ..lineTo(0.40 * w, 0.66 * h)
      ..lineTo(0.52 * w, 0.80 * h)
      ..lineTo(0.60 * w, 0.66 * h)
      ..lineTo(0.80 * w, 0.66 * h)
      ..quadraticBezierTo(0.95 * w, 0.66 * h, 0.88 * w, 0.38 * h)
      ..quadraticBezierTo(0.84 * w, 0.16 * h, 0.62 * w, 0.08 * h)
      ..close();

    final fill = Paint()..color = color;
    canvas.drawPath(body, fill);

    final hl = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        radius: 0.9,
        colors: [const Color(0xFFFFFFFF).withOpacity(0.35), Colors.transparent],
      ).createShader(Offset.zero & size)
      ..blendMode = BlendMode.plus;
    canvas.drawPath(body, hl);

    final visor = Path()
      ..moveTo(0.59 * w, 0.42 * h)
      ..quadraticBezierTo(0.50 * w, 0.37 * h, 0.44 * w, 0.44 * h)
      ..quadraticBezierTo(0.50 * w, 0.46 * h, 0.59 * w, 0.46 * h)
      ..close();
    canvas.saveLayer(Offset.zero & size, Paint());
    final punch = Paint()..blendMode = BlendMode.clear;
    canvas.drawPath(visor, punch);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HelmetPainter oldDelegate) => false;
}

class _MatteNoiseOverlay extends StatelessWidget {
  final double opacity;
  const _MatteNoiseOverlay({super.key, this.opacity = 0.03});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _NoisePainter(opacity: opacity),
        isComplex: false,
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  _NoisePainter({this.color = Colors.white, required this.opacity});
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7);
    final paint = Paint()..color = color.withOpacity(opacity);
    final count = (size.width * size.height / 120).clamp(200, 1200).toInt();
    for (int i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.35, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.color != color;
}
