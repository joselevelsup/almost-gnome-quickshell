# Design policy

Guide for keeping the shell visually consistent. Every new piece (popup, bar
widget, component) must follow these rules; if something doesn't fit, discuss
it and update this document before breaking them.

## 1. Principles

1. **Vanilla GNOME 50 first.** The visual reference is GNOME Shell 50, as close
   to vanilla GNOME as possible: opaque surfaces, rounded corners, system
   accent, monochrome symbolic icons. When in doubt, "how would GNOME do it?".
   Don't add non-GNOME extras to the top bar.
2. **The system decides the accent.** The shell is dark theme only; the accent
   color follows gsettings (`org.gnome.desktop.interface accent-color`) live
   via `Theme.qml`. Never hardcode an accent in a component.
3. **Direct, not nested.** Frequent actions are one click away. Destructive or
   infrequent ones (power off, restart…) go behind an expander, not in the
   main view.
4. **State is visible.** Every control that represents a state (Wi-Fi,
   floating, current wallpaper, current workspace) shows it with the accent,
   and its secondary text states it in words ("Off", "Disconnected").
5. **Small screen.** The reference machine is 1366×768. No popup should exceed
   ~620 px in height; long lists scroll (`Flickable`).

### Top bar layout

- **Left:** workspace indicator pill (opens umbriel's overview). No Activities label.
- **Center:** clock (opens calendar/notifications).
- **Right:** system tray, then status icons (open quick settings).

User-facing options go in the Settings window (`SettingsWindow.qml`), stored in
`Settings.options`; don't add one-off config files.

## 2. Tokens (`Theme.qml`)

Colors, radii and fonts are taken **only** from `Theme`. No hex colors in
components, except for the exceptions listed below.

### Color

| Token | Use |
|---|---|
| `fg` / `fgDim` | Primary / secondary text and icons, section labels |
| `accent` / `accentHover` | Active/selected state (fill) and its hover |
| `accentFg` | Text and icons on `accent` |
| `danger` | Destructive actions (Power off, Close window) — icon/text only |
| `ok` | Confirmations/success |
| `barBg` / `popupBg` / `toastBg` | Bar, popup and toast background |
| `cardBg` / `cardHoverBg` | Surface of tiles, buttons and cards **inside** a popup |
| `hoverBg` | Hover of flat rows (`ActionRow`, inactive segments) |
| `activeBg` | Selected item inside the app grid/popups (bar buttons use white, like GNOME) |
| `trackBg` | Track of sliders and switches that are off |
| `border` | 1 px border of popups and separators |

Allowed exceptions: `#ffffff` for slider/switch knobs and text over images;
`#000000` with alpha for gradients/dimming over images (always via
`Theme.withAlpha`).

Surfaces are opaque, like vanilla GNOME: the top bar is
solid black like GNOME, and popups use opaque Adwaita dark surfaces.

> ⚠️ No property may start with `on` + uppercase (`onAccent`): QML interprets
> it as a signal handler and the whole singleton fails to load.

### Radii

| Value | Use |
|---|---|
| `Theme.radius` (18) | Popup card |
| `radius - 2` (16) | Inner cards, tiles, preview |
| `radius - 6` (12) | Rows, chips, thumbnails |
| `height / 2` | Pills: bar buttons, quick toggles, `IconButton`, `SegmentedControl`, badges |

### Typography

Font `Theme.fontFamily` (Adwaita Sans); `monoFontFamily` only for code or
tabular data.

| Size | Weight | Use |
|---|---|---|
| 13 | Bold | Popup title |
| 12 | DemiBold / Normal | Main label of rows and toggles |
| 11 | Normal | Values (%, time), segments, chips |
| 10 | Normal | Subtitle/state, help text |
| 10 | DemiBold, UPPERCASE, +0.6 tracking | `SectionLabel` |

Percentages and changing numbers use tabular figures (`font.features: { "tnum": 1 }`).

### Spacing

- `PopupCard` inner padding: 12 px; spacing between blocks: 10 px.
- Grid gaps: 8 px (toggles, thumbnails), 6 px (tiles, chips).
- Icon ↔ text in rows: 10 px. Row side margins: 10–16 px.
- Separators (1 px `Rectangle` with `Theme.border`) only when grouping with
  cards or `SectionLabel` isn't enough.

## 3. Components

Use an existing one before creating a new one. If you create one, it goes in
`components/`, with a header comment in English explaining what it is and
where it's used.

| Component | When to use it |
|---|---|
| `PopupCard` | Base of every popup anchored to the bar (`align`: left/center/right) |
| `BarButton` | Any bar button; `active` when its popup is open |
| `QuickToggle` | Turn a system feature on/off (2-column grid) |
| `TileButton` | Action or state on an object (window); 3-column grid |
| `IconButton` | Icon-only secondary action in headers; `checked` if it expands something |
| `SliderRow` | Continuous 0–1 value; the icon is clickable (mute) and accepts the wheel |
| `SegmentedControl` | Pick one option among 2–4 mutually exclusive ones |
| `ChipButton` | Compact option in a grid (workspaces, arrows); `dot` = has content |
| `ActionRow` | Menu item with text (power menu, actions with long labels) |
| `SectionLabel` | Header of a group inside a popup |
| `SymbolicIcon` | Every monochrome icon; never a direct `Image` for icons |
| `SettingsRow` | A row in the Settings window: title/subtitle with the control on the right |
| `TextField` | Single-line text entry; `committed` only fires for valid input |

### Popup anatomy

```
┌ PopupCard ─────────────────────────┐
│ Header: title/context + IconButtons │
│ (optional expander)                │
│ Main content                       │
│ SECTION LABEL                      │
│ Grouped controls                   │
└────────────────────────────────────┘
```

- The header gives context (which window, how many images, battery) and holds
  the secondary actions on the right.
- Most used at the top; destructive at the end or in an expander.
- Explicit empty state: dimmed icon + one line saying what to do.

## 4. States and interaction

| State | Treatment |
|---|---|
| Normal | `cardBg` (or transparent in flat rows) |
| Hover | `cardHoverBg` / `hoverBg`; `accentHover` if active |
| Pressed | `scale` 0.94–0.97, 90 ms `OutCubic` |
| Active / selected | `accent` fill, `accentFg` content, DemiBold weight |
| Disabled | `opacity: 0.4`; disable, don't hide, if the user should know it exists |
| Destructive | `danger` icon/text, never a red fill |

- Every clickable element gets `cursorShape: Qt.PointingHandCursor`.
- Controls are **controlled**: they emit `toggled(value)`/`clicked()` and don't
  overwrite their own `checked`; the real value comes back by binding from the
  service (Networking, Bluetooth, Umbriel…).
- After an action on umbriel, let `Umbriel.qml` refresh from its `subscribe` events so the UI reflects reality
  and not an assumption.
- When a popup closes, reset its transient states (expanders, hover).
- For hover over areas with interactive children, use `HoverHandler` instead of
  `MouseArea`.

## 5. Motion

| What | Duration | Curve |
|---|---|---|
| Hover / color change | 100–120 ms | linear |
| Opacity (enable, image load) | 100–150 ms | linear |
| Press (scale) | 90 ms | `OutCubic` |
| Switch / knob | 140 ms | `OutCubic` |
| Expand (height) | 160 ms | `OutCubic` |
| Popup open | 140 ms fade + 180 ms 6 px slide | `OutCubic` |

Nothing exceeds 200 ms. No bounces or close animations that delay
interaction.

## 6. Icons

- Active theme: **Adwaita** (`//@ pragma IconTheme Adwaita`), as in GNOME.
- Use freedesktop `*-symbolic` names. Before using a new one, check that it
  exists in Adwaita:
  ```sh
  find /usr/share/icons/Adwaita -name 'NAME-symbolic.svg'
  ```
- Beware of Adwaita title bar icons (`window-maximize`, `window-restore`): they
  render tiny. Prefer alternatives (`zoom-fit-best`, `focus-windows`).
- Custom icons: symbolic SVG in `assets/`, passed via `iconSource`.
- Sizes: 16 px (bar, default), 16 px (quick toggles), 18 px (tiles),
  11–14 px (badges, chips), 32 px (empty states).

## 7. Text

- UI in **English**. Use GNOME Shell's own wording and capitalization where an
  equivalent exists ("Log Out", "Do Not Disturb", "Pin to Dash"); otherwise
  sentence case for hints and subtitles.
- Short labels (1–2 words); details go in the subtitle.
- The subtitle describes the state, it doesn't repeat the label.
- Text that may overflow gets `elide: Text.ElideRight`.
- Code comments also in English, explaining the *why*.

## 8. Verification

Before considering a visual change done:

1. Load the config without errors: `qs -p .` and check the log (ignore the
   time zone warning and the duplicate notification server one).
2. Check the popup with a different accent color.
3. Check that it fits in 1366×768 and that empty/disabled states look right.
4. To capture a popup without clicking: copy the config to a temporary
   directory, initialize `PopupManager.current` with the popup's name, launch
   it with `timeout` and take the screenshot with `grim`.
