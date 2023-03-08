
# Refactors:
# _vm_owner > _vm_owner
# enable_vm_autostart > vm_enable_autostart
# disable_vm_autostart > vm_disable_autostart
# assertRunning > vm_asset_running
# start_vm > vm_start
# shutdown_vm > vm_shutdown
# shutdown_identity_vms > vm_shutdown_identity
# delete_identity_vms > vm_delete_identity
# delete_vm > vm_delete
# is_proxy_vm > vm_is_proxy
# all_vms > _vm_list_all
# get_updatable_vms > _vm_list_updatable
# get_update_vm_template > _vm_template
# get_vm_args > _vm_args
# get_active_window_vm > _vm_focus

# Returns the name of the identity to which a VM belongs.
_vm_owner ()
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
    owner="$(_vm_owner "$vm")"
    [[ -n "$owner" ]] || _failure "VM $vm has no RISKS owner. Aborting" 
    [[ "$owner" == "$IDENTITY" ]] || _failure "VM $vm does not belong to identity $IDENTITY"

    # If there is not network VM, there is nothing to do
    netvm="$(qvm-prefs "$vm" netvm)"
    [[ -z "$netvm" ]] && return 0

    # If the VM is the whonix gateway for the identity, we are done with the chain
    [[ "$vm" == "$(_identity_tor_gateway)" ]] && return 0

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

# shutdown_identity_vms powers off all running VMs belonging to the identity.
shutdown_identity_vms ()
{
    local clients proxies tor_gateway browser_vm net_vm other_vms

    # Client VMs
    read -rA clients < <(_identity_client_vms)
    for vm in "${clients[@]}" ; do
        if [[ -z "${vm}" ]]; then
            continue
        fi
        _info "Shutting down $vm"
        shutdown_vm "$vm"
    done

    # Browser VMs (disposables to find from template/tag)
    browser_vm="$(_identity_browser_vm)"
    if [[ -n "${browser_vm}" ]]; then
        _info "Shutting down $browser_vm"
        shutdown_vm "$browser_vm"
    fi

    # Proxy VMs
    read -rA proxies < <(_identity_client_vms)
    for vm in "${proxies[@]}" ; do
        if [[ -z "${vm}" ]]; then
            continue
        fi
        _info "Shutting down $vm"
        shutdown_vm "$vm"
    done

    # Tor gateway.
    tor_gateway="$(_identity_tor_gateway)"
    if [[ -n "${tor_gateway}" ]]; then
        _info "Shutting down $tor_gateway"
        shutdown_vm "$tor_gateway"
    fi

    # Other VMs that are tagged with the identity.
    read -rA other_vms < <(all_vms)
    for vm in "${other_vms[@]}" ; do
        if [[ -z "${vm}" ]]; then
            continue
        fi

        if [[ "$(_vm_owner "${vm}")" == "${IDENTITY}" ]]; then
            _info "Shutting down $vm"
            shutdown_vm "$vm"
        fi
    done
}

# delete_identity_vms deletes all VMs belonging to an identity.
delete_identity_vms ()
{
    local clients proxies tor_gateway browser_vm net_vm other_vms

    # Client VMs
    read -rA clients < <(_identity_client_vms)
    for client in "${clients[@]}"; do
        delete_vm "${client}" "client_vms"
    done

    # Browser VM
    browser_vm="$(_identity_browser_vm)"
    if [[ -n "${browser_vm}" ]]; then
        delete_vm "${browser_vm}" "browser_vm"
    fi
    
    # Proxy VMs
    read -rA proxies < <(_identity_client_vms)
    for proxy in "${proxies[@]}"; do
        delete_vm "${proxy}" "proxy_vms"
    done

    # Tor gateway.
    tor_gateway="$(_identity_tor_gateway)"
    if [[ -n "${tor_gateway}" ]]; then
        delete_vm "${tor_gateway}" "tor_gw"
    fi

    # Net VM
    
    # Other VMs that are tagged with the identity.
    read -rA other_vms < <(all_vms)
    for vm in "${other_vms[@]}"; do
        if [[ "$(_vm_owner "${vm}")" == "${IDENTITY}" ]]; then
            delete_vm "${vm}"
        fi
    done
}

# delete_vm deletes a VM belonging to the identity, and removes its from the 
# specified file. If this file is empty after this, it is deleted here.
# $1 - VM name.
# $2 - The file to search under ${IDENTITY_DIR}/ for deletion.
delete_vm ()
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
