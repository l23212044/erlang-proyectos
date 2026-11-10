---
name: Tactical Sentinel C4
colors:
  surface: '#0c1324'
  surface-dim: '#0c1324'
  surface-bright: '#33394c'
  surface-container-lowest: '#070d1f'
  surface-container-low: '#151b2d'
  surface-container: '#191f31'
  surface-container-high: '#23293c'
  surface-container-highest: '#2e3447'
  on-surface: '#dce1fb'
  on-surface-variant: '#bec8d2'
  inverse-surface: '#dce1fb'
  inverse-on-surface: '#2a3043'
  outline: '#88929b'
  outline-variant: '#3e4850'
  surface-tint: '#89ceff'
  primary: '#89ceff'
  on-primary: '#00344d'
  primary-container: '#0ea5e9'
  on-primary-container: '#003751'
  inverse-primary: '#006591'
  secondary: '#b7c8e1'
  on-secondary: '#213145'
  secondary-container: '#3a4a5f'
  on-secondary-container: '#a9bad3'
  tertiary: '#4edea3'
  on-tertiary: '#003824'
  tertiary-container: '#00b17b'
  on-tertiary-container: '#003b26'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#c9e6ff'
  primary-fixed-dim: '#89ceff'
  on-primary-fixed: '#001e2f'
  on-primary-fixed-variant: '#004c6e'
  secondary-fixed: '#d3e4fe'
  secondary-fixed-dim: '#b7c8e1'
  on-secondary-fixed: '#0b1c30'
  on-secondary-fixed-variant: '#38485d'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#0c1324'
  on-background: '#dce1fb'
  surface-variant: '#2e3447'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: 0em
  body-lg:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
    letterSpacing: 0em
  body-md:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: 0em
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0em
  stat-lg:
    fontFamily: JetBrains Mono
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 28px
    letterSpacing: -0.02em
  stat-md:
    fontFamily: JetBrains Mono
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: -0.01em
  mono-code:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0em
  mono-timestamp:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 14px
    letterSpacing: 0.02em
  label-caps:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 12px
    letterSpacing: 0.08em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 0.75rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

### Brand Personality & Core Intent
The brand personality is uncompromisingly tactical, vigilant, and mission-critical. Designed for urban control centers (C4/C5/C2), incident commanders, and field patrol supervisors operating high-throughput Erlang/OTP monitoring engines, the UI communicates absolute operational certainty. It strips away cosmetic ornament to minimize cognitive burden, prioritize rapid anomaly triage, and deliver uncompromised visual clarity under hostile lighting conditions—ranging from dark control room consoles to glaring midday sunlight in field units.

### Target Audience & Operational Demands
- Field supervisors and mobile emergency dispatchers managing high-density telemetry streams.
- Security perimeter operators executing access control grants, lockouts, and live stream spot-checks.
- Infrastructure reliability engineers overseeing real-time Erlang/OTP process trees, ETS memory ingestion, and cryptographic chain audits.

### Visual Style
The design language combines **Tactical High-Contrast Minimalism** with **Functional Skeuomorphic Micro-Affordances**:
- **Deep Slate Grounding**: Layered dark surfaces anchored in near-black slate (`#020617` and `#0b1120`), eliminating light bleed and preserving night vision while optimizing OLED power consumption.
- **Precision Engineering**: Crisp 1px structural outlines (`#1e293b` and `#334155`), razor-thin dividers, and tabular telemetry feeds that reflect high-reliability distributed systems.
- **Unambiguous Chromatic Semantics**: Zero decorative usage of status tones. Green, amber, red, and cyan are reserved strictly for deterministic operational states.

## Colors

### Canvas & Surface Architecture
- **Canvas Base (`#020617` / slate-950)**: Deep, low-reflectance canvas backing all screen layouts.
- **Surface Low (`#0b1120`)**: Base background for cards, list modules, and modal backdrops.
- **Surface Default (`#0f172a` / slate-900)**: Elevated telemetry cards, input fields, and panel wrappers.
- **Surface High (`#1e293b` / slate-800)**: Active toggles, elevated headers, bottom navigation bars, and interactive pill backgrounds.
- **Surface Highest (`#334155` / slate-700)**: Structural borders, dividing lines, and disabled touch surfaces.

