---
name: macos-visual-exploration
description: Layer 1 skill for native macOS UI documentation via screencapture and the Accessibility (AX) tree. Preflight permission doctoring, window reconnaissance, menu-bar traversal, AX-tree dumps, navigation-only flow capture, edge cases, screenshot methodology. Loaded by the analyzer agent for the ui-observer role.
---

# macOS Visual Exploration Methodology

Document behavioral intelligence through screen capture and Accessibility-tree inspection of a native macOS application. Every screenshot is an empirical observation. Every AX-tree dump is the machine-readable twin of that observation -- each capture ships both. This mode captures what the user SEES and what the system PRESENTS, without ever changing the user's data.

This skill is the native-macOS sibling of the `visual-exploration` skill. Where that skill drives a browser with Playwright, this skill drives the host's `screencapture` and System Events AX queries. The framing, output shapes, and provenance rules mirror `visual-exploration` deliberately; the interaction policy is stricter because the target runs on the user's host with the user's real data.

## When to Use This Mode

macOS visual exploration activates when the target is a native macOS application (an `.app` bundle), `macos-bundle-analysis` has run with the signature verified, and the user has granted host-observation consent covering `app-launch` and `visual`. All output is **RAW** (screenshots and AX dumps capture the target's proprietary UI in detail); it never reaches `workspace/output/` or `workspace/public/`.

## Host Execution Carve-Out

Runtime observation normally happens inside containers, no exceptions. Native macOS GUI applications cannot run in a Linux container, so this skill operates under a narrow carve-out: host observation is permitted ONLY when ALL of the following hold:

1. The target is a user-installed application, signed and notarized.
2. The signature has been verified: `workspace/raw/macos/bundle/signing.md` records a PASS.
3. Consent is recorded in `workspace/consent/macos-host-observation.md` with a `**Granted scopes:**` line covering the scopes this skill needs.
4. Every interaction with the application is read-only toward the application's data.

If any condition fails, the container rule governs and this skill must not run. You NEVER create or edit the consent artifact -- you verify it exists and read its scopes. A missing artifact or scope is an environmental gate: record it in `preflight-visual.md` and exit.

This skill requires the `app-launch` and `visual` scopes. `appearance-toggle` (dark mode switching) is NOT a standing scope -- it requires fresh per-action consent relayed through the orchestrator in the dispatch prompt each time (see Phase 5).

## Why macOS Visual Exploration Matters

Bundle analysis tells you what the app CAN do (capabilities, strings, entitlements). AppleScript exploration tells you what the app exposes to automation. Visual exploration tells you what the app LOOKS LIKE and how its interface is organized: affordances, the complete command surface with keyboard shortcuts, navigation structure (sidebars, tabs, window hierarchy), state representation as the user navigates, and feedback (selection, focus, enabled/disabled state). No other mode captures this.

## Interaction Policy: NAVIGATION vs. MUTATING

Every UI element gets the same classification `macos-bundle-analysis` applies to scripting commands: make/delete/move/duplicate/save/set verbs, or app-specific imperatives, are MUTATING; anything unknown is MUTATING. Consume its `capability-inventory.md` and strings catalog (`text-catalog.md`) for cross-checks throughout. The MUTATING prohibition targets the application's data and settings; System Events process/window/appearance attributes -- process visibility, window position/size, and the appearance toggle under per-action consent -- are sanctioned navigation-class operations WITH the mandatory restore obligations stated at each use site, not instances of the app-object `set` ban.

- **NAVIGATION** -- view switches, window operations (open/close/minimize/restore of windows, not documents), disclosure triangles, scrolling, tab selection, search fields (typed then cleared and verified). These may be activated. Search-field caveat: typed probes may persist in recent-searches stores outside the agent's view -- use innocuous probe strings (e.g. a single common letter) and note the possible persistence as an observation.
- **MUTATING** -- anything that creates, changes, or deletes user data or settings. NEVER activated. Documented from visible presence only: label, position, enabled state, and what they likely do inferred from the label cross-checked against the bundle strings catalog.

When in doubt, an element is MUTATING. A "New Task" button you did not press is still an observation -- an inferred one.

## Phase 0: Preflight Doctor

**Goal:** Verify every permission and precondition, pick a degradation mode BEFORE any exploration, and write `workspace/raw/macos/runtime/preflight-visual.md` with a PASS/FAIL table and exact remediation paths. Run all checks even after a failure -- the complete picture picks the mode.

### 0.1 Consent and Signature

`workspace/consent/macos-host-observation.md` exists with `app-launch` and `visual` in its `**Granted scopes:**` line; `workspace/raw/macos/bundle/signing.md` records a PASS. Either failing: record the gate, exit. Do not launch the app.

### 0.2 Accessibility Permission

```bash
osascript -e 'tell application "System Events" to return UI elements enabled'
```

Must print `true`. FAIL remediation (record verbatim): "System Settings > Privacy & Security > Accessibility > enable <parent terminal app>. TCC cannot be granted from the CLI."

### 0.3 Automation Permission (System Events)

Run a trivial query:

```bash
osascript -e 'tell application "System Events" to return name of first process'
```

Error -1743 ("Not authorized to send Apple events") means the Automation permission is missing or denied. Remediation: "System Settings > Privacy & Security > Automation > <parent terminal app> > enable System Events." If the first-use consent dialog cannot be answered non-interactively, record -1743 as a FAIL.

### 0.4 Screen Recording -- Silent-Failure Detection

Screen Recording permission attaches to the PARENT terminal app, and its failure mode is silent: `screencapture` exits 0 and writes a wallpaper-only image. Detect it empirically:

```bash
osascript -e "tell application id \"$BUNDLE_ID\" to activate"; sleep 1
screencapture -x workspace/raw/macos/runtime/screenshots/000-preflight-frontmost.png
osascript -e "tell application \"System Events\" to set visible of process \"$PROC\" to false"; sleep 1
screencapture -x workspace/raw/macos/runtime/screenshots/000-preflight-hidden.png
osascript -e "tell application \"System Events\" to set visible of process \"$PROC\" to true"
# Near-identical file sizes (within ~1%) => nothing app-specific captured => FAIL (wallpaper-only).
# Remediation: System Settings > Privacy & Security > Screen & System Audio Recording >
#   enable <parent terminal app>, then RESTART the terminal app.
# Size heuristic can false-negative: fallback is showing the user the capture and asking.
```

If hiding the app barely changes the image size, the app was never in the image. Another window behind the target can defeat the heuristic -- when unsure, show the user `000-preflight-frontmost.png` and ask.

### 0.5 Degradation Decision

Record the chosen mode in `preflight-visual.md` before any exploration:

| Mode | Condition | Consequence |
|------|-----------|-------------|
| **both** | Accessibility AND Screen Recording pass | Full methodology: PNGs + `.ax.md` sidecars |
| **AX-only** | Screen Recording fails | No PNGs; all evidence in `.ax.md` dumps and inventories, "screenshot" slots reference sidecars |
| **screenshots-only** | Accessibility fails | No AX means no menu traversal -- `command-surface.md` records the gap. Full-screen captures only |
| **abort** | Both fail, or a consent/signature gate | `preflight-visual.md` is the deliverable; the gates are environmental data |

### 0.6 Preflight Output Format

```markdown
# Preflight: Visual Exploration -- <App Name>

| Check | Result | Detail | Remediation |
|-------|--------|--------|-------------|
| Consent artifact + scopes | PASS | app-launch, visual granted | -- |
| Signature (signing.md) | PASS | Developer ID, notarized | -- |
| Accessibility | PASS | UI elements enabled = true | -- |
| Automation > System Events | PASS | trivial query returned | -- |
| Screen Recording | FAIL | captures within 0.4% size | Screen & System Audio Recording > enable <terminal>, restart it |

**Degradation mode:** AX-only
```

## Phase 1: Window Reconnaissance

**Goal:** Activate the app, enumerate every window via System Events, and capture each one. This seeds `window-inventory.md`.

### 1.1 Activation and Enumeration

```applescript
tell application id "com.example.app" to activate
tell application "System Events" to tell process "AppProcessName"
  repeat with w in windows
    log (name of w) & " | main=" & (value of attribute "AXMain" of w as text) ¬
      & " | minimized=" & (value of attribute "AXMinimized" of w as text)
  end repeat
end tell
```

Record per window: name, position, size, main flag, minimized flag.

### 1.2 Window-Scoped Capture Without CGWindowID

`screencapture -l <windowid>` captures a single window cleanly, but window IDs are unobtainable from a plain shell. The built-ins-only trick: read the window's frame from the AX tree and capture that rectangle:

```bash
read -r X Y W H <<< "$(osascript -e "tell application \"System Events\" to tell process \"$PROC\"
  set p to position of window 1
  set s to size of window 1
  return (item 1 of p as text) & \" \" & (item 2 of p as text) & \" \" & (item 1 of s as text) & \" \" & (item 2 of s as text)
end tell")"
screencapture -x -o -R"$X,$Y,$W,$H" workspace/raw/macos/runtime/screenshots/001-main-window.png
```

Fallback when the bounds query fails: full-screen `screencapture -x -o` with the app frontmost, noted in the manifest. Peekaboo-class tools that expose window IDs are an approved-install-only upgrade -- never install anything without explicit user approval.

### 1.3 Initial Assessment

Document, as the browser sibling does for a landing page: application shape (single-window, multi-window, library/document model), primary navigation (sidebar, source list, tab bar, toolbar), visible affordances (noting MUTATING buttons without pressing them), and window chrome (title, toolbar style, resizability).

## Phase 2: Menu-Bar Traversal

**Goal:** Walk the entire menu bar and produce `workspace/raw/macos/runtime/command-surface.md`. This IS the app's Complete Feature Inventory and All Keyboard Shortcuts from the analysis-pipeline's "What the Implementer Needs" -- the menu bar is the one place a macOS app is required to enumerate its own commands.

### 2.1 Recursive AppleScript Walk

Walk every menu with one submenu level:

```applescript
tell application "System Events" to tell process "Things3"
  set out to ""
  repeat with mbi in menu bar items of menu bar 1
    repeat with mi in menu items of menu 1 of mbi
      set out to out & (name of mbi) & " > " & (name of mi) ¬
        & tab & (value of attribute "AXMenuItemCmdChar" of mi as text) ¬
        & tab & (value of attribute "AXMenuItemCmdModifiers" of mi as text) ¬
        & tab & (enabled of mi as text) & linefeed
    end repeat
  end repeat
  return out
end tell
```

For items with a submenu, repeat one level down (`menu items of menu 1 of mi`), recording the full path (`File > Export > As PDF...`). Separators return `missing value` for name -- skip them without breaking the walk.

### 2.2 Decoding Shortcuts

`AXMenuItemCmdModifiers` is a bitmask over the Command-relative modifiers:

| Value | Modifiers | Value | Modifiers |
|-------|-----------|-------|-----------|
| 0 | ⌘ | 4 | ⌃⌘ |
| 1 | ⇧⌘ | 5 | ⌃⇧⌘ |
| 2 | ⌥⌘ | 6 | ⌃⌥⌘ |
| 3 | ⌥⇧⌘ | 7 | ⌃⌥⇧⌘ |

When `AXMenuItemCmdChar` is empty but a shortcut exists (arrow keys, function keys, Delete), read `AXMenuItemCmdVirtualKey` and decode the virtual key code.

### 2.3 Command Record Table

Every menu item gets a sequential `CMD-NNN` ID and a mutation class:

```markdown
| ID | Menu Path | Shortcut | Enabled | Mutation Class |
|----|-----------|----------|---------|----------------|
| CMD-041 | File > New To-Do | ⌘N | yes | MUTATING -- never invoke |
| CMD-042 | File > New Project | ⌥⌘N | yes | MUTATING -- never invoke |
| CMD-043 | View > Show Sidebar | ⌃⌘S | yes | NAVIGATION |
```

Cross-check each menu label against the bundle strings catalog (`workspace/raw/macos/bundle/text-catalog.md`). A label found in both the live menu and the strings catalog is two independent sources -- the command's existence is `confidence=confirmed`. What a MUTATING command DOES remains `inferred` from its label.

### 2.4 Menu Screenshots

Opening a menu to screenshot it (`menu-NNN-<menu>.png`) is NAVIGATION and permitted. Press Escape immediately after each capture -- an open menu left behind blocks subsequent AX queries. Cleanup is part of the observation.

## Phase 3: AX-Tree Dumps and Window Inventory

**Goal:** For EVERY screenshot, write a sidecar `<name>.ax.md` next to the `.png`, and complete `window-inventory.md`.

### 3.1 Why Sidecars

The sidecar keeps the evidence in `.md` form for downstream gates and synthesis agents that read text, and makes every pixel claim greppable. The AX dump and the screenshot of the same state are the SAME evidence group -- cross-note them, but never count the pair as two independent sources.

### 3.2 Sidecar Format

```markdown
# AX Snapshot: 001-main-window.png
**Window:** Things — Today   **Captured:** <timestamp>
- AXWindow "Things — Today" (0,25 1200x800)
  - AXSplitGroup
    - AXOutline (sidebar)
      - AXRow "Inbox" [selected=false]
      - AXRow "Today" [selected=true]
    - AXScrollArea (content)
      - AXButton "New To-Do" [enabled=true]
```

The walk records role, title/value, enabled state, position, and size per element, indented to mirror the hierarchy. `entire contents of window 1` is the quick-but-flat alternative -- one call, but it risks timing out on big windows; when it does, chunk the walk by top-level UI element (one query per split-group child, toolbar, sidebar).

### 3.3 Window Inventory Output

`window-inventory.md` mirrors `visual-exploration`'s `page-inventory.md`, one section per window:

```markdown
## Window: Things — Today

**Screenshot:** win-001-today.png (sidecar: win-001-today.ax.md)

### Interactive Elements

| Role | Title | Enabled | Action Taken | Screenshots |
|------|-------|---------|--------------|-------------|
| AXRow | Inbox | yes | navigation -- clicked | win-001-today.png, step-02-inbox.png |
| AXButton | New To-Do | yes | none (MUTATING) | win-001-today.png |
| AXTextField | Search | yes | navigation -- typed, cleared | step-05-search.png, step-06-search-cleared.png |
```

`Action Taken` is only ever `none` or `navigation`. There is no third value.

## Phase 4: Flow Documentation (Navigation-Only)

**Goal:** Document end-to-end navigation flows with a capture pair at every state transition. Each flow gets a directory `workspace/raw/macos/runtime/flows/<flow>/` containing `step-NN-*.png`, `step-NN-*.ax.md`, and `flow.md` -- mirroring `visual-exploration` exactly.

### 4.1 Core Flows to Document

| Flow | Description | Priority |
|------|-------------|----------|
| **View navigation** | Visit every sidebar/source-list destination, capture each | High |
| **Window lifecycle** | New window, close, reopen, restore -- window ops only, never documents | High |
| **Menu-driven view changes** | Invoke each NAVIGATION-classed CMD and capture the result | High |
| **Search/filter** | Type a query, observe results, press Escape, verify the field cleared | Medium |
| **Settings window** | Open Settings, screenshot every tab, CHANGE NOTHING | Medium |

### 4.2 Flow Format

Each `flow.md` uses the Step/Screenshot/Action/State/Feedback shape plus Behavioral Claims:

```markdown
# Flow: View Navigation

## Steps

### Step 1: Today View
**Screenshot:** step-01-today.png (sidecar: step-01-today.ax.md)
**Action:** Click sidebar row "Inbox" (NAVIGATION)
**State:** Main window frontmost, Today selected
**Feedback:** Selection highlight on Today row

### Step 2: Inbox View
**Screenshot:** step-02-inbox.png (sidecar: step-02-inbox.ax.md)
**Action:** none (arrival state)
**State:** Inbox selected, content repopulated
**Feedback:** Window title changed to "Things — Inbox"

## Behavioral Claims

- Selecting a sidebar destination updates the window title to match the destination name
  <!-- cite: source=visual-observation, ref=flows/view-navigation/step-02-inbox.ax.md, confidence=confirmed, agent=ui-observer -->
```

### 4.3 Interaction Policy for Flows

- Clicks only on NAVIGATION-classed elements.
- Keyboard input only for navigation shortcuts and search fields; every search field cleared afterward, verified by a follow-up capture.
- Before AND after captures per interaction -- the behavioral claim is the difference between the pair.
- Disabled elements documented as disabled, never forced.
- MUTATING elements documented from visible presence only, never activated.

## Phase 5: Edge Cases

**Goal:** Probe boundaries that reveal behavior -- without ever manufacturing state by touching data.

### 5.1 Window Resize

Record the original geometry first. Probe the minimum size and a large size, capture each, then RESTORE the original geometry and capture the restoration. Discovering the enforced minimum window size is a behavioral claim:

```markdown
- The main window enforces a minimum size of 640x480; resize attempts below this snap back
  <!-- cite: source=visual-observation, ref=screenshots/edge-resize-min.png, confidence=confirmed, agent=ui-observer -->
```

### 5.2 Dark Mode (Fresh Consent Required)

Appearance toggling changes a SYSTEM setting, and `appearance-toggle` is not a standing scope. Consent for EACH toggle must arrive via the dispatch prompt (relayed by the orchestrator); if no explicit grant is present, skip the dark-mode phase and record it as an untested gap. If granted:

```applescript
tell application "System Events" to tell appearance preferences to set dark mode to not dark mode
```

Capture the main views in the toggled appearance, then TOGGLE BACK unconditionally -- restoration is not contingent on capture success. If consent is declined, record dark-mode rendering as an untested gap in `visual-behaviors.md`.

### 5.3 Empty States

Document empty states ONLY if naturally present. NEVER delete or move data to manufacture one.

### 5.4 Out of Scope

Display and resolution variations (multiple monitors, scaled resolutions) are explicitly out of scope.

## Screenshot Naming Convention

| Prefix | Usage |
|--------|-------|
| `000-` | Phase 0: preflight captures |
| `001-` through `099-` | Phase 1: window reconnaissance |
| `win-NNN-` | Phase 3: window inventory captures |
| `menu-NNN-` | Phase 2: open-menu captures |
| `step-NN-` | Phase 4: flows (within the flow subdirectory) |
| `edge-` | Phase 5: edge case exploration |

### Directory Structure

```
workspace/raw/macos/runtime/
    screenshots/               # Flat (except flows); every .png has a .ax.md sidecar
        001-main-window.png
        001-main-window.ax.md
        win-001-today.png
        win-001-today.ax.md
        ...
    flows/
        view-navigation/
            step-01-today.png
            step-01-today.ax.md
            flow.md
    preflight-visual.md        # Phase 0 PASS/FAIL table + degradation mode
    window-inventory.md        # Per-window interactive element inventory
    command-surface.md         # Complete menu inventory with CMD-NNN records
    visual-behaviors.md        # Behavioral claims synthesized from all observations
    screenshot-manifest.md     # Every capture, its sidecar, and what it evidences
```

`screenshot-manifest.md` lists every capture with its sidecar and what it evidences. This satisfies output gates and lets specs cite records, not bare images. Do not write to `observations/` or `scripting/` -- those belong to the applescript-explorer role. Your observation records live inside your own output files.

## Provenance Rules

### Source Type

All claims from this skill use `source=visual-observation` with `agent=ui-observer`. The `ref` field is the screenshot path or the `.ax.md` sidecar path:

```markdown
- The sidebar lists six standard destinations: Inbox, Today, Upcoming, Anytime, Someday, Logbook
  <!-- cite: source=visual-observation, ref=screenshots/win-001-today.ax.md, confidence=confirmed, agent=ui-observer -->
```

### Confidence Levels

Identical to `visual-exploration`:

- **confirmed** -- the behavior is directly visible in a capture or demonstrated by a before/after pair
- **inferred** -- the element exists but was not exercised. This is the DEFAULT for ALL MUTATING elements: what a "Delete Project" menu item likely does comes from its label and the strings catalog, not from observation.
- **assumed** -- visual-cue guesswork (e.g., a grayed row is assumed to represent a disabled feature)

### Evidence Independence

- An AX dump and a screenshot of the SAME state are the SAME evidence group. Cross-note them, but they do not escalate confidence.
- The live menu inventory and the app's official documentation ARE independent sources -- agreement escalates to `confirmed`.
- The live menu inventory and the bundle strings catalog are independent for existence claims (the string was compiled in AND is presented live).

### Cite As You Go

Every behavioral claim gets an inline `<!-- cite: -->` comment immediately after the claim, per the provenance-methodology skill. Never defer citation.

## Failure Modes and Degradation

| Failure | Response |
|---------|----------|
| Screen Recording permission missing | AX-only mode: no PNGs, all evidence in `.ax.md` and inventories |
| Accessibility permission missing | Screenshots-only mode: no AX means no menu traversal; record the gap |
| Both missing | Abort; `preflight-visual.md` with remediation paths is the deliverable |
| Window-bounds query fails | Full-screen capture fallback, noted in the manifest |
| `entire contents` timeout | Chunked walk by top-level UI element |
| Dark-mode consent declined | Record as untested gap; do not toggle |
| App owned by another login session (error -1728 on process access) | Abort; the session boundary is environmental data |

Every failure mode produces data. A permission gate documented with its exact remediation path is a deliverable, not a dead end.

## Definition of Done

- [ ] `preflight-visual.md` records every check with PASS/FAIL, remediation paths for failures, and the chosen degradation mode
- [ ] Every window captured with its `.ax.md` sidecar (or gap-noted per the degradation mode)
- [ ] `command-surface.md` covers every menu item including submenus, with shortcut, enabled state, and mutation class; CMD-NNN IDs are sequential
- [ ] `window-inventory.md` complete, with `Action Taken` only ever `none` or `navigation`
- [ ] At least the View-navigation flow documented with before/after pairs
- [ ] All search fields cleared, window geometry restored, appearance restored -- with the restoration itself captured
- [ ] `visual-behaviors.md` synthesizes behavioral claims, every claim cited
- [ ] **Zero MUTATING elements invoked -- asserted explicitly in `visual-behaviors.md`**
- [ ] `screenshot-manifest.md` lists every capture, its sidecar, and what it evidences

## Rules

1. **Screenshots and AX dumps are RAW** -- they go to `workspace/raw/`, never to `workspace/output/` or `workspace/public/`.
2. **Every capture ships both halves** -- a `.png` without its `.ax.md` sidecar is half an observation (except in a degraded mode, where the gap is recorded).
3. **Never activate MUTATING elements** -- unknown means MUTATING. Presence plus label plus strings catalog supplies the inferred behavior.
4. **Restore everything you disturb** -- geometry, appearance, search fields, open menus. Cleanup captures are evidence of restoration.
5. **Consent is verified, never created** -- and `appearance-toggle` is consented per-action, never assumed.
6. **Permission gates are data** -- a FAIL row with an exact System Settings path is a deliverable.
7. **Cite as you go** -- every behavioral claim gets its `<!-- cite: -->` comment immediately, `ref` pointing at a screenshot or sidecar path.
