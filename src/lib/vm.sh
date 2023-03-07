
# Returns the name of the identity to which a VM belongs.
get_vm_owner ()
{
    print "$(qvm-tags "$1" "$RISK_VM_OWNER_TAG" 2>/dev/null)"
}

# Enables a VM to autostart
enable_vm_autostart ()
{
    local name="$1"
    local autostart_vms=( "$(_identity_autostart_vms)" )

    # Check if the VM is already marked autostart
    for vm in "${autostart_vms[@]}" ; do
        if [[ $vm == "$name" ]]; then
            already_enabled=true
        fi
    done

    if [[ ! $already_enabled ]]; then
        _info "Enabling VM ${name} to autostart"
        echo "$name" >> "${IDENTITY_DIR}/autostart_vms"
    else
        _info "VM ${name} is already enabled"
    fi
}

# Disables a VM to autostart
disable_vm_autostart ()
{
    local name="$1"
    _info "Disabling VM $name"
    sed -i /"$name"/d "${IDENTITY_DIR}/autostart_vms"
}

#assertRunning [vm] [start]
#Assert that the given VM is running. Will unpause paused VMs and may start shut down VMs.
#[vm]: VM for which to make sure it's running.
#[start]: If it's not running and not paused, start it (default: 0/true). If set to 1, this function will return a non-zero exit code.
#returns: A non-zero exit code, if it's not running and/or we failed to start the VM.
assertRunning () 
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

