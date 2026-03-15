# hackfm
Hackable File Manager

A TUI file manager written in pure bash. Extend it if you know bash.

Uses [ba.sh](https://github.com/mnorin/ba.sh) for code organisation and a ba.sh-based TUI library for text graphics. Doesn't use ncurses — the idea is to use bash as much as possible and minimise external tool dependencies.

This is an experimental tool. Be careful when using it, especially with file operations.

---

## Dependencies

### Required
These must be present for hackfm to run at all:
- **bash** — shell runtime
- **awk** — text processing (panel info bar, size formatting)
- **find** — directory listing and file search
- **stat** — file metadata (size, permissions, timestamps)
- **grep** — content search (find module) and archive detection
- **dd** — file copying with progress (fscopy, fsmove)
- **mkdir** — directory creation
- **chmod**, **chown**, **touch** — permission and timestamp preservation after copy
- **mkfifo** — named pipe for the titled module message bus
- **timeout** — prevents FIFO writes from blocking (titled module)
- **sort** — directory listing sort (filelist)
- **cut** — field splitting in several places
- **cat** — file content in viewer and editor
- **head** — windowed file loading in viewer

### Optional — Archive Browsing and Extraction
Required only when working with those archive formats:
- **tar** — tar, tar.gz, tar.bz2, tar.xz archives
- **unzip** — zip archive browsing and extraction
- **zip** — zip archive creation (fsarchive module)
- **unrar** — rar archive browsing and extraction
- **7z** / **7za** / **7zr** — 7z archive browsing, creation and extraction (any one of the three suffices)
- **isoinfo** (from the `genisoimage` package) — ISO 9660 image browsing with Rock Ridge extension support

### Optional — External Viewers and Editors
Configured in `conf/view.conf` and `conf/edit.conf`. Common examples:
- **pdftotext** (poppler-utils) — PDF text extraction for the viewer
- **ffprobe** (ffmpeg) — media file metadata
- **identify** (ImageMagick) — image metadata
- **python3** — JSON pretty-printing and other scripted handlers
- **vim** / **nano** / **vi** / any editor — configurable default editor and per-extension editors

---

## Features

### File Management
- Two-panel layout
- Navigate the filesystem in both panels independently
- Copy, move, delete files and directories (with progress dialogs for large operations)
- Create directories (F7)
- Multiple file selection with Insert key — selection is preserved across operations
- Tab to switch between panels

### Sorting
- Sort by name, date, size, or extension (via Left/Right menus or Ctrl+S)
- Ascending and descending order, toggled by pressing the same sort key again
- Directories always shown before files
- When sorting by name: dot directories on top, dot files on top, capitals before lowercase (MC style)
- When sorting by size or date: all entries sorted together within dirs/files groups

### Archives
Browse archives as if they were directories. Supported formats:
- tar, tar.gz, tar.bz2, tar.xz
- zip
- rar (requires unrar)
- 7z (requires 7z/7za/7zr)
- ISO 9660 images (requires isoinfo), with Rock Ridge and Joliet extension support

Press Enter to navigate into and out of archives. Copy from inside an archive to extract files selectively.

### File Viewer (F3)
- Built-in text viewer with scrolling (PgUp/PgDn, Home/End)
- Windowed loading for large files
- View files inside archives without extracting manually
- Configurable external handlers per extension via `conf/view.conf`
  - Falls back to built-in viewer if handler not found or produces no output
  - Binary files show type and size information

### File Editor (F4)
- Built-in text editor
- Configurable external editor per extension via `conf/edit.conf`
- Global default external editor via `default_editor` in `conf/hackfm.conf`
- Priority: edit.conf handler → default_editor → internal editor
- Shows error dialog if configured editor is not found

### Archiving and Extraction (F12 / F13)
- **F12** — Archive selected files or the file under the cursor into a new archive
  - Format is detected from the filename you type: `.tar.gz`, `.tar.bz2`, `.tar.xz`, `.tar`, `.zip`, `.7z`
  - Multiple selected files and directories are archived together
  - Selection is cleared after archiving
- **F13** — Extract a whole archive to a destination of your choice
  - Destination defaults to the other panel's path
  - Offers to create the destination directory if it doesn't exist
  - Selective extraction: navigate into an archive and use Copy (F5) to extract individual files

### Find File (F17 — Layer 1, physical F7)
- Full-screen find dialog with filename pattern and content search fields
- Filename matching is glob-style (`*`, `?`) and case-insensitive by default
- Content search uses grep across all matching files
- Options: case-sensitive toggle, skip hidden files toggle
- Results list: Enter jumps to the file in the active panel, F3 opens it in the viewer, `n` starts a new search

### Command Line
- Integrated command line at the bottom of the screen
- Commands run in the current directory of the active panel
- Ctrl+O drops to a full interactive bash session. Press Ctrl+O again inside that session to return to hackfm
- Ctrl+Up / Ctrl+Down scroll through command history
- Ctrl+/ inserts the path of the selected file into the command line
- Ctrl+R reloads the active panel
- Ctrl+U clears the command line

### File Coloring
- Files are colored by type and extension (MC color scheme by default)
- Configurable via `conf/colors.conf` — map extensions to color names
- Compound extensions supported (e.g. `tar.gz` matched before `gz`)
- Extension matching is case-insensitive
- Color categories: directories (bright white), executables (bright green),
  archives (bright magenta), source code (cyan), images (bright cyan),
  media (green), documents (yellow), databases (bright red)

### User Menu (F2)
- Customisable popup menu defined in `conf/usermenu.conf`
- Each entry has a hotkey, label, command, and optional execution mode
- Use `%f` in the command as a placeholder for the selected file path
- Execution modes: run in terminal (default), `background`, or `new-terminal`

### Quick Directory Jump (Ctrl+D)
- Jump to frequently used directories
- Configurable directory list

---

## Multi-Layer F-Key Bar

hackfm's F-key bar supports multiple layers, each providing its own set of 10 keys. This gives effectively unlimited F-key bindings — the physical F1–F10 keys always refer to whichever layer is currently active, with no modal state to track.

**Switching layers:** `Ctrl+Right` advances to the next layer, `Ctrl+Left` goes back. The current layer number is shown as `L0`, `L1`, `L2`, etc. at the left end of the F-key bar. Only layers that have at least one registered key are shown.

**Key numbering:** Keys are numbered sequentially across layers. Layer 0 is F1–F10, Layer 1 is F11–F20, Layer 2 is F21–F30, and so on. Registering a module key as `F17` places it on Layer 1, physical F7. The bar takes care of everything else — label display, layer indicators, and dispatch.

**Layer 0 (default):**

| F-Key | Physical Key | Action |
|---|---|---|
| F2 | F2 | User menu |
| F3 | F3 | View |
| F4 | F4 | Edit |
| F5 | F5 | Copy / Extract from archive |
| F6 | F6 | Move |
| F7 | F7 | Mkdir |
| F8 | F8 | Delete |
| F9 | F9 | Menu |
| F10 | F10 | Quit |

**Layer 1 (Ctrl+Right):**

| F-Key | Physical Key | Action |
|---|---|---|
| F12 | F2 | Archive |
| F13 | F3 | Extract archive |
| F14 | F4 | Open in Vim (vimhook module, requires vim) |
| F17 | F7 | Find File |

Modules can register keys on any layer. Additional layers are created automatically as needed.

---

## Key Bindings

### Navigation

| Key | Action |
|-----|--------|
| Up / Down | Move cursor |
| PgUp / PgDn | Page up / page down |
| Home / End | Jump to first / last file |
| Tab | Switch active panel |
| Enter | Open file / enter directory or archive |
| Backspace | Go to parent directory |

### File Operations

| Key | Action |
|-----|--------|
| Insert | Toggle file selection and move down |
| F2 | User menu |
| F3 | View file |
| F4 | Edit file |
| F5 | Copy file / extract from archive |
| F6 | Move / rename |
| F7 | Mkdir |
| F8 | Delete |
| F9 | Menu bar |
| F10 | Quit |
| F2 (Layer 1 / F12) | Archive selected / current file |
| F3 (Layer 1 / F13) | Extract archive |
| F7 (Layer 1 / F17) | Find file |

### Command Line

| Key | Action |
|-----|--------|
| Enter | Execute command (when command line has text) |
| Backspace | Delete character |
| Delete | Delete character forward |
| Left / Right | Move cursor |
| Home / End | Move cursor to start / end |
| Ctrl+Up | Previous command in history |
| Ctrl+Down | Next command in history |
| Ctrl+U | Clear command line |
| Ctrl+/ | Insert selected file path |

### Other

| Key | Action |
|-----|--------|
| Ctrl+O | Drop to interactive bash session (Ctrl+O to return) |
| Ctrl+R | Reload active panel |
| Ctrl+S | Quick sort menu |
| Ctrl+A | File attributes |
| Ctrl+D | Quick directory jump |
| Ctrl+Left | Previous F-key layer |
| Ctrl+Right | Next F-key layer |

---

## Module System

hackfm's module system lets you add new functionality without touching any core code. Each module is a single bash file that lives in `modules/<name>/<name>.mod` and is enabled by a line in `conf/hackfm.conf`. Modules run in the same bash process as hackfm, so they have full access to all internals: panels, dialogs, the message broker, configuration, everything.

### Module Lifecycle

Each module implements any combination of four hook functions:

```bash
name.pre_init()   # Called before any objects are created
name.init()       # Called after all objects exist
name.run()        # Action handler — called by key dispatch
name.on_exit()    # Called when hackfm exits — use for cleanup
```

**`pre_init`** runs before panels, the title bar, and the F-key bar are instantiated. This is the right place to redefine constructors or override class behaviour. The `colors` module uses `pre_init` to wrap the `panel()` constructor and inject color-aware row rendering without modifying `panel.class` at all.

**`init`** runs after all core objects exist. Use it to register key bindings, F-key labels, menu items, and message subscriptions.

**`run`** (or any function name you choose) is called when the registered key is pressed. Return `0` if handled, `1` to pass to the next handler for the same key. Multiple modules can register handlers for the same key — they are called in registration order until one returns `0`.

**`on_exit`** is called when hackfm exits cleanly. Use it to kill background processes, remove temp files, close file descriptors, or release any other resources your module acquired. The `bus` module uses it to kill the FIFO listener and clean up run files.

### Registering Keys and Labels

```bash
name.init() {
    # Register a key on layer 0 with a static label
    hackfm.module.register_key "F3" "name.run" "View"

    # Register a key on layer 1 (physical F7)
    hackfm.module.register_key "F17" "name.run" "Find"

    # Dynamic label — function sets __HACKFM_FKEY_LABEL directly, never echoes
    hackfm.module.register_key_label "F5" "name.fkey_label"
}

name.fkey_label() {
    __HACKFM_FKEY_LABEL="Copy"
}
```

### Subscribing to Messages

hackfm uses a pub/sub message broker for inter-component communication. Modules can subscribe to any topic and publish their own:

```bash
name.init() {
    hackfm.module.subscribe "panel.active.dir_changed" "name.on_dir_changed"
    hackfm.module.subscribe "dialog_closed"            "name.on_dialog_closed"
    hackfm.module.subscribe "viewer_closed"            "name.on_viewer_closed"
    hackfm.module.subscribe "editor_closed"            "name.on_editor_closed"
}

name.on_dir_changed() {
    local topic="$1"
    local data="$2"   # new directory path
}
```

Publishing:

```bash
broker.publish "dialog_closed" ""
broker.publish "selection.clear" ""
```

Built-in topics:

| Topic | Published when |
|---|---|
| `dialog_closed` | Any dialog or modal closes — triggers panel redraw |
| `viewer_closed` | The file viewer exits |
| `editor_closed` | The file editor exits |
| `panel.active.dir_changed` | The active panel navigates to a new directory |
| `selection.clear` | The active panel should clear its selection |
| `ui.menu_opened` | A menu overlay is about to appear |
| `ui.menu_closed` | A menu overlay has closed |

### Common Helpers

```bash
# Get the active/inactive panel object name
local panel=$(get_active_panel)       # e.g. "left_panel"
local other=$(get_other_panel)

# Get the selected file info
local filename filetype path
IFS='|' read -r filename filetype path <<< "$(get_selected_item)"

# Dialogs
file_dialog.show_input "Title" "Message:" "default_value"
file_dialog.show_confirm "Title" "Are you sure?"
show_error "Something went wrong"
_draw_status_dialog "Title" "Working..."

# Panel operations
reload_active_panel
reload_both_panels

# Always publish dialog_closed when your operation finishes — triggers panel redraw
broker.publish "dialog_closed" ""
```

### Module Example

A minimal module that opens the selected file in `less` on Layer 1, F3 (F13):

```bash
#!/bin/bash
# modules/lessview/lessview.mod

lessview.init() {
    hackfm.module.register_key "F13" "lessview.run" "Less"
}

lessview.run() {
    local filename filetype path
    IFS='|' read -r filename filetype path <<< "$(get_selected_item)"
    [ -z "$filename" ] && return 1
    tui.screen.main
    less "$path/$filename"
    tui.screen.alt
    draw_screen
    broker.publish "dialog_closed" ""
}
```

Enable it by adding `module_lessview_enabled=1` to `conf/hackfm.conf`.

### pre_init Example — Wrapping a Constructor

The `colors` module wraps the `panel()` constructor to inject color rendering. The pattern looks like this:

```bash
#!/bin/bash
# modules/mything/mything.mod

mything.pre_init() {
    # Redefine the panel constructor — called for every panel() instantiation
    panel() {
        # ... set up properties, override methods ...
    }
}
```

Because `pre_init` runs before any objects are created, the redefined constructor is used for all panels. This is how you change core object behaviour without forking core files.

---

## Configuration

All configuration lives in the `conf/` directory.

### conf/hackfm.conf

Main configuration file. Enables/disables modules and sets global options.

```
# Open executables in a new terminal window (1) or inline (0)
open_execute_in_terminal=0

# Default external editor (leave empty to use internal editor)
default_editor=

# Modules — set to 1 to enable, 0 to disable
module_colors_enabled=1
module_viewer_enabled=1
module_editor_enabled=1
module_fscopy_enabled=1
module_fsmove_enabled=1
module_fsdelete_enabled=1
module_fsmkdir_enabled=1
module_fsextract_enabled=1
module_fsattr_enabled=1
module_fsarchive_enabled=1
module_find_enabled=1
module_quickdir_enabled=1
module_usermenu_enabled=1
module_vimhook_enabled=1
module_terminal_enabled=1
```

### conf/colors.conf

Maps file extensions and types to color names. First match wins, so compound
extensions (e.g. `tar.gz`) must appear before simple ones (`gz`).

```
# Special keywords
dir             bright_white
exe             bright_green

# Compound extensions first
tar.gz          bright_magenta

# Then simple extensions
gz              bright_magenta
py              cyan
jpg             bright_cyan
```

Available color names: `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`,
`bright_black`, `bright_red`, `bright_green`, `bright_yellow`, `bright_blue`,
`bright_magenta`, `bright_cyan`, `bright_white`

### conf/view.conf

Maps file extensions to viewer commands. Use `%f` as a placeholder for the filepath.

```
pdf     pdftotext -layout %f -
json    python3 -m json.tool %f
iso     isoinfo -d -i %f
```

Falls back to built-in viewer if the command is not found or produces no output.

### conf/edit.conf

Maps file extensions to editor commands. Use `%f` as a placeholder for the filepath.

```
py      nano
sh      vi
```

Falls back to `default_editor` from `hackfm.conf`, then to the internal editor.

### conf/ext.conf

Maps file extensions to open actions (executed when pressing Enter on a file).

---

## Built-in Modules

### colors
File type coloring for panels, based on the MC color scheme. Uses `pre_init` to wrap
the `panel()` constructor and inject color-aware row rendering — `panel.class` is
untouched. Color mappings are configured in `conf/colors.conf`. Disable with
`module_colors_enabled=0` for plain white-on-blue panels.

### viewer
File viewer (F3). Built-in text viewer with scrolling. Supports viewing files inside
archives without extracting. External handlers configurable in `conf/view.conf`.

### editor
File editor (F4). Built-in text editor. External editors configurable per extension
in `conf/edit.conf`, with a global default in `conf/hackfm.conf`.

### fscopy
Copy files and directories (F5). Shows a destination path dialog and a progress
dialog for large operations. Supports copying multiple selected files at once.

### fsmove
Move and rename files and directories (F6). Shows a destination path dialog.
Supports moving multiple selected files at once.

### fsdelete
Delete files and directories (F8). Shows a confirmation dialog. Supports deleting
multiple selected files at once.

### fsmkdir
Create a new directory (F7). Prompts for the directory name.

### fsextract
Extract files from an archive (F5 when browsing inside an archive). Prompts for
destination directory.

### fsarchive
Archive and extract operations on the filesystem (F12 / F13).

- **F12 Archive** — archives the selected files (or the file under the cursor if nothing is selected) into a new archive. Format is determined by the extension of the name you provide: `.tar.gz`, `.tar.bz2`, `.tar.xz`, `.tar`, `.zip`, `.7z`. Clears panel selection after success.
- **F13 Extract** — extracts the archive under the cursor to a destination directory, defaulting to the other panel's path. Will offer to create the destination if it doesn't exist.

### find
Find files by name and/or content (Layer 1, physical F7 = F17).

Opens a full-screen search form with fields for filename pattern (glob-style), content grep string, and starting directory. Options include case-sensitive matching and skipping hidden files. Results are shown in a scrollable list; Enter navigates the active panel to the found file, F3 opens it in the viewer, and `n` returns to the search form for a new search.

### fsattr
Show file attributes dialog (Ctrl+A). Displays permissions, owner, size, and timestamps
for the selected file.

### quickdir
Quick directory jump (Ctrl+D). Jump to a configured list of favourite directories
without navigating there manually.

### usermenu
User-defined menu (F2). Shows a popup list of custom commands defined in `conf/usermenu.conf`. Each entry has a hotkey, a label, a command, and an optional execution mode. Use `%f` in the command as a placeholder for the currently selected file path.

```
# Format: "hotkey" "Label" "command %f" [execution_mode]
# execution_mode: (absent) = run in terminal, background, new-terminal

"v" "View in less"       "less %f"
"e" "Edit with nano"     "nano %f"
"i" "File info"          "file %f"
"t" "Open terminal here" "bash"         new-terminal
"c" "Copy path to clip"  "echo %f | xclip -selection clipboard" background
```

### terminal
Interactive bash session (Ctrl+O). Drops hackfm to a full bash shell in the same terminal. Press Ctrl+O again inside the shell to return to hackfm. The panel reloads on return to pick up any filesystem changes made during the shell session. Disable with `module_terminal_enabled=0` in `conf/hackfm.conf`.

### vimhook
Open the selected file in Vim (Layer 1, physical F4 = F14). A simple example of
F-key layer registration. Requires `vim` to be installed. Disable by setting
`module_vimhook_enabled=0` in `conf/hackfm.conf`.

---

## Architecture

hackfm is built from small, single-responsibility bash classes using the
[ba.sh](https://github.com/mnorin/ba.sh) OOP framework.

### Application
- `hackfm.sh` — main orchestrator: init, main loop, key dispatch, module loading
- `modules.class` — module loader and registry (pre_init, init, key registration, subscriptions)

### Panels & Files
- `panel.class` — individual panel (wraps filelist, handles rendering and navigation)
- `filelist.class` — directory listing, sorting, selection, find-and-select
- `archivelist.class` — archive contents listing and extraction

### Operations
- `openhandler.class` — open/execute dispatch: reads ext.conf, handles executables
- `dialogs.class` — modal dialog overlays (status, error, progress, input)

### UI Components
- `commandline.class` — command line input and history
- `menu.class` — menu system
- `fkeybar.class` — multi-layer F-key bar with per-layer label registration
- `title.class` — title bar with left/right text areas
- `dialog.class` — input/confirm/message dialog widget
- `msgbroker.class` — pub/sub message broker for inter-component communication

### Modules (`modules/`)
- `bus/` — message broker initialisation
- `terminal/` — interactive bash session via Ctrl+O
- `viewer/` — viewer.class, viewhandler.class, viewer.sh (subprocess)
- `editor/` — editor.class, edithandler.class, editor.sh (subprocess)
- `colors/` — colorpanel.class (overrides panel row rendering via pre_init)
- `titled/` — live title bar updates (clock, active directory)
- `fscopy/`, `fsmove/`, `fsdelete/`, `fsmkdir/`, `fsextract/` — file operations
- `fsarchive/` — archive creation and extraction
- `find/` — find file by name and content
- `fsattr/`, `quickdir/`, `usermenu/`, `vimhook/` — additional functionality

### TUI Library (`tui/`)
- `cursor.class` — cursor positioning and visibility
- `color.class` — terminal colors and reset
- `screen.class` — screen switching (main/alt), size detection
- `box.class` — box drawing characters
- `input.class` — keyboard input and key sequence parsing
- `style.class` — bold, underline, reset
- `region.class` — scrollable screen regions
- `mouse.class` — mouse event handling

---

## Extending hackfm

The easiest ways to extend hackfm without writing a module:

- Add viewer handlers in `conf/view.conf` for any file type
- Add editor handlers in `conf/edit.conf` for any file type
- Add open actions in `conf/ext.conf` for any file type
- Adjust file colors in `conf/colors.conf`

To add new functionality, write a module. Drop it in `modules/<name>/<name>.mod`
and enable it in `conf/hackfm.conf`. Your module has full access to all hackfm
internals — panels, dialogs, the broker, everything — because it runs in the same
bash process.

The ba.sh framework provides dot-notation OOP:

```bash
myobject.method arg1 arg2
myobject.property = "value"
local val=$(myobject.property)
```

See any existing module in `modules/` for a working example.
