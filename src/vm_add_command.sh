
local vm vm_owner

vm="${args['vm']}"

identity_set

# We need a valid identity
identity_check_exists "$IDENTITY"

# Check VM ownership
vm_owner=$(_vm_owner "$vm")

# If already belongs to an identity, ask for confirmation to update the settings.
if [[ -n "$vm_owner" ]] && [[ "$vm_owner" != "$IDENTITY" ]]; then
    _warning "VM $vm already belongs to $vm_owner"
    printf >&2 '%s ' "Do you really want to assign a new identity ($IDENTITY) to this VM ? (YES/n)"
    read ans

    if [[ "$ans" != 'YES' ]]; then
        _info "Aborting identity change. Exiting"
        exit 0
    fi
fi

# Tag the VM with its owner
_run qvm-tags "$vm" set "$IDENTITY"
_catch "Failed to tag VM with identity"

# Change its network VM, either with the default for the identity,
# or with the netvm flag, which has precedence.
if [[ "$(qvm-tags "$vm" netvm)" != 'None' ]]; then
    _info "VM is networked. Updating its network VM"
    local netvm="$(_identity_default_netvm)"

    # If the user overrode the default netVM, check that it belongs
    # to the identity, or ask confirmation.
    if [[ -n "${args['--netvm']}" ]]; then
        netvm_owner=$(_vm_owner "${args['--netvm']}")
        if [[ "$vm_owner" != "$IDENTITY" ]]; then
            _warning "Network VM $vm already belongs to $vm_owner"
            printf >&2 '%s ' "Do you really want to use this VM as netvm for $vm? (YES/n)"
            read ans

            if [[ "$ans" == 'YES' ]]; then
                netvm="${args['--netvm']}"
            fi
        fi
    fi

    _info "Setting network VM to $netvm"
    _run qvm-tags "$vm" netvm "$netvm"
    _catch "Failed to set netvm"
fi


# Check if the VM provides network. If yes we naturally consider
# it to be a gateway, and we add it to the list of proxy_vms.
if [[ "$(qvm-tags "$vm" provides_network)" == 'True' ]]; then
    _info "VM provides network. Treating it as a gateway VM"

    # Add as a proxy VM
    echo "$vm" > "${IDENTITY_DIR}/proxy_vms"

    # If the user specified to use it as the default netvm
    if [[ ${args['--set-default']} -eq 1 ]]; then
        echo "$vm" > "${IDENTITY_DIR}/net_vm"
        _info "Setting '$vm' as default NetVM for all client machines"
    fi
fi

# Enable autostart if asked to
[[ "${args['--enable']}" -eq 1 ]] && vm_enable_autostart "$vm"

_success "Succesfully set VM $vm as belonging to identity $IDENTITY"
