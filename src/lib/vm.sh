
#
# // Attributes functions //
#
# Functions starting with an underscore 
# give information and values related to VMs, 
#

# Returns the name of the identity to which a VM belongs.
_vm_owner ()
{
    print "$(qvm-tags "$1" "$RISK_VM_OWNER_TAG" 2>/dev/null)"
}

# Returns the template used by a given AppVM
_vm_template ()
{
    qvm-ls | grep "$(qubes-prefs updatevm)" | grep "TemplateVM" | awk '{print $1}'
}

# _vm_focused returns the name of the VM owning the currently active window.
_vm_focused ()
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

# Returns an array of all VMs
_vm_list ()
{
    local -a vms

    while IFS= read -r VM_NAME ; do
        vms+=("${VM_NAME}")
    done < <(qvm-ls --raw-list | sort)

    echo "${vms[@]}"
}

# _vm_list_updatable returns all templates and standalone VMs
_vm_list_updatable () 
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

# _vm_args returns a list of VMs that are either explicitly named 
# in the array passed as arguments, or those belonging to some 
# "group keyword" of this same array.
_vm_args ()
{
    local vms=("$@")
    local _vm_list=()
    local can_update=()
    local updatevm

    # Return if our only argument is empty

    # All updatable VMs, except the updater one
    read -rA can_update <<< "$(_vm_list_updatable)"
    updatevm="$(_vm_template)"
    can_update=( ${can_update:#$~updatevm} )

    for word in "${vms[@]}"; do
        case "${word}" in
            # First check for group keywords
            all)
                _vm_list+=( "${updatevm}" )
                _vm_list+=( "${can_update[@]}" )
                ;;
            cacher)
                _vm_list+=( "${updatevm}" )
                ;;
            torbrowser)
                ;;
            dom0)
                ;;
            # Else return the VM name itself
            *)
                for vm in "${can_update[@]}"; do
                    [[ "${vm}" =~ ${word} ]] && _vm_list+=( "${vm}" )
                done
                ;;
        esac
        
    done

    echo "${_vm_list[@]}"
}

# _vm_is_identity_proxy verifies that the identity's proxy VMs arrays contains a given VM.
_vm_is_identity_proxy ()
{
    local vm="$1"
    local match proxies

    match=1
    read -rA proxies < <(_identity_proxies)

    for proxy in "${proxies[@]}"; do
        if [[ $vm == "$proxy" ]]; then
            match=0
            break
        fi
    done

    return $match
}

#
# // VM control and settings management //
# 

# Enables a VM to autostart
vm_enable_autostart ()
{
    local name="$1"
    local autovm_starts=( "$(_identity_autovm_starts)" )

    # Check if the VM is already marked autostart
    for vm in "${autovm_starts[@]}" ; do
        if [[ $vm == "$name" ]]; then
            already_enabled=true
        fi
    done

    if [[ ! $already_enabled ]]; then
        _info "Enabling VM ${name} to autostart"
        echo "$name" >> "${IDENTITY_DIR}/autovm_starts"
    else
        _info "VM ${name} is already enabled"
    fi
}

# Disables a VM to autostart
vm_disable_autostart ()
{
    local name="$1"
    _info "Disabling VM $name"
    sed -i /"$name"/d "${IDENTITY_DIR}/autovm_starts"
}

# vm_start [vm 1] ... [vm n]
#Start the given VMs without executing any command.
vm_start () 
{
    local ret=0

    local vm=
    declare -A pids=() #VM --> pid
    for vm in "$@" ; do
        [[ "$vm" == "dom0" ]] && continue
        _verbose "Starting: $vm"
        vm_assert_running "$vm" &
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

# vm_shutdown [vm 1] ... [vm n]
#Shut the given VMs down.
vm_shutdown () 
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

#vm_assert_running [vm] [start]
#Assert that the given VM is running. Will unpause paused VMs and may start shut down VMs.
#[vm]: VM for which to make sure it's running.
#[start]: If it's not running and not paused, start it (default: 0/true). If set to 1, this function will return a non-zero exit code.
#returns: A non-zero exit code, if it's not running and/or we failed to start the VM.
vm_assert_running () 
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

# vm_delete deletes a VM belonging to the identity, and removes its from the 
# specified file. If this file is empty after this, it is deleted here.
# $1 - VM name.
# $2 - The file to search under ${IDENTITY_DIR}/ for deletion.
vm_delete ()
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

# vm_shutdown_identity powers off all running VMs belonging to the identity.
vm_shutdown_identity ()
{
    local clients proxies tor_gateway browser_vm net_vm other_vms

    # Client VMs
    read -rA clients < <(_identity_client_vms)
    for vm in "${clients[@]}" ; do
        if [[ -z "${vm}" ]]; then
            continue
        fi
        _info "Shutting down $vm"
        vm_shutdown "$vm"
    done

    # Browser VMs (disposables to find from template/tag)
    browser_vm="$(_identity_browser_vm)"
    if [[ -n "${browser_vm}" ]]; then
        _info "Shutting down $browser_vm"
        vm_shutdown "$browser_vm"
    fi

    # Proxy VMs
    read -rA proxies < <(_identity_client_vms)
    for vm in "${proxies[@]}" ; do
        if [[ -z "${vm}" ]]; then
            continue
        fi
        _info "Shutting down $vm"
        vm_shutdown "$vm"
    done

    # Tor gateway.
    tor_gateway="$(_identity_tor_gateway)"
    if [[ -n "${tor_gateway}" ]]; then
        _info "Shutting down $tor_gateway"
        vm_shutdown "$tor_gateway"
    fi

    # Other VMs that are tagged with the identity.
    read -rA other_vms < <(_vm_list)
    for vm in "${other_vms[@]}" ; do
        if [[ -z "${vm}" ]]; then
            continue
        fi

        if [[ "$(_vm_owner "${vm}")" == "${IDENTITY}" ]]; then
            _info "Shutting down $vm"
            vm_shutdown "$vm"
        fi
    done
}

# vm_delete_identity deletes all VMs belonging to an identity.
vm_delete_identity ()
{
    local clients proxies tor_gateway browser_vm net_vm other_vms

    # Client VMs
    read -rA clients < <(_identity_client_vms)
    for client in "${clients[@]}"; do
        vm_delete "${client}" "client_vms"
    done

    # Browser VM
    browser_vm="$(_identity_browser_vm)"
    if [[ -n "${browser_vm}" ]]; then
        vm_delete "${browser_vm}" "browser_vm"
    fi
    
    # Proxy VMs
    read -rA proxies < <(_identity_client_vms)
    for proxy in "${proxies[@]}"; do
        vm_delete "${proxy}" "proxy_vms"
    done

    # Tor gateway.
    tor_gateway="$(_identity_tor_gateway)"
    if [[ -n "${tor_gateway}" ]]; then
        vm_delete "${tor_gateway}" "tor_gw"
    fi

    # Net VM
    
    # Other VMs that are tagged with the identity.
    read -rA other_vms < <(_vm_list)
    for vm in "${other_vms[@]}"; do
        if [[ "$(_vm_owner "${vm}")" == "${IDENTITY}" ]]; then
            vm_delete "${vm}"
        fi
    done
}

