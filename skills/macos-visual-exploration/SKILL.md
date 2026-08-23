---
name: macos-visual-exploration
description: Layer 1 skill for read+write visual exploration of a native macOS application inside a disposable environment. Preflight doctor, first-launch capture, window reconnaissance, menu inventory, AX-tree dumps, destructive-flow capture, screenshot methodology. Loaded by the analyzer agent for the ui-observer role.
---

# macOS Visual Exploration Methodology

Document behavioral intelligence through screen capture and Accessibility-tree inspection of a native macOS application. Every screenshot is an empirical observation. Every AX-tree dump is the machine-readable twin of that observation -- each capture ships both. This mode captures what the app SHOWS and what the system PRESENTS, and -- because it runs inside a disposable environment -- it drives the UI read+write to capture what the app DOES.

This skill is the native-macOS sibling of the `visual-exploration` skill. Where that skill drives a browser with Playwright, this skill drives `screencapture` and System Events AX queries inside the environment. The framing, output shapes, and provenance rules mirror `visual-exploration` deliberately; the interaction policy is read+write because the target runs inside a disposable environment -- a fresh VM or a throwaway account -- with no real data to protect.

## When to Use This Mode

macOS visual exploration activates when the target is a native macOS application (an `.app` bundle), `macos-bundle-analysis` has run, and a disposable runtime environment has been chosen and recorded in `workspace/environment/runtime-environment.md` (verified in Phase 0). All output is **RAW** (screenshots and AX dumps capture the target's proprietary UI in detail); it never reaches `workspace/output/` or `workspace/public/`.

## The Runtime Environment

This skill never runs against the user's own account or the user's own data. It runs inside a disposable runtime environment chosen at dispatch time and recorded in `workspace/environment/runtime-environment.md`: a throwaway macOS VM, or a throwaway user account on this Mac. The environment is pristine -- a fresh install of the target, a fresh account, no real data in it -- so analysis is READ+WRITE. You may create, edit, and delete through the app's own surfaces, run destructive flows, and manufacture states that do not occur naturally. Nothing you break belongs to anyone.

**Environment verification.** Read `workspace/environment/runtime-environment.md`. It must exist, and its `**Environment:**` line must read `vm-tart`, `vm-lume`, or `host-direct`. A value of `none`, a missing line, or a missing file is a hard environmental gate: record it in `preflight-visual.md` and exit without touching the target. You VERIFY this artifact; you NEVER create or edit it. When `**Environment:**` is `host-direct`, `workspace/raw/macos/bundle/signing.md` must additionally record a PASS verdict -- record the gate and exit otherwise. For `vm-tart` and `vm-lume`, copy the artifact's `**Signature verdict:**` into your preflight table as data; it does not gate the run, because a bad signature inside a disposable VM costs a VM.

**host-direct caveat.** A VM is pristine by construction. A `host-direct` account is pristine only because it was freshly created -- the `**Disposable-account affirmation:**` line in the artifact is the user's statement that the account is empty and expendable. Artifacts produced under `host-direct` reflect whatever is actually in that account. Say so in the preflight file.

## Running Commands in the Environment

Every command in this skill runs inside the environment, through the helpers defined by the `macos-vm-execution` skill. Never write a bare `ssh`, and never call `osascript`, `screencapture`, or a System Events query directly. Every screenshot and every AX query in this skill goes through `gf_gui`; a `screencapture` that skips it produces a valid PNG of nothing.

| Helper | Use for |
|--------|---------|
| `gf_exec '<cmd>'` | Non-GUI work: `ls`, `plutil`, file plumbing |
| `gf_gui '<cmd>'` | Anything that touches the window server: AppleScript/System Events, AX queries, `screencapture` |
| `gf_get <guest-path> <host-path>` | Pull evidence back to `workspace/` |
| `gf_put <host-path> <guest-path>` | Push a script or fixture in |

`gf_gui` exists because of one failure mode: over SSH, a GUI command runs outside the guest's Aqua session and returns an empty AX tree, an empty window list, or a wallpaper-only screenshot -- with exit status 0. It looks exactly like a finding and is not one. `gf_gui` wraps the command in `launchctl asuser` against the auto-login session so it lands in the real GUI session. On `host-direct` both helpers are pass-throughs.

`GF_ENV`, `GF_VM`, `GF_SSH`, and `GF_GUEST_WORKSPACE` arrive in your dispatch prompt. Write output under `$GF_GUEST_WORKSPACE/...` and `gf_get` it to the matching path under `workspace/raw/macos/...` before you finish. The Layer 1 gate counts files on the host: evidence still sitting in the guest does not exist.

## Why macOS Visual Exploration Matters

Bundle analysis tells you what the app CAN do (capabilities, strings, entitlements). AppleScript exploration tells you what the app exposes to automation. Visual exploration tells you what the app LOOKS LIKE and how its interface is organized: affordances, the complete command surface with keyboard shortcuts, navigation structure (sidebars, tabs, window hierarchy), state representation as the user navigates, and feedback (selection, focus, enabled/disabled state). No other mode captures this.

## Read+Write Conduct

Mutation is allowed. Exactly one prohibition survives, and it is about fidelity, not privacy:

**All state changes go through the app's own surfaces -- UI actions, scripting commands, URL schemes, Shortcuts. Never change state by writing the app's data store, preference plists, or container files directly.** The app's reaction to its own write is the thing you are here to observe; a direct write destroys the observation.

Keep the READ/MUTATING classification from `macos-bundle-analysis`, with its meaning changed. It no longer decides whether you may click; it decides WHEN you click and what you capture around the click. Unknown still classifies as MUTATING -- schedule it late and bracket it, do not skip it.

### NAVIGATION vs. MUTATING

Every UI element gets the same classification `macos-bundle-analysis` applies to scripting commands: make/delete/move/duplicate/save/set verbs, or app-specific imperatives, are MUTATING; anything unknown is MUTATING. Consume its `capability-inventory.md` and strings catalog (`text-catalog.md`) for cross-checks throughout.

- **NAVIGATION** -- view switches, window operations (open/close/minimize/restore of windows, not documents), disclosure triangles, scrolling, tab selection, search fields (typed then cleared and verified). Clicked freely. Search-field caveat: typed probes may persist in recent-searches stores outside the agent's view -- use innocuous probe strings and note the possible persistence as an observation.
- **MUTATING** -- anything that creates, changes, or deletes data or settings. Exercised deliberately in Phases 4 and 6, one action at a time, with before+after captures plus an AX sidecar. The dialog a MUTATING action raises is often the most valuable screenshot in the run -- capture it before dismissing.
- **UNKNOWN = MUTATING** -- schedule it late and bracket it; do not skip it.

System Events process/window/appearance attributes -- process visibility, window position/size, and the appearance toggle -- are sanctioned navigation-class operations WITH the mandatory restore obligations stated at each use site, not instances of the app-object `set` ban.

An unexercised element's effect is `inferred` from its label; an element exercised with a before/after pair is `confirmed`. Prefer the second -- the environment is disposable, so there is rarely a reason to leave a MUTATING element merely inferred.

## Phase 0: Preflight Doctor

**Goal:** Verify every permission and precondition, pick a degradation mode BEFORE any exploration, and write `workspace/raw/macos/runtime/preflight-visual.md` with a PASS/FAIL table and exact remediation paths. Run all checks even after a failure -- the complete picture picks the mode.

### 0.1 Environment and Signature

Perform the environment verification from **The Runtime Environment** above. Read `workspace/environment/runtime-environment.md`: it must exist and its `**Environment:**` line must read `vm-tart`, `vm-lume`, or `host-direct`. A `none`, a missing line, or a missing file is a hard environmental gate -- record it in `preflight-visual.md` and exit without touching the target. When `**Environment:**` is `host-direct`, `workspace/raw/macos/bundle/signing.md` must additionally record a PASS -- record the gate and exit otherwise. For `vm-tart` and `vm-lume`, copy the artifact's `**Signature verdict:**` into the preflight table as data; it does not gate the run. You VERIFY this artifact; you NEVER create or edit it.

### 0.2 Accessibility Permission

```bash
gf_gui "osascript -e 'tell application \"System Events\" to return UI elements enabled'"
```

Must print `true`. FAIL remediation depends on the environment. Under `vm-tart`/`vm-lume` a missing Accessibility grant is a provisioned-base defect -- the base image's TCC provisioning (see `macos-vm-execution` §9) did not take. Record it and request a re-provisioned base rather than editing TCC mid-run. Under `host-direct` (record verbatim): "System Settings > Privacy & Security > Accessibility > enable the terminal app in this account. TCC cannot be granted from the CLI."

### 0.3 Automation Permission (System Events)

Run a trivial query:

```bash
gf_gui "osascript -e 'tell application \"System Events\" to return name of first process'"
```

Error -1743 ("Not authorized to send Apple events") means the Automation permission is missing or denied. Under a VM this is a provisioned-base defect (the `kTCCServiceAppleEvents` grant did not take) -- record it and request a re-provisioned base. Under `host-direct`: "System Settings > Privacy & Security > Automation > terminal app > enable System Events." If the first-use consent dialog cannot be answered non-interactively, record -1743 as a FAIL.

### 0.4 Screen Recording -- Silent-Failure Detection

Screen Recording permission attaches to the terminal/login binary that issues the call, and its failure mode is silent: `screencapture` exits 0 and writes a wallpaper-only image. Detect it empirically:

```bash
gf_gui "osascript -e 'tell application id \"$BUNDLE_ID\" to activate'"; sleep 1
gf_gui "screencapture -x $GF_GUEST_WORKSPACE/runtime/screenshots/000-preflight-frontmost.png"
gf_gui "osascript -e 'tell application \"System Events\" to set visible of process \"$PROC\" to false'"; sleep 1
gf_gui "screencapture -x $GF_GUEST_WORKSPACE/runtime/screenshots/000-preflight-hidden.png"
gf_gui "osascript -e 'tell application \"System Events\" to set visible of process \"$PROC\" to true'"
# Near-identical file sizes (within ~1%) => nothing app-specific captured => FAIL (wallpaper-only).
# Remediation: VM => the provisioned base lacks the kTCCServiceScreenCapture grant; request a
#   re-provisioned base. host-direct => System Settings > Privacy & Security > Screen & System
#   Audio Recording > enable the terminal app, then RESTART it.
# Size heuristic can false-negative: fallback is gf_get'ing the capture and showing the user.
```

If hiding the app barely changes the image size, the app was never in the image. Another window behind the target can defeat the heuristic -- when unsure, `gf_get` `000-preflight-frontmost.png` to the host and ask the user.

### 0.5 GUI-Session Attachment

The dominant failure mode of this entire skill is a GUI command that runs in the detached SSH session instead of the Aqua session: it returns an empty AX tree, an empty window list, or a wallpaper-only screenshot, and it exits 0. Prove the session is attached before trusting any capture. Run the same query both ways and compare:

```bash
gf_exec "osascript -e 'tell application \"System Events\" to count processes'"   # detached session
gf_gui  "osascript -e 'tell application \"System Events\" to count processes'"   # Aqua session
```

The `gf_gui` count must be substantially higher (a real desktop has dozens of processes; a detached session sees almost none). If BOTH come back empty or error, there is no window server to attach to -- a provisioning defect (auto-login did not occur, or no console session exists). This is a HARD STOP: record it in `preflight-visual.md` and exit. Do NOT fall back to `gf_exec` for the GUI phases -- an empty AX tree from a detached session is not a finding.

### 0.6 App Present and Usable Without Sign-In

Confirm the target is installed in the environment and reaches a usable state without credentials:

```bash
gf_exec "ls -d /Applications/<App>.app"        # present?
gf_gui  "osascript -e 'tell application id \"$BUNDLE_ID\" to activate'"; sleep 2
gf_gui  "screencapture -x $GF_GUEST_WORKSPACE/runtime/screenshots/000-preflight-firstscreen.png"
```

If the app is absent, that is a provisioning gate (the target was never installed -- see `macos-vm-execution` target provisioning), not this skill's job to fix: record and exit. If the first screen is a hard sign-in or paywall wall with no usable surface behind it and no credentials are available, record `app-unusable-without-sign-in` and exit -- there is nothing to explore. A trial or onboarding screen that can be dismissed forward is NOT a wall; capture it in Phase 1.0.

### 0.7 Degradation Decision

Record the chosen mode in `preflight-visual.md` before any exploration:

| Mode | Condition | Consequence |
|------|-----------|-------------|
| **both** | Accessibility AND Screen Recording pass | Full methodology: PNGs + `.ax.md` sidecars |
| **AX-only** | Screen Recording fails | No PNGs; all evidence in `.ax.md` dumps and inventories, "screenshot" slots reference sidecars |
| **screenshots-only** | Accessibility fails | No AX means no menu traversal -- `command-surface.md` records the gap. Full-screen captures only |
| **abort** | Both fail, or an environment gate | `preflight-visual.md` is the deliverable; the gates are environmental data |

### 0.8 Preflight Output Format

```markdown
# Preflight: Visual Exploration -- <App Name>

| Check | Result | Detail | Remediation |
|-------|--------|--------|-------------|
| Runtime environment | PASS | vm-tart (greenfield-acmetasks-target) | -- |
| Signature (signing.md) | PASS | Developer ID, notarized | -- |
| Accessibility | PASS | UI elements enabled = true | -- |
| Automation > System Events | PASS | trivial query returned | -- |
| Screen Recording | FAIL | captures within 0.4% size | provisioned base missing ScreenCapture grant; re-provision |
| GUI-session attachment | PASS | gf_gui count 274 vs gf_exec count 3 | -- |
| App present + usable | PASS | launches to onboarding, dismissible | -- |

**Degradation mode:** AX-only
```

## Phase 1: Window Reconnaissance

**Goal:** Activate the app, enumerate every window via System Events, and capture each one. This seeds `window-inventory.md`.

### 1.0 First-Launch Capture

The app has NEVER launched in this environment -- it is pristine. First launch is a one-time, unrecoverable event: onboarding screens, first-run tips, permission primers, and the empty initial state appear once and never again in this clone. Capture them BEFORE anything else.

- Take the onboarding one screen at a time: `first-01-`, `first-02-`, ... one screenshot each, each with its `.ax.md` sidecar.
- Advance only AFTER both halves (PNG + sidecar) are on disk. Dismiss/continue forward only -- never backward, and never skip a screen uncaptured.
- This sequence is unrecoverable except by rolling the environment back to its pristine snapshot. If a capture fails partway, do NOT keep clicking: request a rollback to the pristine snapshot (the `macos-vm-execution` `gf_rollback` path) and restart the sequence. Coordinate dispatch order with the runtime skill so the pristine snapshot exists before first launch.

```bash
gf_gui "osascript -e 'tell application id \"$BUNDLE_ID\" to activate'"; sleep 2
gf_gui "screencapture -x $GF_GUEST_WORKSPACE/runtime/screenshots/first-01-onboarding.png"
# dump the AX sidecar, gf_get both halves, then advance one screen and repeat as first-02-, ...
```

### 1.1 Activation and Enumeration

Run the enumeration through `gf_gui`; a bare `osascript` over SSH returns an empty window list:

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
read -r X Y W H <<< "$(gf_gui "osascript -e 'tell application \"System Events\" to tell process \"$PROC\"
  set p to position of window 1
  set s to size of window 1
  return (item 1 of p as text) & \" \" & (item 2 of p as text) & \" \" & (item 1 of s as text) & \" \" & (item 2 of s as text)
end tell'")"
gf_gui "screencapture -x -o -R\"$X,$Y,$W,$H\" $GF_GUEST_WORKSPACE/runtime/screenshots/001-main-window.png"
```

Fallback when the bounds query fails: full-screen `gf_gui "screencapture -x -o"` with the app frontmost, noted in the manifest. Peekaboo-class tools that expose window IDs would have to be baked into the provisioned base image -- that is the `macos-vm-execution` provisioning job, done once when the base is built, never a mid-run install. Under `host-direct`, install nothing into the account.

### 1.3 Initial Assessment

Document, as the browser sibling does for a landing page: application shape (single-window, multi-window, library/document model), primary navigation (sidebar, source list, tab bar, toolbar), visible affordances (noting MUTATING affordances for deliberate exercise in Phases 4/6), and window chrome (title, toolbar style, resizability).

## Phase 2: Menu-Bar Traversal

**Goal:** Walk the entire menu bar and produce `workspace/raw/macos/runtime/command-surface.md`. This IS the app's Complete Feature Inventory and All Keyboard Shortcuts from the analysis-pipeline's "What the Implementer Needs" -- the menu bar is the one place a macOS app is required to enumerate its own commands.

### 2.1 Recursive AppleScript Walk

Walk every menu with one submenu level:

```applescript
-- substitute the target's process name (bundle inventory, Contents/MacOS/<name>)
tell application "System Events" to tell process "AcmeTasks"
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
| CMD-041 | File > New To-Do | ⌘N | yes | MUTATING -- exercised in Phase 6 |
| CMD-042 | File > New Project | ⌥⌘N | yes | MUTATING -- not exercised (destructive, no undo) |
| CMD-043 | View > Show Sidebar | ⌃⌘S | yes | NAVIGATION |
```

Cross-check each menu label against the bundle strings catalog (`workspace/raw/macos/bundle/text-catalog.md`). A label found in both the live menu and the strings catalog is two independent sources -- the command's existence is `confidence=confirmed`. What a MUTATING command DOES is `inferred` from its label until Phase 6 exercises it, at which point it becomes `confirmed`.

### 2.4 Menu Screenshots

Opening a menu to screenshot it (`menu-NNN-<menu>.png`) is NAVIGATION and permitted. Press Escape immediately after each capture -- an open menu left behind blocks subsequent AX queries. Cleanup is part of the observation.

## Phase 3: AX-Tree Dumps and Window Inventory

**Goal:** For EVERY screenshot, write a sidecar `<name>.ax.md` next to the `.png`, and complete `window-inventory.md`.

### 3.1 Why Sidecars

The sidecar keeps the evidence in `.md` form for downstream gates and synthesis agents that read text, and makes every pixel claim greppable. The AX dump and the screenshot of the same state are the SAME evidence group -- cross-note them, but never count the pair as two independent sources.

### 3.2 Sidecar Format

```markdown
# AX Snapshot: 001-main-window.png
**Window:** Acme Tasks — Today   **Captured:** <timestamp>
- AXWindow "Acme Tasks — Today" (0,25 1200x800)
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
## Window: Acme Tasks — Today

**Screenshot:** win-001-today.png (sidecar: win-001-today.ax.md)

### Interactive Elements

| Role | Title | Enabled | Action Taken | Screenshots |
|------|-------|---------|--------------|-------------|
| AXRow | Inbox | yes | navigation -- clicked | win-001-today.png, step-02-inbox.png |
| AXButton | New To-Do | yes | none (MUTATING) | win-001-today.png |
| AXTextField | Search | yes | navigation -- typed, cleared | step-05-search.png, step-06-search-cleared.png |
```

`Action Taken` takes one of `none`, `navigation`, or `mutating -- see flows/<flow>`.

## Phase 4: Flow Documentation

**Goal:** Document end-to-end flows -- navigation AND mutation -- with a capture pair at every state transition. Each flow gets a directory `workspace/raw/macos/runtime/flows/<flow>/` containing `step-NN-*.png`, `step-NN-*.ax.md`, and `flow.md` -- mirroring `visual-exploration` exactly.

### 4.1 Core Flows to Document

| Flow | Description | Priority |
|------|-------------|----------|
| **View navigation** | Visit every sidebar/source-list destination, capture each | High |
| **Window lifecycle** | New window, close, reopen, restore -- window ops only, never documents | High |
| **Menu-driven view changes** | Invoke each NAVIGATION-classed CMD and capture the result | High |
| **Search/filter** | Type a query, observe results, press Escape, verify the field cleared | Medium |
| **Create** | Create a new item through the app's own surface; capture before, the creation sheet/dialog, and after | High |
| **Edit** | Modify an existing item; before/after pair around the change | High |
| **Complete / state-change** | Toggle a state (complete, flag, archive); before/after pair | High |
| **Delete-and-trash** | Delete an item, capture the confirmation dialog and the trashed result; before/after pair | High |
| **Settings-change** | Open Settings, change a setting, capture the effect, restore the original within the run | Medium |
| **Undo** | Perform a mutation, then Undo it; capture that the app reverts; before/after pair | Medium |

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
**Feedback:** Window title changed to "Acme Tasks — Inbox"

## Behavioral Claims

- Selecting a sidebar destination updates the window title to match the destination name
  <!-- cite: source=visual-observation, ref=flows/view-navigation/step-02-inbox.ax.md, confidence=confirmed, agent=ui-observer -->
```

### 4.3 Interaction Policy for Flows

- One action per step -- the behavioral claim is the difference between the before and after capture.
- Every interaction gets a before AND an after capture, each with its AX sidecar.
- Disabled elements are documented as disabled, never forced.
- Modal sheets and dialogs are captured BEFORE dismissal; record both button labels. To observe both outcomes, run the flow twice and press a different button each time.
- Destructive steps the app cannot undo are deferred to Phase 6, where they are bracketed by a snapshot.

## Phase 5: Edge Cases

**Goal:** Probe boundaries that reveal behavior: window geometry limits, appearance, and manufactured empty states.

### 5.1 Window Resize

Record the original geometry first. Probe the minimum size and a large size, capture each, then RESTORE the original geometry and capture the restoration. Discovering the enforced minimum window size is a behavioral claim:

```markdown
- The main window enforces a minimum size of 640x480; resize attempts below this snap back
  <!-- cite: source=visual-observation, ref=screenshots/edge-resize-min.png, confidence=confirmed, agent=ui-observer -->
```

### 5.2 Dark Mode

Toggle the system appearance, capture the main views in both appearances, then toggle back for comparability:

```bash
gf_gui 'osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"'
# capture the main views in the toggled appearance, then toggle back unconditionally
gf_gui 'osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"'
```

Restoration here is about comparability, not consent -- the toggled-back state matches every other capture in the run.

### 5.3 Empty States

Manufacture empty states rather than waiting for them. Delete the entire corpus in one destination through the app's own surfaces, capture the empty-state illustration, headline, and call-to-action, then either re-seed the destination or note it left-empty in the manifest. The empty state is a designed screen most users never see twice -- it is high-value evidence.

### 5.4 Out of Scope

Display and resolution variations (multiple monitors, scaled resolutions) are explicitly out of scope.

## Phase 6: Destructive Flows and Their Dialogs

**Goal:** Exercise the MUTATING surface that Phases 4 and 5 deferred -- the irreversible and destructive flows -- and capture the dialogs they raise. In a disposable environment these are safe; the dialogs are often the single most valuable screenshots in the whole run.

Snapshot the environment before any irreversible flow (`gf_snapshot` per `macos-vm-execution`), `gf_get` all evidence to the host BEFORE any rollback, and note in `visual-behaviors.md` which captures were taken post-rollback. Under `host-direct` there is no snapshot/rollback -- probes that would depend on rollback safety are simply not run there.

Document, each with a before/after pair and the dialog captured before dismissal:

- **Delete-confirmation alerts** -- capture the exact wording and cross-check it against `text-catalog.md`; the live alert and the compiled string are two independent sources.
- **Empty-trash** and any secondary confirmation.
- **Bulk-delete** -- select many, delete, capture the (often different) bulk confirmation.
- **Induced error alerts** -- drive the app into an error state through its own surfaces and capture the alert.
- **Manufactured empty states** produced by deletion (cross-reference Phase 5.3).

Every destructive flow raises a behavioral claim cited to the before/after captures and the dialog sidecar. Captures outside a specific flow directory use the `mut-NN-` prefix.

## Screenshot Naming Convention

| Prefix | Usage |
|--------|-------|
| `000-` | Phase 0: preflight captures |
| `first-NN-` | Phase 1.0: first-launch / onboarding captures |
| `001-` through `099-` | Phase 1: window reconnaissance |
| `win-NNN-` | Phase 3: window inventory captures |
| `menu-NNN-` | Phase 2: open-menu captures |
| `step-NN-` | Phase 4: flows (within the flow subdirectory) |
| `edge-` | Phase 5: edge case exploration |
| `mut-NN-` | Phase 6: destructive-flow captures outside a flow directory |

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

Every path above is written in-guest under `$GF_GUEST_WORKSPACE/runtime/...` and pulled to the host with `gf_get` before the run finishes. The Layer 1 gate counts files on the HOST under `workspace/raw/macos/runtime/` -- evidence still in the guest does not exist. `screenshot-manifest.md` lists every capture with its sidecar and what it evidences, and it must reflect what landed on the HOST, not what was captured in the guest. This satisfies output gates and lets specs cite records, not bare images. Do not write to `observations/` or `scripting/` -- those belong to the applescript-explorer role. Your observation records live inside your own output files.

## Provenance Rules

### Source Type

All claims from this skill use `source=visual-observation` with `agent=ui-observer`. The `ref` field is the screenshot path or the `.ax.md` sidecar path:

```markdown
- The sidebar lists five standard destinations: Inbox, Today, Upcoming, Completed, Trash
  <!-- cite: source=visual-observation, ref=screenshots/win-001-today.ax.md, confidence=confirmed, agent=ui-observer -->
```

### Confidence Levels

Identical to `visual-exploration`:

- **confirmed** -- the behavior is directly visible in a capture or demonstrated by a before/after pair
- **inferred** -- the element exists but was not exercised. This is the default only for an UNEXERCISED element, which is now a shrinking set: in a disposable environment most MUTATING elements get exercised and escalate to `confirmed`. An element left unexercised needs a recorded reason (e.g. no undo and out of snapshot budget).
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
| Environment unreachable / `**Environment:**` = none or missing artifact | Hard environmental gate: record in `preflight-visual.md` and exit |
| GUI session not attached (gf_gui and gf_exec both empty) | HARD STOP -- provisioning defect; do NOT fall back to `gf_exec`, an empty AX tree is not a finding |
| App unusable without sign-in (hard paywall/login wall) | Record `app-unusable-without-sign-in` and exit; nothing to explore |
| Screen Recording permission missing | AX-only mode: no PNGs, all evidence in `.ax.md` and inventories |
| Accessibility permission missing | Screenshots-only mode: no AX means no menu traversal; record the gap |
| Both missing | Abort; `preflight-visual.md` with remediation paths is the deliverable |
| Window-bounds query fails | Full-screen capture fallback, noted in the manifest |
| `entire contents` timeout | Chunked walk by top-level UI element |
| Stuck modal blocks further AX queries | Dismiss forward if possible; if wedged, `gf_get` what exists then roll back to the pristine snapshot |
| Rollback discarded captures never pulled to host | Data loss -- always `gf_get` before `gf_rollback`; note any post-rollback captures in `visual-behaviors.md` |
| App owned by another login session (error -1728 on process access) | Under host-direct, abort; the session boundary is environmental data |

Every failure mode produces data. A permission gate documented with its exact remediation path is a deliverable, not a dead end.

## Definition of Done

- [ ] `preflight-visual.md` records every check with PASS/FAIL, remediation paths for failures, and the chosen degradation mode
- [ ] First-launch / onboarding captured, or its absence recorded (the app launched straight into a usable state)
- [ ] Every window captured with its `.ax.md` sidecar (or gap-noted per the degradation mode)
- [ ] `command-surface.md` covers every menu item including submenus, with shortcut, enabled state, and mutation class; CMD-NNN IDs are sequential
- [ ] `window-inventory.md` complete, with `Action Taken` one of `none`, `navigation`, or `mutating`
- [ ] At least one create, one edit, one state-change, and one delete flow documented with before/after pairs and their dialogs
- [ ] Every MUTATING command either exercised (escalated to `confirmed`) or recorded as not-exercised with a reason
- [ ] At least one manufactured empty state captured
- [ ] Appearance and window geometry restored WITHIN the run for comparability (app data needs no restoration -- the environment is disposable); the restoration itself captured
- [ ] `visual-behaviors.md` synthesizes behavioral claims, every claim cited
- [ ] Every capture and its sidecar `gf_get`'d to the host; `screenshot-manifest.md` reflects what is on the HOST, not the guest

## Rules

1. **Screenshots and AX dumps are RAW** -- they go to `workspace/raw/`, never to `workspace/output/` or `workspace/public/`.
2. **Every capture ships both halves** -- a `.png` without its `.ax.md` sidecar is half an observation (except in a degraded mode, where the gap is recorded).
3. **Exercise MUTATING elements deliberately** -- late, one at a time, each bracketed by before/after captures and the dialog it raises. Unknown still means MUTATING; an unexercised MUTATING element needs a recorded reason.
4. **Restore within a run, not after it** -- geometry, appearance, open menus, and search fields are restored for comparability; app data is NOT restored, because the environment is disposable.
5. **The environment artifact is verified, never created** -- and every GUI-touching command goes through `gf_gui`, never a bare `osascript`/`screencapture` over SSH.
6. **Permission gates are data** -- a FAIL row with an exact remediation path is a deliverable.
7. **Cite as you go** -- every behavioral claim gets its `<!-- cite: -->` comment immediately, `ref` pointing at a screenshot or sidecar path.
8. **A capture that never left the guest is not evidence** -- `gf_get` every screenshot and sidecar to the host before finishing; the Layer 1 gate counts host files.
