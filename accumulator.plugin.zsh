#
# No plugin manager is needed to use this file. All that is needed is adding:
#   source {where-zzcomplete-is}/zzcomplete.plugin.zsh
#
# to ~/.zshrc.
#

0="${(%):-%N}" # this gives immunity to functionargzero being unset
REPO_DIR="${0%/*}"
CONFIG_DIR="$HOME/.config/accumulator"

#
# Update FPATH if:
# 1. Not loading with Zplugin
# 2. Not having fpath already updated (that would equal: using other plugin manager)
#

if [[ -z "$ZPLG_CUR_PLUGIN" && "${fpath[(r)$REPO_DIR]}" != $REPO_DIR ]]; then
    fpath+=( "$REPO_DIR" )
fi

autoload zaccu-process-buffer zaccu-usetty-wrapper zaccu-list zaccu-list-input zaccu-list-draw zaccu-list-wrapper accu

mkdir -p "${CONFIG_DIR}/data"

trackinghook() {
    local first second
    first="${(q)1}"
    second="${(q)2}"

    local newline=$'\n'
    first="${first//$newline/\\$newline}"
    second="${second//$newline/\\$newline}"

    print -r -- "$first $second" >> "${CONFIG_DIR}/data/input.db"
}

autoload add-zsh-hook
add-zsh-hook preexec trackinghook

zle -N accu
bindkey '^B' accu
