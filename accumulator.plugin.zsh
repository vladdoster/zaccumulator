#
# No plugin manager is needed to use this file. All that is needed is adding:
#   source {where-accumulator-is}/accumulator.plugin.zsh
#
# to ~/.zshrc.
#

0="${(%):-%N}" # this gives immunity to functionargzero being unset
ZACCU_REPO_DIR="${0%/*}"
ZACCU_CONFIG_DIR="$HOME/.config/accumulator"

#
# Update FPATH if:
# 1. Not loading with Zplugin
# 2. Not having fpath already updated (that would equal: using other plugin manager)
#

if [[ -z "$ZPLG_CUR_PLUGIN" && "${fpath[(r)$ZACCU_REPO_DIR]}" != $ZACCU_REPO_DIR ]]; then
    fpath+=( "$ZACCU_REPO_DIR" )
fi

#
# Autoload
#

autoload zaccu-process-buffer zaccu-usetty-wrapper zaccu-list zaccu-list-input zaccu-list-draw zaccu-list-wrapper accumulator __from-zhistory-accumulate

#
# Set up trackinghook
#

mkdir -p "${ZACCU_CONFIG_DIR}/data"

__trackinghook() {
    local first second
    # Simlate as-from-input quoting on PWD
    # by additional (q) – as if user entered
    # the path with backslashes
    first="${(q)${(q)PWD}}"
    second="${(q)1}"
    third="${(q)2}"

    ##
    # Get timestamp: via datetime module or via date command
    ##

    local fork ts
    zstyle -s ":accumulator:tracking" fork fork || fork="0"

    if [ "$fork" = "0" ]; then
        [[ "${+modules}" = 1 && "${modules[zsh/datetime]}" != "loaded" && "${modules[zsh/datetime]}" != "autoloaded" ]] && zmodload zsh/datetime
        [ "${+modules}" = 0 ] && zmodload zsh/datetime
        ts="$EPOCHSECONDS"
    else
        ts="$( date +%s )"
    fi

    ##
    # Check if we are in a project – by detecting .git dir,
    # files: Makefile, CMakeLists.txt, configure, etc.
    ##

    local proj_discovery_nparents
    zstyle -s ":accumulator:tracking" proj_discovery_nparents proj_discovery_nparents || proj_discovery_nparents=4

    local look_in="$PWD" marks="" saved_marks
    local -a tmp
    integer PROJECT=0 SUBPROJECT=0
    # -ge not -gt -> one run of the loop more than *_nparents,
    # for PWD check, i.e. of current, not parent directory
    while [[ "$proj_discovery_nparents" -ge 0 && "$look_in" != "/" ]]; do
        (( proj_discovery_nparents = proj_discovery_nparents - 1 ))
        [ -e "$look_in/.git" ] && marks+="GIT:1:"
        [ -e "$look_in/Makefile" ] && marks+="MAKEFILE:1:"
        [ -e "$look_in/CMakeLists.txt" ] && marks+="CMAKELISTS.TXT:1:"
        [ -e "$look_in/configure" ] && marks+="CONFIGURE:1:"
        [ -e "$look_in/SConstruct" ] && marks+="SCONSTRUCT:1:"

        tmp=( "$look_in"/*.pro(NY1) )
        [ "${#tmp}" != "0" ] && marks+="PRO:1:"
        tmp=( "$look_in"/*.xcodeproj(NY1) )
        [ "${#tmp}" != "0" ] && marks+="XCODEPROJ:1:"
        tmp=( "$look_in"/*.cbp(NY1) )
        [ "${#tmp}" != "0" ] && marks+="CBP:1:"

        if [ -n "$marks" ]; then
            if [ "$PROJECT" = "1" ]; then
                marks=""
                # Guard typical possible accident:
                # Makefile or .git, etc. in $HOME
                if [ "$look_in" != "$HOME" ]; then
                    SUBPROJECT=1
                    saved_marks+="SUBPROJECT:1:"
                    # No save of outer project's marks
                    break;
                fi
            else
                # Guard typical possible accident:
                # Makefile or .git, etc. in $HOME
                if [ "$look_in" != "$HOME" ]; then
                    PROJECT=1
                    saved_marks="${marks}PROJECT:1:"
                fi
                marks=""
            fi
        fi
        look_in="${look_in:h}"
    done

    # Empty saved_marks will become: ''
    print -r -- "$ts $first $second $third ${(q)saved_marks}" >> "${ZACCU_CONFIG_DIR}/data/input.db"
}

autoload add-zsh-hook
add-zsh-hook preexec __trackinghook

#
# Initialize infrastructure globals
#

typeset -gA ZACCU_PLUGS_INITIAL_TEXT_GENERATORS ZACCU_PLUGS_TEXT_GENERATORS ZACCU_PLUGS_FINAL_TEXT_GENERATORS
typeset -gA ZACCU_PLUGS_ACTION_IDS_TO_HANDLERS ZACCU_CONFIG

ZACCU_PLUGS_INITIAL_TEXT_GENERATORS=()
ZACCU_PLUGS_TEXT_GENERATORS=()
ZACCU_PLUGS_FINAL_TEXT_GENERATORS=()
ZACCU_PLUGS_ACTION_IDS_TO_HANDLERS=()
ZACCU_CONFIG=()

#
# Load standard library
#

source "$ZACCU_REPO_DIR"/plugins/stdlib.laccu

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

    # Ability to register multiple generators per single command
    ZACCU_PLUGS_INITIAL_TEXT_GENERATORS[$program]="${ZACCU_PLUGS_INITIAL_TEXT_GENERATORS[$program]} $initial"
    ZACCU_PLUGS_INITIAL_TEXT_GENERATORS[$program]="${ZACCU_PLUGS_INITIAL_TEXT_GENERATORS[$program]# }"
    ZACCU_PLUGS_TEXT_GENERATORS[$program]="${ZACCU_PLUGS_TEXT_GENERATORS[$program]} $generator"
    ZACCU_PLUGS_TEXT_GENERATORS[$program]="${ZACCU_PLUGS_TEXT_GENERATORS[$program]# }"
    ZACCU_PLUGS_FINAL_TEXT_GENERATORS[$program]="${ZACCU_PLUGS_FINAL_TEXT_GENERATORS[$program]} $final"
    ZACCU_PLUGS_FINAL_TEXT_GENERATORS[$program]="${ZACCU_PLUGS_FINAL_TEXT_GENERATORS[$program]# }"
}


# Appends hyperlink into "reply" output array. It's the
# standard action button, shown without surrounding
# "[" and "]".
#
# $1 - action ID
# $2 - data1, e.g. timestamp
# $3 - data2, e.g. command
# $4 - data3, e.g. active path
# $5 - data4, e.g. file path, file name, URL, other data
# $6 - text
# $7 - handler function name
#
# $reply array is extended by hyperlink's text (one new element)
#
function zaccu_get_std_button() {
    local id="${(q)1}" data1="${(q)2}" data2="${(q)3}" data3="${(q)4}" data4="${(q)5}" text="$6" handler="$7"
    reply+=( $'\1'"$id"$'\1'"$data1"$'\1'"$data2"$'\1'"$data3"$'\1'"$data4"$'\2'"${text}" )
    ZACCU_PLUGS_ACTION_IDS_TO_HANDLERS[$id]="$handler"
}

# Appends button hyperlink into "reply" output array
#
# Arguments are the same as in zaccu_get_std_button
#
function zaccu_get_button() {
    local id="${(q)1}" data1="${(q)2}" data2="${(q)3}" data3="${(q)4}" data4="${(q)5}" text="$6" handler="$7"
    reply+=( "["$'\1'"$id"$'\1'"$data1"$'\1'"$data2"$'\1'"$data3"$'\1'"$data4"$'\2'"${text}]" )
    ZACCU_PLUGS_ACTION_IDS_TO_HANDLERS[$id]="$handler"
}

() {
    local p
    for p in "$ZACCU_REPO_DIR"/plugins/*.accu; do
        # The sourced plugin should provide 2 functions
        # and call zaccu_register_plugin() for them
        source "$p"
    done
}

#
# Setup Zle / keyboard shortcut
#

zle -N accumulator
bindkey '^B' accumulator
