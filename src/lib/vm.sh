
#
# ========================================================================================
# Attributes functions
# ========================================================================================
#
# Functions starting with an underscore
# give information and values related to VMs,
#

# qube.exists returns 0 if the qube is found, or 1 if not.
# $1 - Qube name
function qube.exists ()
{
    vm=""
    for item in $(qvm-ls --raw-list | grep -v dom0)
    do
        if [ "${item}" == "${1}" ]; then
            vm=${1}
        fi
    done
    if [ ${#vm} -eq 0 ]; then
        return 1
    fi

    return 0
}

# Returns the name of the identity to which a VM belongs.
# $1 - Qube name
function qube.owner ()
{
    qvm-tags "$1" | grep "^$IDENTITY\$" 2>/dev/null
}

# qube.is_identity_proxy verifies that the identity's proxy VMs arrays contains a given VM.
# $1 - Qube name
function qube.is_identity_proxy ()
{
    local vm="$1"
    local match proxies

    match=1
    read -rA proxies < <(identity.proxy_qubes)

    for proxy in "${proxies[@]}"; do
        if [[ $vm == "$proxy" ]]; then
            match=0
            break
        fi
    done

    return $match
}

# qube.root_template returns the updateable template of a given VM.
# Example: if a disposable VM is given as argument, the first resolved
# template is the dispvm template, which itself is an AppVM, so we get
# the template of the dispvm template.
# $1 - Qube name
function qube.root_template ()
{
    local vm="${1}"
    local updateable

    template="$(qvm-prefs "${vm}" template 2>/dev/null)"
    updateable="$(qvm-prefs "${vm}" updateable 2>/dev/null)"

    while [[ "${updateable}" == "False" ]]; do
        template="$(qvm-prefs "${template}" template 2>/dev/null)"
        updateable="$(qvm-prefs "${template}" updateable 2>/dev/null)"
    done

    echo "${template}"
}

# qube.command_args returns a list of VMs that are either explicitly named
# in the array passed as arguments, or those belonging to some
# "group keyword" of this same array.
# $@ - Any number of qubes' names, patterns or group keywords.
function qube.command_args ()
{
    local vms=("$@")
    local all=()
    local can_update=()
    local updatevm

    [[ -z "${vms[*]}" ]] && return

    # All updateable VMs, except the updater one
    read -rA can_update < <(qubes.list_all_updateable)
    updatevm="$(qubes.updatevm_template)"
    read -rA can_update <<< "${can_update:#$~updatevm}"

    for word in "${vms[@]}"; do
        case "${word}" in
            torbrowser|dom0)
                # Tor browser is handled in the risk_qube_update_command function.
                # Dom0 is handled in the risk_qube_update_command function.
                ;;
            all)
                all+=( "${updatevm}" )
                all+=( "${can_update[@]}" )
                ;;
            *cacher)
                all+=( "${updatevm}" )
                ;;
            *)
                # Else return the VM name itself
                for vm in "${can_update[@]}"; do
                    [[ "${vm}" =~ ${word} ]] && all+=( "${vm}" )
                done
                ;;
        esac

    done

    echo "${all[@]}"
}

# qube.is_browser_instance returns 0 if the qube is either 
# the identity browser qube itself, or a disposable based on it.
# $1 - Qube name
function qube.is_browser_instance ()
{
    local qube="$1"
    local qube_class

    [[ "${qube}" == "dom0" ]] && return 1
    [[ -z "${qube}" ]] && return 1

    # Get the type of qube, and return if not compatible.
    qube_class="$(qvm-prefs "${qube}" klass 2>/dev/null)"
    [[ "${qube_class}" == "TemplateVM" ]] && return 1

    # If it's a disposable, use the template.
    if [[ "${qube_class}" == "DispVM" ]]; then
        qube="$(qvm-prefs "${qube}" template)" 
    fi

    [[ "${qube}" == "$(identity.browser_qube)" ]] || return 1
}


# ========================================================================================
#  VM control and settings management
# ========================================================================================
#

# qube.enable enables a VM to autostart
function qube.enable ()
{
    local name="$1"
    local enabled=( "$(identity.enabled_qubes)" )

    # Check if the VM is already marked autostart
    for vm in "${enabled[@]}" ; do
        if [[ $vm == "$name" ]]; then
            already_enabled=true
        fi
    done

    if [[ ! $already_enabled ]]; then
        _info "Enabling VM ${name} to autostart"
        identity.config_append AUTOSTART_QUBES "${name}"
        # echo "$name" >> "${IDENTITY_DIR}/autostart_vms"
    else
        _info "VM ${name} is already enabled"
    fi
}

# qube.disable disables a VM to autostart
function qube.disable ()
{
    local name="$1"
    _info "Disabling VM $name"
    local autostart_qubes
    autostart_qubes=$(identity.config_get AUTOSTART_QUBES)

    autostart_qubes=$(sed /^"$name"\$/d <<<"${autostart_qubes}")
    identity.config_set AUTOSTART_QUBES "${autostart_qubes}"
    # sed -i /^"$name"\$/d "${IDENTITY_DIR}/autostart_vms"
}