# start_vm [vm 1] ... [vm n]
#Start the given VMs without executing any command.
start_vm () 
{
    local ret=0

    local vm=
    declare -A pids=() #VM --> pid
    for vm in "$@" ; do
        [[ "$vm" == "dom0" ]] && continue
        _verbose "Starting: $vm"
        assertRunning "$vm" &
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

# shutdown_vm [vm 1] ... [vm n]
#Shut the given VMs down.
shutdown_vm () 
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

# check_network_chain verifies that the NetVM of a given VM indeed belongs
# to the same owner, and does this recursively for each NetVM found in the chain.
check_network_chain ()
{
    local vm="$1"
    local netvm
    local owner

    _verbose "Checking network chain (starting from VM $vm)"

    # If there is not network VM, there is nothing to do
    netvm="$(qvm-prefs "$vm" netvm)"
    [[ -z "$netvm" ]] && return 0

    # This call recursively checks for all netVMs
    check_valid_netvm "$netvm"
}

# check_vm_owner verifies that the VM is owned by the current identity.
check_valid_netvm ()
{
    local vm="$1"
    local owner
    local tor_gw

    # Or if the owner is either non-existant or not the good one, we must fail.
    owner="$(get_vm_owner "$vm")"
    [[ -n "$owner" ]] || _failure "VM $vm has no RISKS owner. Aborting" 
    [[ "$owner" == "$IDENTITY" ]] || _failure "VM $vm does not belong to identity $IDENTITY"

    # If there is not network VM, there is nothing to do
    netvm="$(qvm-prefs "$vm" netvm)"
    [[ -z "$netvm" ]] && return 0

    # If the VM is the whonix gateway for the identity, we are done with the chain
    [[ "$vm" == "$(identity_tor_gw)" ]] && return 0

    # We also return if its the sys-firewall, which does not belong to any identity.
    [[ "$vm" == "$(config_get DEFAULT_NETVM)" ]] && return 0

    # Or check if the netVM is in one of the identity proxies, or if its the default VM
    is_proxy_vm "$netvm" || _failure "NetworkVM $vm is not listed as one of the identity's proxies"
    
    # Else, we go on with the netvm and do the same steps
    check_valid_netvm "$netvm"
}

# is_proxy_vm verifies that the identity's proxy VMs arrays contains a given VM.
is_proxy_vm ()
{
    local vm="$1"
    local match proxies

    match=1
    proxies=( $(_identity_proxies) )

    for proxy in "${proxies[@]}"; do
        if [[ $vm == "$proxy" ]]; then
            match=0
            break
        fi
    done

    return $match
}

# Returns an array of all VMs
all_vms ()
{
    local -a vms

    while IFS= read -r VM_NAME ; do
        vms+=("${VM_NAME}")
    done < <(qvm-ls --raw-list | sort)

    echo "${vms[@]}"
}

# check_not_netvm fails if the VM provides network to any other VM
check_not_netvm ()
{
    local vm="$1" 
    local vms connected_vms

    # If it does not provide network at all, don't go further.
    [[ $(qvm-prefs "$vm" provides_network) == "True" ]] || return 0

    # Check if it provides network to any VM, and if yes, fail.
    vms=( $(all_vms) )
    for svm in "${vms[@]}" ; do
        local netvm
        if [[ "$(qvm-prefs "$svm" netvm)" == "$vm" ]]; then
            connected_vms+=( "$svm" )
        fi
    done

    [[ ${#connected_vms} -gt 0 ]] && _failure "VM $vm is netVM for [ ${connected_vms[*]} ] VMs"
}

# get_updatable_vms returns all templates and standalone VMs
get_updatable_vms () 
{
    local templates=() 
    while read line ; do
        IFS="|" read -r name class <<< "${line}"
        if [[ "$class" == "TemplateVM" ]]; then
            templates+=( "$name" )
        elif [[ "$class" == "StandaloneVM" ]]; then
            templates+=( "$name" )
        fi
    done < <(qvm-ls --raw-data --fields name,class | sort)

    echo "${templates[@]}"
}

# Returns the template used by a given AppVM
get_update_vm_template ()
{
    qvm-ls | grep "$(qubes-prefs updatevm)" | grep "TemplateVM" | awk '{print $1}'
}

# get_vm_args returns a list of VMs that either explicitly named in the array 
# arguments, or those belonging to some "group keyword" of this same array.
get_vm_args ()
{
    local vms=("$@")
    local all_vms=()
    local can_update=()
    local updatevm

    # Return if our only argument is empty

    # All updatable VMs, except the updater one
    read -rA can_update <<< "$(get_updatable_vms)"
    updatevm="$(get_update_vm_template)"
    can_update=( ${can_update:#$~updatevm} )

    for word in "${vms[@]}"; do
        case "${word}" in
            # First check for group keywords
            all)
                all_vms+=( "${updatevm}" )
                all_vms+=( "${can_update[@]}" )
                ;;
            cacher)
                all_vms+=( "${updatevm}" )
                ;;
            torbrowser)
                ;;
            dom0)
                ;;
            # Else return the VM name itself
            *)
                for vm in "${can_update[@]}"; do
                    [[ "${vm}" =~ ${word} ]] && all_vms+=( "${vm}" )
                done
                ;;
        esac
        
    done

    echo "${all_vms[@]}"
}

# get_active_window_vm returns the name of the VM owning the currently active window.
get_active_window_vm ()
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

# select_bookmark prompts the user with bookmarks, 
# and returns the URL extracted from the selection.
select_bookmark ()
{
    local bookmarks_command result

    # bookmark_prompt=( $(bookmark_display_command) )
    bookmarks_command='export SB_CMD_INPUT=bookmark; touch $SB_CMD_INPUT; split-browser-bookmark get'
    qvm-run --pass-io "${vm}" "${bookmarks_command}"
    result="$(qvm-run --pass-io "${vm}" cat bookmark)" 
    print "$result" | awk '{print $2}'
}

# pop_bookmark prompts the user with bookmarks, returns the URL 
# extracted from the selection and deletes the line in the file.
# Returns the complete bookmark entry.
pop_bookmark ()
{
    local bookmarks_command result bookmark_line vm
    bookmark_file=".local/share/split-browser/bookmarks.tsv"
    vm="$(config_get SPLIT_BROWSER)"

    # Get the URL
    bookmarks_command='export SB_CMD_INPUT=bookmark; touch $SB_CMD_INPUT; split-browser-bookmark get'
    qvm-run --pass-io "${vm}" "${bookmarks_command}"
    result=$( qvm-run --pass-io "${vm}" cat bookmark | awk '{print $2}')
    qvm-run --pass-io "${vm}" "rm bookmark"

    # Get the entire line, with the title and timestamp.
    bookmark_line="$(qvm-run --pass-io "${vm}" "cat ${bookmark_file}")"
    line="$(echo "${bookmark_line}" | grep "${result}")"

    # Abort if the user did not select anything
    [[ -z "${result}" ]] && return

    # Remove the line from the file.
    remove_command="sed -i '\#${result}#d' .local/share/split-browser/bookmarks.tsv"
    qvm-run --pass-io "${vm}" "${remove_command}"

    print "${line}"
}

# get_browser_vm_from requires a VM name to be passed as argument.
# If this VM is a disposable based on the identity's browser VM,
# the argument is returned, otherwise the identity's browser VM.
get_browser_vm_from ()
{
    echo
}
