# hackfm
Hackable File Manager

A TUI file manager written in bash. Extend it if you know bash.

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
- Sort by name, date, size, or extension (via Left/Right menus)
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
- Ctrl+O toggles between file manager and full-screen terminal buffer
- Ctrl+Up / Ctrl+Down scroll through command history
- Ctrl+/ inserts the path of the selected file into the command line
- Ctrl+R reloads the active panel
- Ctrl+U clears the command line

---

## Key Bindings

| Key | Action |
|-----|--------|
| Tab | Switch active panel |
| Enter | Open file / enter directory or archive |
| Insert | Toggle file selection |
| F3 | View file |
| F4 | Edit file |
| F5 | Copy / Extract from archive |
| F6 | Move / Rename |
| F7 | Make directory |
| F8 | Delete |
| F9 | Menu bar |
| F10 | Quit |
| Ctrl+O | Toggle terminal buffer |
| Ctrl+Up | Previous command in history |
| Ctrl+Down | Next command in history |
| Ctrl+/ | Insert selected file path into command line |
| Ctrl+R | Reload active panel |
| Ctrl+U | Clear command line |
| Ctrl+S | Sort menu |

---

## Configuration

All configuration lives in the `conf/` directory.

### conf/hackfm.conf
Main configuration file.

```
# Open executables in a new terminal window (1) or inline (0)
open_execute_in_terminal=0

# Default external editor (leave empty to use internal editor)
default_editor=
```

### conf/view.conf
Maps file extensions to viewer commands. Use `%f` as a placeholder for the filepath.

```
pdf     pdftotext -layout %f -
json    python3 -m json.tool %f
iso     isoinfo -d -i %f
```

If the command is not found or produces no output, the built-in viewer is used as fallback.

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

## Architecture

hackfm is built from small, single-responsibility bash classes using the [ba.sh](https://github.com/mnorin/ba.sh) OOP framework.

### Application
- `hackfm.sh` — main orchestrator: init, main loop, key dispatch
- `appframe.class` — overall screen layout

### Panels & Files
- `panel.class` — individual panel (wraps filelist, handles rendering and input)
- `filelist.class` — directory listing, sorting, selection
- `archivelist.class` — archive contents listing and extraction
- `statusbar.class` — panel status bar

### Operations
- `fs.class` — file operations: copy, move, delete, mkdir, extract
- `viewhandler.class` — view dispatch: reads view.conf, handles archive extraction, delegates to viewer
- `edithandler.class` — edit dispatch: reads edit.conf, handles external editors, delegates to editor
- `dialogs.class` — modal dialog overlays (status, error, progress, input)

### UI Components
- `viewer.class` — text file viewer engine
- `editor.class` — text file editor engine
- `commandline.class` — command line input and history
- `menu.class` / `menubar.class` — menu system
- `fkeybar.class` — F-key bar at bottom
- `dialog.class` — input/confirm/message dialog widget
- `msgbroker.class` — message broker for inter-component communication

### TUI Library (`tui/`)
- `cursor.class` — cursor positioning and visibility
- `color.class` — terminal colors
- `screen.class` — screen switching (main/alt), size
- `box.class` — box drawing
- `input.class` — keyboard input and key sequence parsing
- `style.class` — bold, underline, etc.
- `region.class` — scrollable screen regions
- `mouse.class` — mouse event handling

---

## Extending hackfm

Since everything is bash, you can:

- Add viewer handlers in `conf/view.conf` for any file type
- Add editor handlers in `conf/edit.conf` for any file type
- Add open actions in `conf/ext.conf` for any file type
- Edit any `.class` file to change behaviour
- Add new `.class` files and source them in `hackfm.sh`

The ba.sh framework lets you define classes with properties and methods using dot notation:

```bash
myobject.method arg1 arg2
myobject.property = "value"
local val=$(myobject.property)
```