### Functional Status Semantics
Color is strictly functional; it conveys systemic state without ambiguity:
- **Operativo / Concedido / OK (`#10b981` / emerald-500)**: Used for active feeds, valid credentials, verified SHA-256 hashes, and healthy OTP workers. Paired with background `#022c22` and text `#a7f3d0`.
- **Alerta / Advertencia / SOS (`#f59e0b` / amber-500)**: Used for perimeter motion triggers, NTP time drifts (> 3.0s), buffer pressure, and non-fatal operational bottlenecks. Paired with background `#451a03` and text `#fde68a`.
- **Crítico / Falla / Denegado / Offline (`#ef4444` / red-500)**: Used for severed nodes, biometric/card rejections, supervisor crash events, and tampered hash sequences. Paired with background `#450a0a` and text `#fecaca`.
- **Enlace Activo / Proceso / Info (`#0ea5e9` / sky-500)**: Used for live RTSP streaming, active WebSocket tunnels, focus rings, and primary execution commands. Paired with background `#082f49` and text `#bae6fd`.

### Text Contrast Tiers
- **High-Contrast Value Text (`#f8fafc` / slate-50)**: Critical metrics, node labels, and emergency headers.
- **Readable Secondary (`#cbd5e1` / slate-300)**: Facility metadata, parameter labels, and dense log descriptions.
- **Muted Technical Text (`#94a3b8` / slate-400)**: Axis lines, secondary timestamps, and network protocol tags.
- **Subdued Trace (`#64748b` / slate-500)**: Bypass indicators and empty state placeholders.

## Typography

### Structural Duality
The system mandates a strict functional division between two typefaces:
- **Inter** handles narrative structure, UI control labels, form titles, and operational summaries. It offers exceptional micro-scale legibility on low-resolution or sunlight-exposed mobile panels.
- **JetBrains Mono** governs all technical data: hardware node identifiers, IP addresses, RTSP URLs, RFID tags, cryptographic hashes, and high-frequency millisecond timestamps.

### Tabular Figures & Scanability
- All numeric data in both fonts must enforce tabular figures (`font-variant-numeric: tabular-nums; font-feature-settings: "tnum" 1`) to eliminate jitter and layout shifts during 60 Hz telemetry updates.
- Section tags, hardware roles, and severity categories employ `label-caps` with uppercase styling and expanded tracking (`0.08em`) to enable immediate peripheral classification by the operator.

## Layout & Spacing

### Mobile-First Layout Model
The layout adheres to a single-column, fluid mobile grid configured for 360px to 430px viewports, bounded by a maximum mobile width of 480px when displayed on wider tablets or vehicle dashboard docks:
- **Horizontal Screen Margins**: Constant 16px (`1rem`) on standard viewports, expanding to 24px (`1.5rem`) on tablets.
- **Grid Gutters**: 12px (`0.75rem`) horizontal separation between telemetry metric tiles and quick-selection chips.
- **Component Densities**: Micro-spacing (4px to 8px) between metric label-value pairs ensures 4 to 6 live event log entries or 2 live video cards remain visible above the fold on modern mobile handsets.

### Ergonomics & Safe Areas
- Top app bars incorporate native status bar height plus 56px of operational title/connection breadcrumb area.
- Bottom actions anchor within a persistent 64px dock accommodating `env(safe-area-inset-bottom)`.
- All primary interactive elements maintain a hard minimum touch envelope of 48x48px to permit rapid gloved or one-handed operation during critical incidents.

## Elevation & Depth

### Depth Through Surface Luminance & Micro-Outlines
The design system avoids diffused ambient shadows, which introduce visual mud in dark environments. Hierarchy is achieved through systematic surface illumination tiers and sharp 1px hairline borders:

1. **Level 0 (Canvas Backing - `#020617`)**: Base screen ground containing scrollable lists and background grids.
2. **Level 1 (Card & Module Containers - `#0f172a`)**: Bounded by a 1px border in `#334155`. Cards establish physical boundaries without casting muddy drop shadows.
3. **Level 2 (Active Controls & Headers - `#1e293b`)**: Elevated toolbars, sticky date/time range shelves, and selected interactive chips. Framed by a 1px outline in `#475569`.
4. **Level 3 (Modals, Tactical Sheets & Bottom Bar - `#0b1120` with 95% opacity)**: Utilizes `backdrop-filter: blur(12px)` and a top hairline border of `#38bdf8` (accent) or `#334155` (neutral).

### Active Status Glows
Telemetry alerts use focused, low-spread color halos rather than standard drop shadows:
- **Normal Process Focus**: `0 0 0 1px #0ea5e9, 0 0 12px rgba(14, 165, 233, 0.35)`
- **Critical Alert / Intrusión**: `0 0 0 1px #ef4444, 0 0 16px rgba(239, 68, 68, 0.45)`
- **Live Stream Indicator**: `0 0 8px rgba(16, 185, 129, 0.5)`

