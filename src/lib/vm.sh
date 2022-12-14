
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
        _message "Enabling VM ${name} to autostart"
        echo "$name" >> "${IDENTITY_DIR}/autostart_vms"
    else
        _message "VM ${name} is already enabled"
    fi
}

# Disables a VM to autostart
disable_vm_autostart ()
{
    local name="$1"
    _message "Disabling VM $name"
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
