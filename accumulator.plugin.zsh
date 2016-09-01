#
# No plugin manager is needed to use this file. All that is needed is adding:
#   source {where-accumulator-is}/accumulator.plugin.zsh
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

#
# Autoload and colors
#

autoload zaccu-process-buffer zaccu-usetty-wrapper zaccu-list zaccu-list-input zaccu-list-draw zaccu-list-wrapper accu

C_RESET=$'\e[0m'
C_BLACK=$'\e[0;30m'
C_RED=$'\e[0;31m'
C_GREEN=$'\e[0;32m'
C_YELLOW=$'\e[1;33m'
C_BLUE=$'\e[0;34m'
C_MAGENTA=$'\e[0;35m'
C_CYAN=$'\e[0;36m'
C_WHITE=$'\e[0;37m'

#
# Set up trackinghook
#

mkdir -p "${CONFIG_DIR}/data"

trackinghook() {
    local first second
    first="${(q)PWD}"
    second="${(q)1}"
    third="${(q)2}"

    print -r -- "$first $second $third" >> "${CONFIG_DIR}/data/input.db"
}

autoload add-zsh-hook
add-zsh-hook preexec trackinghook

#
# Initialize infrastructure globals
#

typeset -gA ZACCU_PLUGS_INITIAL_TEXT_GENERATORS ZACCU_PLUGS_TEXT_GENERATORS
typeset -gA ZACCU_PLUGS_FINAL_TEXT_GENERATORS ZACCU_PLUGS_LINK_HANDLERS

ZACCU_PLUGS_INITIAL_TEXT_GENERATORS=()
ZACCU_PLUGS_TEXT_GENERATORS=()
ZACCU_PLUGS_FINAL_TEXT_GENERATORS=()
ZACCU_PLUGS_LINK_HANDLERS=()

#
# Load plugins
#

# $1 - name of command (e.g. vim, cd) whose invocation is
#      to be routed to following generator
#
# $2 - name of initial generator function - called before
#      any input data gets processed
#
# $3 - name of generator function - the one that typically
#      puts text into ZACCU_OUTPUT_DOCUMENT_SECTIONS; it
#      should generate links that use $1 as type, so that
#      selections of the links will be routed to specified
#      handler
#
# $4 - name of final generator function - the one that is
#      run after all calls to above generator are done
#
# $5 - name of handler function - the one that knows what
#      to do with selected link from the document that
#      is generated from ZACCU_OUTPUT_DOCUMENT_SECTIONS;
#      standard action of handler should be putting
#      selected data at prompt with meaningful command
#      that uses the data
#
function zaccu_register_plugin() {
    local program="$1" initial="$2" generator="$3" final="$4" handler="$5"

    ZACCU_PLUGS_INITIAL_TEXT_GENERATORS[$program]="$initial"
    ZACCU_PLUGS_TEXT_GENERATORS[$program]="$generator"
    ZACCU_PLUGS_FINAL_TEXT_GENERATORS[$program]="$final"
    ZACCU_PLUGS_LINK_HANDLERS[$program]="$handler"
}

() {
    local p
    for p in "$REPO_DIR"/plugins/*.accu; do
        # The sourced plugin should provide 2 functions
        # and call zaccu_register_plugin() for them
        source "$p"
    done
}

#
# Setup Zle / keyboard shortcut
#

zle -N accu
bindkey '^B' accu
