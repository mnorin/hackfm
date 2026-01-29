# hackfm
Hackable File Manager

File manager you can extend if you know bash.

It's a TUI file manager written in bash.

Uses [ba.sh](https://github.com/mnorin/ba.sh) for code organisation and ba.sh based TUI library for text graphics. Doesn't use ncurses, the idea is to use bash as much as possible in favor of external tools.

This is, obviously, an experimental tool, so be careful when using it.

Dependencies:

1. bash
2. awk
3. tar
4. 7z
5. unrar
6. unzip

Supports:

1. Navigating file system
2. File operations (copy, move, delete for files and directories)
3. Multiple file selection for file operations
4. Sorting file order ascending and descending on different fields
5. Integrated file viewer
6. Integrated text editor (be careful with this one, saves changes automatically, may need to fix it)
7. Navigating archives (tar, tar.gz, tar.bz2, tar.xz, zip, rar, 7z), extracting files is not supported yet, may require 

TODO:

1. Extracting files from archives
2. Message broken for components communication (e.g. triggering update on other components)
3. ? Multiple functional key layers
4. Centralized configuration

