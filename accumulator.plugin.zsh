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
    # Trust own CPU-time limiting SECONDS-based mechanism,
    # block Ctrl-C. Also, any infinite loop is impossible
    setopt localtraps; trap '' INT

    local -F SECONDS
    local -F start_time="$SECONDS" diff
    local time_limit=150

    local first second third
    first="${(q)${(q)PWD}}"
    second="${(q)1}"
    third="${(q)2}"

    ##
    # Get timestamp: via datetime module or via date command
    ##

    local fork ts
    zstyle -b ":accumulator:tracking" fork fork || fork="no"
    [ "$fork" = "yes" ] && fork=1 || fork=0

    if [ "$fork" = "0" ]; then
        [[ "${+modules}" = 1 && "${modules[zsh/datetime]}" != "loaded" && "${modules[zsh/datetime]}" != "autoloaded" ]] && zmodload zsh/datetime
        [ "${+modules}" = 0 ] && zmodload zsh/datetime
        ts="$EPOCHSECONDS"
    fi
    # Also a fallback
    if [[ "$fork" = "1" || -z "$ts" || "$ts" = "0" ]]; then
        ts="$( date +%s )"
    fi

    local proj_discovery_nparents
    local -a project_starters unit_starters
    zstyle -s ":accumulator:tracking" proj_discovery_nparents proj_discovery_nparents || proj_discovery_nparents=4
    zstyle -s ":accumulator:tracking" time_limit time_limit || time_limit="150"
    zstyle -a ":accumulator:tracking" project_starters project_starters \
        || project_starters=( .git .hg Makefile CMakeLists.txt configure SConstruct \*.pro \*.xcodeproj \*.cbp \*.kateproject \*.plugin.zsh )
    zstyle -a ":accumulator:tracking" unit_starters unit_starters_str || unit_starters=( Makefile CMakeLists.txt \*.pro )

    # A map of possible project files into compact mark
    local -A pfile_to_mark
    pfile_to_mark=( ".git" "GIT" ".hg" "HG" "Makefile" "MAKEFILE" "CMakeLists.txt" "CMAKELISTS"
                    "configure" "CONFIGURE" "SConstruct" "SCONSTRUCT" "*.pro" "PRO" "*.xcodeproj" "XCODE"
                    "*.cbp" "CBP" "*.kateproject" "KATE" "*.plugin.zsh" "ZSHPLUGIN" )

    local look_in="$PWD" ps
    local -a tmp subtract entries paths marks
    integer current_entry=1 result

    # -ge not -gt -> one run of the loop more than *_nparents,
    while [[ "$proj_discovery_nparents" -ge 0 && "$look_in" != "/" && "$look_in" != "$HOME" ]]; do
        (( proj_discovery_nparents = proj_discovery_nparents - 1 ))

        for ps in "${project_starters[@]}"; do
            (( (diff=(SECONDS-start_time)*1000) > time_limit )) && echo "${fg_bold[red]}TRACKING ABORTED, TOO SLOW (${diff%.*}ms / $proj_discovery_nparents)${reset_color}" && break 2
            result=0
            if [ "${ps/\*/}" != "$ps" ]; then
                tmp=( $look_in/$~ps(NY1) )
                [ "${#tmp}" != "0" ] && result=1
            else
                [ -e "$look_in/$ps" ] && result=1
            fi

            if (( result )); then
                entries[current_entry]="project"
                paths[current_entry]="$look_in"
                if (( ${+pfile_to_mark[$ps]} )); then
                    marks[current_entry]="${marks[current_entry]}${pfile_to_mark[$ps]}:1:"
                else
                    marks[current_entry]="${marks[current_entry]}NEW:$ps:"
                fi
            fi
        done

        if [ "${entries[current_entry]}" = "project" ]; then
            if [[ "$current_entry" -gt "1" ]]; then
                entries[current_entry-1]="subproject"
                # Check if previous entry will have any unit_starters
                # and will not have project_starters:|unit_starters
                tmp=( ${paths[current_entry-1]}/$^~unit_starters(NY1) )
                if [ "${#tmp}" != "0" ]; then
                    subtract=( "${(@)project_starters:|unit_starters}" )
                    tmp=( ${paths[current_entry-1]}/$^~subtract(NY1) )

                    if [ "${#tmp}" = "0" ]; then
                        # We have unit_starters-only project, turn it into unit
                        entries[current_entry-1]="unit"
                    fi
                fi
            fi

            current_entry+=1
        fi

        look_in="${look_in:h}"
    done

    integer count=${#entries} i
    local -a variadic
    for (( i=1; i<=count; i ++ )); do
        variadic+=( "${(q)entries[i]}" "${(q)paths[i]}" ":${(q)marks[i]}" )
    done

    # Zconvey plugin integration
    local convey_id="${(q)ZCONVEY_ID}" convey_name="${(q)ZCONVEY_NAME}"

    print -r -- "$ts $convey_id $convey_name $first $second $third ${variadic[*]}" >>! "${ZACCU_CONFIG_DIR}/data/input.db"

    [ "$ZACCU_DEBUG" = "1" ] && local t=$(( SECONDS - start_time )) && echo preexec ran ${t[1,5]}s
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
    reply+=( $'\1'"$id"$'\1'"$data1"$'\1'"$data2"$'\1'"$data3"$'\1'"$data4"$'\2'"[${text}]" )
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
