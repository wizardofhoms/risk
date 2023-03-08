
## This file contains functions used for general network management and checks.
#


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
    _vm_is_identity_proxy "$netvm" || _failure "NetworkVM $vm is not listed as one of the identity's proxies"
    
    # Else, we go on with the netvm and do the same steps
    check_valid_netvm "$netvm"
}

# network_check_identity_chain verifies that the NetVM of a given VM indeed belongs
# to the same owner, and does this recursively for each NetVM found in the chain.
network_check_identity_chain ()
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

# fail_vm_provides_network fails if the VM provides network to any other VM
fail_vm_provides_network ()
{
    local vm="$1" 
    local vms connected_vms

    # If it does not provide network at all, don't go further.
    [[ $(qvm-prefs "$vm" provides_network) == "True" ]] || return 0

    # Check if it provides network to any VM, and if yes, fail.
    vms=( $(_vm_list) )
    for svm in "${vms[@]}" ; do
        local netvm
        if [[ "$(qvm-prefs "$svm" netvm)" == "$vm" ]]; then
            connected_vms+=( "$svm" )
        fi
    done

    [[ ${#connected_vms} -gt 0 ]] && _failure "VM $vm is netVM for [ ${connected_vms[*]} ] VMs"
}

