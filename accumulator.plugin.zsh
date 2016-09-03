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

# Available colors to embed in generated text
C_RED=$'\7'
C_RED_E=$'\25'
C_GREEN=$'\3'
C_GREEN_E=$'\25'
C_YELLOW=$'\4'
C_YELLOW_E=$'\25'
C_MAGENTA=$'\5'
C_MAGENTA_E=$'\25'
C_CYAN=$'\6'
C_CYAN_E=$'\25'

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

typeset -gA ZACCU_PLUGS_INITIAL_TEXT_GENERATORS ZACCU_PLUGS_TEXT_GENERATORS ZACCU_PLUGS_FINAL_TEXT_GENERATORS
typeset -gA ZACCU_PLUGS_ACTION_IDS_TO_HANDLERS

ZACCU_PLUGS_INITIAL_TEXT_GENERATORS=()
ZACCU_PLUGS_TEXT_GENERATORS=()
ZACCU_PLUGS_FINAL_TEXT_GENERATORS=()
ZACCU_PLUGS_ACTION_IDS_TO_HANDLERS=()

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
function zaccu_register_plugin() {
    local program="$1" initial="$2" generator="$3" final="$4"

    ZACCU_PLUGS_INITIAL_TEXT_GENERATORS[$program]="$initial"
    ZACCU_PLUGS_TEXT_GENERATORS[$program]="$generator"
    ZACCU_PLUGS_FINAL_TEXT_GENERATORS[$program]="$final"
}


# Appends hyperlink into "reply" output array. It's the
# standard action button, shown without surrounding
# "[" and "]".
#
# $1 - action ID
#
# $2 - data1, e.g. timestamp
#
# $3 - data2, e.g. active path
#
# $4 - data3, e.g. file path, file name, URL, other data
#
# $5 - text
#
# $6 - handler function
#
function zaccu_get_std_button() {
    local id="$1" data1="$2" data2="$3" data3="$4" text="$5"
    reply+=( $'\1'"$id"$'\1'"$data1"$'\1'"$data2"$'\1'"$data3"$'\2'"${text}" )
    ZACCU_PLUGS_ACTION_IDS_TO_HANDLERS[$id]="$6"
}

# Appends button hyperlink into "reply" output array
#
# Arguments are the same as in zaccu_get_std_button
#
function zaccu_get_button() {
    local id="$1" data1="$2" data2="$3" data3="$4" text="$5"
    reply+=( "["$'\1'"$id"$'\1'"$data1"$'\1'"$data2"$'\1'"$data3"$'\2'"${text}]" )
    ZACCU_PLUGS_ACTION_IDS_TO_HANDLERS[$id]="$6"
}

# Resolves absolute path from current working directory and file path
#
# $1 - current working directory
#
# $2 - file path
#
# $reply[1] - dirname
#
# $reply[2] - basename
#
function zaccu_resolve_path() {
    local dirpath="$1" filepath="$2"

    local dirpath2="${dirpath/#\~/$HOME}"
    local filepath2="${filepath/#\~/$HOME}"

    reply=()
    if [ "${filepath2[1]}" = "/" ]; then
        reply[1]="${filepath2:h}"
        reply[2]="${filepath2:t}"
    else
        local p="$dirpath2/$filepath2"
        reply[1]="${p:h}"
        reply[2]="${p:t}"
    fi
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
