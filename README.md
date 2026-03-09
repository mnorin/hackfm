# hackfm
Hackable File Manager

A TUI file manager written in pure bash. Extend it if you know bash.

Uses [ba.sh](https://github.com/mnorin/ba.sh) for code organisation and a ba.sh-based TUI library for text graphics. Doesn't use ncurses — the idea is to use bash as much as possible and minimise external tool dependencies.

This is an experimental tool. Be careful when using it, especially with file operations.

---

## Dependencies

Required:
- bash
- awk
- find
- stat

Optional (for archive support):
- tar
- unzip
- unrar
- 7z / 7za / 7zr
- isoinfo (from genisoimage, for ISO 9660 images)

Optional (for view.conf handlers):
- Various tools depending on what you configure (pdftotext, ffprobe, identify, etc.)

---

## Features

### File Management
- Two-panel layout
- Navigate the filesystem in both panels independently
- Copy, move, delete files and directories (with progress dialogs for large operations)
- Create directories (F7)
- Multiple file selection with Insert key
- Tab to switch between panels

### Sorting
- Sort by name, date, size, or extension (via Left/Right menus or Ctrl+S)
- Ascending and descending order
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

Press Enter to navigate into and out of archives. F5 to extract files.

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

### Command Line
- Integrated command line at the bottom of the screen
- Commands run in the current directory of the active panel
- Ctrl+O toggles between file manager and a full interactive bash session
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

### F-Key Layers
- The F-key bar supports multiple layers of 10 keys each
- Layer 0: F1–F10, Layer 1: F11–F20 (physical F1–F10), etc.
- Ctrl+Left / Ctrl+Right cycles between layers
- Current layer shown as `L0`, `L1`, etc. at the left of the F-key bar
- Modules register keys on any layer — e.g. `F14` puts a key on Layer 1, physical F4

### User Menu (F2)
- Customisable user menu defined in the `conf/menu` directory
- Add your own commands and scripts accessible from the file manager

### Quick Directory Jump (Ctrl+D)
- Jump to frequently used directories
- Configurable directory list

---

## Key Bindings

### Navigation

| Key | Action |
|-----|--------|
| Up / Down | Move cursor |
| PgUp / PgDn | Page up / page down |
| Home / End | Jump to first / last file (or move cursor in command line) |
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
| F7 | Make directory |
| F8 | Delete |
| F9 | Menu bar (sorting and more) |
| F10 | Quit |

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
| Ctrl+O | Toggle terminal (full interactive bash session) |
| Ctrl+R | Reload active panel |
| Ctrl+S | Quick sort menu |
| Ctrl+A | File attributes |
| Ctrl+D | Quick directory jump |
| Ctrl+Left | Previous F-key layer |
| Ctrl+Right | Next F-key layer |

### F-Key Layers

Layer 0 (default):

| Key | Action |
|-----|--------|
| F2 | User menu |
| F3 | View |
| F4 | Edit |
| F5 | Copy / Extract |
| F6 | Move |
| F7 | Mkdir |
| F8 | Delete |
| F9 | Menu |
| F10 | Quit |

Layer 1 (Ctrl+Right to switch):

| Key | Action |
|-----|--------|
| F4 (physical) | Open in Vim (vimhook module, if vim is installed) |

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
module_quickdir_enabled=1
module_usermenu_enabled=1
module_vimhook_enabled=1
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

## Modular Architecture

hackfm has a module system that lets you add new functionality without touching core code.
Modules live in `modules/<name>/<name>.mod` and are enabled in `conf/hackfm.conf`.

### Module Lifecycle

Each module can implement any combination of three functions:

```bash
name.pre_init()   # Called before any objects are created — use to override constructors
name.init()       # Called after all objects exist — use to register keys, menu items, subscriptions
name.run()        # The action handler — called by key dispatch when the module's key is pressed
```

`pre_init` is the powerful one: because it runs before panels and appframe are created, a module
can redefine any constructor (`panel()`, `appframe()`, etc.) to alter how objects are built.
The `colors` module uses this to wrap `panel()` and inject color-aware row rendering without
touching `panel.class` at all.

### Registering Keys

In `name.init`, call:

```bash
hackfm.module.register_key "F5" "mymodule.run" "MyLabel"
# or on layer 1 (physical F5 = F15):
hackfm.module.register_key "F15" "mymodule.run" "MyLabel"
```

The label appears in the F-key bar. Multiple modules can register the same key — the first
handler that returns 0 wins; return 1 to pass to the next handler.

### Subscribing to Events

```bash
hackfm.module.subscribe "viewer_closed" "mymodule.on_viewer_closed"
```

### Adding Menu Items

```bash
hackfm.module.add_menu_item "File" "My Action" "mymodule.run"
```

### Module Example

A minimal module that opens the selected file in `less`:

```bash
#!/bin/bash
# modules/lessview/lessview.mod

lessview.init() {
    hackfm.module.register_key "F13" "lessview.run" "Less"
}

lessview.run() {
    local panel=$(get_active_panel)
    local filepath=$($panel.get_selected_filepath)
    [ -z "$filepath" ] && return 1
    tui.screen.main
    less "$filepath"
    tui.screen.alt
    draw_screen
}
```

Enable it by adding `module_lessview_enabled=1` to `conf/hackfm.conf`.

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
Delete files and directories (F8). Shows a confirmation dialog listing the files
to be deleted. Supports deleting multiple selected files at once.

### fsmkdir
Create a new directory (F7). Prompts for the directory name.

### fsextract
Extract files from an archive (F5 when browsing an archive). Prompts for
destination directory.

### fsattr
Show file attributes dialog (Ctrl+A). Displays permissions, owner, size, and timestamps
for the selected file.

### quickdir
Quick directory jump (Ctrl+D). Jump to a configured list of favourite directories
without navigating there manually.

### usermenu
User-defined menu (F2). Define your own commands and scripts in the `conf/menu`
directory and invoke them from within the file manager.

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
- `appframe.class` — overall screen layout (title bar, panels area, F-key bar)

### Panels & Files
- `panel.class` — individual panel (wraps filelist, handles rendering and input)
- `filelist.class` — directory listing, sorting, selection
- `archivelist.class` — archive contents listing and extraction
- `statusbar.class` — panel status bar

### Operations
- `openhandler.class` — open/execute dispatch: reads ext.conf, handles executables
- `dialogs.class` — modal dialog overlays (status, error, progress, input)

### UI Components
- `commandline.class` — command line input and history
- `menu.class` — menu system
- `fkeybar.class` — multi-layer F-key bar at the bottom
- `dialog.class` — input/confirm/message dialog widget
- `msgbroker.class` — pub/sub message broker for inter-component communication

### Modules (`modules/`)
- `viewer/` — viewer.class, viewhandler.class, viewer.sh (subprocess)
- `editor/` — editor.class, edithandler.class, editor.sh (subprocess)
- `colors/` — colorpanel.class (overrides panel row rendering via pre_init)
- `fscopy/`, `fsmove/`, `fsdelete/`, `fsmkdir/`, `fsextract/` — file operations
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
