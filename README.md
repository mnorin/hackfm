# hackfm
Hackable File Manager

A TUI file manager written in bash. Extend it if you know bash.

Uses [ba.sh](https://github.com/mnorin/ba.sh) for code organisation and a ba.sh based TUI library for text graphics. Doesn't use ncurses — the idea is to use bash as much as possible in favor of external tools.

This is an experimental tool, so be careful when using it.

## Dependencies

### Required

- **bash** (4.0+) — requires associative arrays (`declare -A`) and `${var^^}` case conversion. macOS ships with bash 3.2 by default; install a newer version via Homebrew (`brew install bash`) if needed.
- **tar** — for tar-based archive browsing and extraction
- **unzip** — for zip archive support
- **unrar** — for rar archive support
- **7z** / **7za** / **7zr** — for 7z archive support (any one of these)

### Standard utilities (expected to be present on any Linux system)

These are used internally and are part of GNU coreutils or util-linux:

`awk`, `sed`, `grep`, `cut`, `sort`, `wc`, `tr`, `stat`, `file`, `find`, `head`, `tail`, `cat`, `cp`, `mv`, `rm`, `mkdir`, `stty`, `tput`, `hostname`

## Features

### File Manager

Two-panel layout inspired by Midnight Commander. Each panel shows the contents of a directory with file names, sizes, modification dates, and permissions.

- Navigate the file system with arrow keys, Page Up/Down, Home, End
- Switch between panels with Tab
- Execute shell commands directly from the command line at the bottom
- Command history navigation with Up/Down arrows when command line is active
- Quick search within the current panel (Ctrl+S)
- Toggle between file manager and an interactive terminal session (Ctrl+O)
- Reload the active panel (Ctrl+R)

### File Operations

- **View** — open file in the built-in viewer (F3)
- **Edit** — open file in the built-in editor (F4)
- **Copy** — copy file or directory to the other panel (F5)
- **Move/Rename** — move or rename file or directory (F6)
- **Make directory** — create a new directory (F7)
- **Delete** — delete file or directory with confirmation (F8)
- **Multi-select** — mark/unmark files with Insert key, then apply operations to all marked files

### Archive Support

Browse inside archives as if they were directories. Supported formats:

- tar, tar.gz / tgz, tar.bz2 / tbz2, tar.xz / txz
- zip
- rar
- 7z

Press Enter on an archive to navigate inside it. Press F5 inside an archive to extract the selected file.

### File Viewer (F3)

- Scroll with arrow keys, Page Up/Down, Home, End
- Syntax-aware viewing via conf/view.conf — map file extensions to external conversion commands (e.g. render markdown, highlight source code)
- Exit with F3, F10

### Text Editor (F4)

- Full cursor navigation: arrow keys, Page Up/Down, Home, End
- Text selection with F3 (toggle selection mode)
- Copy selection (F5)
- Move/cut-paste selection (F6)
- Delete current line (F8)
- Save (F2)
- Exit with F10 (prompts to save if there are unsaved changes)
- ESC clears the current selection

> **Note:** The editor saves changes when you exit via F10 and confirm. Be careful — it modifies files directly.

### Command Line

The command line at the bottom of the screen runs shell commands in the current panel's directory.

- Type a command and press Enter to execute
- **Ctrl+/** — insert the filename under the cursor at the current command line position (useful for building commands like `./script arg1 arg2`)
- **Ctrl+U** — clear the command line
- **Up/Down arrows** — navigate command history (when command line is active)

### Configuration

#### conf/ext.conf
Maps file extensions to programs to open them with when pressing Enter. Each line: `extension command`.

#### conf/view.conf
Maps file extensions to commands for the built-in viewer. Each line: `extension command`. Use `%f` as a placeholder for the file path, or omit it to have the path appended automatically.

## Keyboard Reference

### File Manager

| Key | Action |
|-----|--------|
| Arrow keys | Navigate files |
| Page Up / Page Down | Scroll page |
| Home / End | Jump to first / last file |
| Enter | Open file or enter directory / execute command |
| Tab | Switch active panel |
| Insert | Toggle file selection |
| Backspace | Go to parent directory |
| F3 | View file |
| F4 | Edit file |
| F5 | Copy file (or extract from archive) |
| F6 | Move / rename file |
| F7 | Create directory |
| F8 | Delete file or directory |
| F9 | Open menu |
| F10 | Quit |
| Ctrl+/ | Insert filename under cursor into command line |
| Ctrl+U | Clear command line |
| Ctrl+R | Reload active panel |
| Ctrl+S | Quick search in current panel (if you terminal intercepts it, press Ctrl-O twice and try again) |
| Ctrl+O | Toggle terminal session |
| ESC | Clear command line |

### File Viewer

| Key | Action |
|-----|--------|
| Up / Down | Scroll one line |
| Page Up / Page Down | Scroll one page |
| Home / End | Jump to start / end |
| F3 / F10 | Exit viewer |

### Text Editor

| Key | Action |
|-----|--------|
| Arrow keys | Move cursor |
| Page Up / Page Down | Scroll page |
| Home / End | Jump to line start / end |
| F2 | Save |
| F3 | Toggle selection |
| F5 | Copy selection |
| F6 | Move (cut + paste) selection |
| F8 | Delete current line |
| F10 | Exit (prompts to save if modified) |
| ESC | Clear selection |

## TODO

- Extracting files from archives (needs improving)
- User menu (F2)
- Multiple functional key layers
- Centralized configuration (in progress)
- Massive refactoring of the main script
- Performance improvements (still things to be improved)