# qube.start [vm 1] ... [vm n]
#Start the given VMs without executing any command.
function qube.start ()
{
    local ret=0

    local vm=
    declare -A pids=() #VM --> pid
    for vm in "$@" ; do
        [[ "$vm" == "dom0" ]] && continue
        _verbose "Starting: $vm"
        qube.assert_running "$vm" &
        pids["$vm"]=$!
    done

    local failed=""
    local ret=
    for vm in "${(@k)pids}" ; do
        wait "${pids["$vm"]}"
        ret=$?
        [ $ret -ne 0 ] && failed="$failed"$'\n'"$vm ($ret)"
    done

    [ -z "$failed" ] || _verbose "Starting the following VMs failed: $failed"

    #set exit code
    [ -z "$failed" ]
}

# qube.shutdown [vm 1] ... [vm n]
#Shut the given VMs down.
function qube.shutdown ()
{
    local ret=0

    if [ $# -gt 0 ] ; then
        #make sure the VMs are unpaused
        #cf. https://github.com/QubesOS/qubes-issues/issues/5967
        local vm=
        for vm in "$@" ; do
            qvm-unpause "$vm" &> /dev/null
        done

        _verbose "Shutting down: $*"
        qvm-shutdown --wait "$@"
        ret=$?
    fi

    return $ret
}

#qube.assert_running [vm] [start]
#Assert that the given VM is running. Will unpause paused VMs and may start shut down VMs.
#[vm]: VM for which to make sure it's running.
#[start]: If it's not running and not paused, start it (default: 0/true). If set to 1, this function will return a non-zero exit code.
#returns: A non-zero exit code, if it's not running and/or we failed to start the VM.
function qube.assert_running ()
{
    local vm="$1"
    local start="${2:-0}"

    #make sure the VM is unpaused
    if qvm-check --paused "$vm" &> /dev/null ; then
        qvm-unpause "$vm" &> /dev/null || return 1
    else
        if [ "$start" -eq 0 ] ; then
            qvm-start --skip-if-running "$vm" &> /dev/null || return 1
        else
            #we don't attempt to start
            return 2
        fi
    fi

    return 0
}

# qube.is_running returns 0 if the target qube is running (or paused), or 1 if not.
# $1 - VM name.
function qube.is_running ()
{
    qvm-check --running "$1" &>/dev/null
}

# qube.delete deletes a VM belonging to the identity, and removes its from the
# specified file. If this file is empty after this, it is deleted here.
# $1 - VM name.
# $2 - The file to search under ${IDENTITY_DIR}/ for deletion.
function qube.delete ()
{
    local vm="${1}"
    local file="${2}"

    if [[ -z "${vm}" ]]; then
        return
    fi

    # Attempt to delete: if fails, return without touching the specified file.
    _info "Deleting VM ${vm}"
    _run qvm-remove --force --verbose "${vm}"
    if [[ $? -gt 0 ]]; then
        return
    fi

    if [[ -z "${file}" ]]; then
        return
    fi

    # Delete the VM from the file
    sed -i "/${vm}/d" "${IDENTITY_DIR}/${file}"
    if [[ -z "$(cat "${IDENTITY_DIR}/${file}")" ]]; then
        rm "${IDENTITY_DIR}/${file}"
    fi
}


# ========================================================================================
#  Qubes dom0 general functions (not about a single qube)
# ========================================================================================
#

# qubes.updatevm_template returns the template of the updateVM.
function qubes.updatevm_template ()
{
    qvm-ls | grep "$(qubes-prefs updatevm)" | grep "TemplateVM" | awk '{print $1}'
}

# qubes.focused_qube returns the name of the VM owning the currently 
# active window. Returns 'dom0' if the focused window is a dom0 one.
function qubes.focused_qube ()
{
    local window_class parts vm
    window_class="$(xdotool getwindowclassname "$(xdotool getactivewindow)")"

    # No colon means dom0
    if [[ ${window_class} == *:* ]]; then
        parts=( ${(s[:])window_class} )
        print "${parts[1]}"
    else
        print "dom0"
    fi
}

# qubes.list_all returns an array of all VMs
function qubes.list_all ()
{
    local -a vms

    while IFS= read -r VM_NAME ; do
        vms+=("${VM_NAME}")
    done < <(qvm-ls --raw-list | sort)

    echo "${vms[@]}"
}

# qubes.list_all_updateable returns all templates and standalone VMs
function qubes.list_all_updateable ()
{
    local templates=()
    while read -r line ; do
        IFS="|" read -r name class <<< "${line}"
        if [[ "$class" == "TemplateVM" ]]; then
            templates+=( "$name" )
        elif [[ "$class" == "StandaloneVM" ]]; then
            templates+=( "$name" )
        fi
    done < <(qvm-ls --raw-data --fields name,class | sort)

    echo "${templates[@]}"
}

