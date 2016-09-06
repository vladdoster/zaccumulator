## Accumulator's Zstyles

The values being set are the defaults.

```zsh
# Main
zstyle ":accumulator" bold "0"                              # Draw interface with no bold
zstyle ":accumulator" colorpair "white/black"               # Text white, background black. Zsh 5.3 supports 254 numbers, e.g. 10/17
zstyle ":accumulator" border "1"                            # Draw border around main and status windows
zstyle ":accumulator" time_limit "500"                      # Start no later than after 500 milliseconds, skipping input data if necessary

# Tracking
zstyle ":accumulator:tracking" fork "0"                     # To obtain time stamp, use zsh/datetime module, if 1 then use date command
zstyle ":accumulator:tracking" proj_discovery_nparents "4"  # How many parent directories to check when determining if command is ran inside a project

\# Which files and directories change owning directory into a project
zstyle ":accumulator:tracking" project_starters .git .hg Makefile CMakeLists.txt configure SConstruct \*.pro \*.xcodeproj \*.cbp \*.kateproject \*.plugin.zsh
\# Which files and directories change owning directory into a unit if only there is a project in a parent directory
zstyle ":accumulator:tracking" unit_starters Makefile CMakeLists.txt \*.pro

# Vim plugin
zstyle ":accumulator:vim1" size "20"                        # Limits number of Vim entries
zstyle ":accumulator:vim1" backup_dir "~/.backup"           # Sets backup directory (for backup action of Vim plugin)

# Emacs plugin
zstyle ":accumulator:emacs1" size "20"                      # Limits number of Emacs entries
zstyle ":accumulator:emacs1" backup_dir "~/.backup"         # Sets backup directory (for backup action of Emacs plugin)

# Shell Utils plugin
zstyle ":accumulator:shellutils1" size "15"                 # Limits number of entries (i.e. of files)
zstyle ":accumulator:shellutils1" backup_dir "~/.backup"    # Sets backup directory (for backup action of Shell Utils plugin)
zstyle ":accumulator:shellutils1" keep_going "100"          # Try `keep_going`-times to add command to any existing entry, after reaching max # of entries
zstyle ":accumulator:shellutils1" sort_order "recent_first" # Files from newer commands are before others. Also: "file_locations" – lexical sort on full file paths
```
