# HackFM Modal Dialog Guidelines

## Navigation

| Key            | Behavior                                              |
|----------------|-------------------------------------------------------|
| TAB            | Move focus to next element                            |
| SHIFT-TAB      | Move focus to previous element                        |
| UP / DOWN      | Same as TAB / SHIFT-TAB (natural for vertical layout) |
| LEFT / RIGHT   | Move between buttons only (natural for horizontal row)|
| SPACE          | Toggle checkbox; activate focused button              |
| ENTER          | Activate focused element; if focus is on a field or  |
|                | checkbox, trigger the default button                  |
| ESC            | Always cancels — equivalent to activating Cancel      |

## Visual Appearance

### Colors
- Focused element:   `bg_cyan; black`  (no bold)
- Unfocused element: `bg_white; black` (no bold)
- Dialog background: `bg_white; black`
- Shadow:            `bg_black`
- Border:            `bg_white; black` via `tui.box.draw`

### Bold
Do not use `tui.color.bold` anywhere in dialogs. In many terminals (e.g. Konsole),
bold maps to bright colors — bright black becomes grey, which is unreadable on cyan.
Use background color alone to indicate focus.

### Buttons
- Default button:     `[< Label >]`  — the action triggered by ENTER from any field
- Non-default button: `[ Label ]`
- Every dialog must have exactly one default button
- Cancel / No is never the default button
- The default is the safest most-expected action: OK, Yes, Search, etc.

### Title
- Drawn by overlaying text on the top border line at col+2
- Format: `tui.box.draw` first, then `tui.cursor.move $dr $((dc+2))` + `printf " Title "`
- Do NOT use `tui.box.titled` — it produces `┤ Title ├` connectors, inconsistent with other dialogs
- No bold
- Focused:   full-width cyan background, cursor shown
- Unfocused: full-width white background, cursor hidden

### Checkboxes
- Checked:   `[x] Label`
- Unchecked: `[ ] Label`
- Focused:   cyan background on the whole `[x] Label` line
- SPACE or ENTER toggles when focused

## Layout

- Dialog centered on screen
- Shadow offset: 1 row down, 2 cols right, bg_black
- Border drawn with `tui.box.draw` after background fill
- Title centered on top border line: ` Title Text ` (spaces padding)
- Minimum 1 blank row between title border and first element
- Minimum 1 blank row between last element and button row
- Exactly 1 blank row between button row and bottom border (buttons at dh-2)
- Buttons on the second-to-last row (row dh-2 from dialog top)
- Buttons separated by 3 spaces

## Element Focus Order

TAB cycles through elements top-to-bottom, left-to-right:
1. Input fields (in order of appearance)
2. Checkboxes (in order of appearance)
3. Buttons (left to right)

Focus wraps around: last element → first element (TAB), first → last (SHIFT-TAB).

## Implementation Checklist

When implementing a new dialog:
- [ ] All tui classes sourced in the entry point (cursor, screen, color, input, region, box)
- [ ] `tui.region.reset` and `tui.screen.wrap_on` called before drawing
- [ ] `tui.screen.wrap_off` and `tui.region.set` restored after dialog returns
- [ ] No `tui.color.bold` anywhere
- [ ] Default button uses `[< Label >]` format
- [ ] ESC always returns cancel result
- [ ] LEFT/RIGHT navigate between buttons
- [ ] UP/DOWN navigate between all elements
- [ ] TAB/SHIFT-TAB navigate between all elements
