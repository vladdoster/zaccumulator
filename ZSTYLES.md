## Accumulator's Zstyles

Values being set are the defaults.

```zsh
zstyle ":accumulator" bold "0"                          # Draw interface with no bold
zstyle ":accumulator" colorpair "white/black"           # Text white, background black. Zsh 5.3 supports 254 numbers, e.g. 10/17
zstyle ":accumulator" border "1"                        # Draw border around main and status windows
zstyle ":accumulator:vim1" size "20"                    # Limits number of Vim entries
zstyle ":accumulator:vim1" backup_dir "~/.vbackup"      # Sets backup directory (for backup action of Vim plugin)
zstyle ":accumulator:emacs1" size "20"                  # Limits number of Emacs entries
zstyle ":accumulator:emacs1" backup_dir "~/.backup"     # Sets backup directory (for backup action of Emacs plugin)
```