## Shapes

### Edge Philosophy
The shape profile corresponds to Level 2 (Rounded) with a disciplined industrial interpretation:
- **Base Components (Inputs, Buttons, Badges)**: 8px border-radius (`rounded-md`). This prevents accidental softness while avoiding sharp, brittle 90-degree corners on ruggedized mobile touch displays.
- **Structural Modules (Camera Cards, Telemetry Panels, Drawers)**: 12px border-radius (`rounded-lg`). Provides containment for inner nested metrics without clipping video stream edges.
- **Status Beacons & Micro-Chips**: Fully rounded (`rounded-full`) reserved strictly for live connection status dots, count pill indicators, and quick-filter tags.

## Components

### Buttons
- **Primary Tactical Action**: Minimum height of 48px. Solid `#0ea5e9` fill with `#ffffff` text, framed with an inner contrast border (`border border-sky-400/30`). Pressed state: `#0284c7` with micro-scale feedback (`transform: scale(0.98)`).
- **Emergency Lockdown / SOS**: Minimum height of 52px. Full `#ef4444` background with white uppercase text (`Inter Bold 13px`). Contains a rhythmic pulsing border ring signaling urgency.
- **Secondary / Action Tool**: `#1e293b` fill, 1px `#334155` border, `#cbd5e1` text. Active state triggers `#0369a1` with `#38bdf8` outline.

### Status Chips & Live Pulse Beacons
- **Live Pulse Beacon**: An 8px circular emitter containing a solid inner core (`#10b981`) and an outer concentric ring executing an asynchronous continuous ping animation, reflecting real-time Erlang process heartbeats.
- **Severity Badge**: Compact pill (height 22px, `rounded-full`, horizontal padding 8px). Contains status label in `label-caps` typography:
  - *OK*: Surface `#022c22`, text `#a7f3d0`, border `#10b981/40`.
  - *ALERTA*: Surface `#451a03`, text `#fde68a`, border `#f59e0b/40`.
  - *CRÍTICO*: Surface `#450a0a`, text `#fecaca`, border `#ef4444/50`.
  - *SYNC*: Surface `#082f49`, text `#bae6fd`, border `#0ea5e9/40`.

### Node Cards (Cameras & Access Portals)
- **Top Aspect Container (16:9)**: Live stream preview or camera stand-by schematic. Overlay top-left: live beacon + `EN VIVO` pill. Overlay top-right: tabular telemetry overlay (`30 FPS | 18 ms`).
- **Body Section**: Primary node name (`Inter SemiBold 15px`), secondary hardware identifier (`JetBrains Mono 12px` in `#94a3b8`), and physical location string.
- **Bottom Telemetry Strip**: 3-column micro-grid showcasing GenServer worker latency, ETS buffer capacity, and NTP time offset with micro-warning flags if offset exceeds threshold.

### Event Log & Ledger (Bitácora)
- **Entry Structure**: Row height of 54px with 1px bottom border in `#1e293b`.
- **Left Column**: Exact timestamp down to the millisecond (`JetBrains Mono 11px` in `#94a3b8`).
- **Center Column**: Event icon followed by device tag and event summary string.
- **Right Column**: Cryptographic verification badge. Displays `SHA-256 ÍNTEGRO` in green with locked padlock micro-icon; flips to an urgent flashing crimson badge (`CADENA ALTERADA`) upon hash verification failure.

### Inputs & Time-Range Selectors
- **Timestamp Filter Inputs**: Height 48px, background `#0f172a`, border 1px `#334155`. Value rendered in `JetBrains Mono 12px` (`YYYY-MM-DD HH:mm:ss`). Focus state activates `#0ea5e9` border with a 2px diffuse cyan glow.
- **Quick-Time Horizontal Selector**: Low-profile horizontal scrolling track with segment pills (`[15m]`, `[1h]`, `[24h]`, `[Turno]`, `[Ayer]`). Inactive: `#1e293b` fill with `#94a3b8` text. Selected: `#0284c7` with white text.

### Checkboxes & Toggle Switches
- **Switches**: 48x28px pill track. Off: `#1e293b` with `#64748b` thumb. On: `#0ea5e9` track with `#ffffff` thumb and cyan glow.
- **Tactical Checkboxes**: 20x20px square with 4px border-radius. Inactive: `#0f172a` surface with `#475569` border. Selected: `#0ea5e9` with bold checkmark icon in `#ffffff`.