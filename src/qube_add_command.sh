
local vm owner               # Variables for the target VM
local netvm netvm_owner      # Variables for any netvm found/used.
local chown chnet            # Questions variable (ex. do you want to blablabla)

vm="${args['vm']}"

identity.set
identity.fail_unknown "$IDENTITY"

# Check VM ownership
owner=$(qube.owner "$vm")

# If already belongs to an identity, ask for confirmation to update the settings.
if [[ -n "$owner" ]] && [[ "$owner" != "$IDENTITY" ]]; then
    _warning "VM $vm already belongs to $owner"
    chown=$(prompt_question "Do you really want to assign a new identity ($IDENTITY) to this VM ? (YES/n)")
    if [[ "$chown" != 'YES' ]]; then
        _info "Aborting qube owner change. Exiting"
        exit 0
    fi
fi

# Tag the VM with its owner
_run qvm-tags "$vm" set "$IDENTITY"
_catch "Failed to tag VM with identity"

# If the target qube is networked, change its network VM, either with 
# the default for the identity, or with the netvm flag, which has precedence.
if [[ "$(qvm-tags "$vm" netvm)" != 'None' ]]; then
    _info "Qube is networked. Updating its network VM"
    netvm="$(identity.netvm)"

    # If the user overrode the default netVM, check that
    # it belongs to the identity, or ask confirmation.
    if [[ -n "${args['--netvm']}" ]]; then
        netvm="${args['--netvm']}"
        netvm_owner=$(qube.owner "${netvm}")

        if [[ -n "${netvm_owner}" ]] && [[ "$netvm_owner" != "$IDENTITY" ]]; then
            _warning "Network VM $netvm already belongs to $netvm_owner"
            chnet=$(prompt_question "Do you really want to use this VM as netvm for $netvm? (YES/n)")
            if [[ "$chnet" != 'YES' ]]; then
                netvm="$(identity.netvm)"
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
    if [[ ${args['--default-netvm']} -eq 1 ]]; then
        echo "$vm" > "${IDENTITY_DIR}/net_vm"
        _info "Setting '$vm' as default NetVM for all client machines"
    fi
fi

# Enable autostart if asked to
[[ "${args['--enable']}" -eq 1 ]] && qube.enable "$vm"

_success "Successfully set VM $vm as belonging to identity $IDENTITY"
