
# Prepare some settings for this new VM
local vm netvm

identity.set

vm="${args['vm']}"

# Check VM ownership
owner=$(qube.owner "$vm")

# If already belongs to an identity, ask for confirmation to update the settings.
if [[ -n "$owner" ]] && [[ "$owner" != "$IDENTITY" ]]; then
    _warning "VM $vm already belongs to $owner"
    chown=$(prompt_question "Do you really want to assign a new identity ($IDENTITY) to this qube ? (YES/n)")
    if [[ "$chown" != 'YES' ]]; then
        _info "Aborting qube owner change. Exiting"
        exit 0
    fi
fi

# Tag the VM with its owner, and mark as providing network.
_run qvm-tags "$vm" set "$IDENTITY"
_catch "Failed to tag qube with identity"

# Network
if [[ "$(qvm-prefs "$vm" netvm)" != 'None' ]]; then
    _info "Qube is networked. Updating its network VM"
    netvm="$(identity.netvm)"

    # If the user overrode the default netVM, check that
    # it belongs to the identity, or ask confirmation.
    if [[ -n "${args['--netvm']}" ]]; then
        netvm="${args['--netvm']}"
        netvm_owner=$(qube.owner "${netvm}")

        if [[ -n "${netvm_owner}" ]] && [[ "$netvm_owner" != "$IDENTITY" ]]; then
            _warning "Network VM $netvm already belongs to $netvm_owner"
            chnet=$(prompt_question "Do you really want to use this qube as network VM for $vm? (YES/n)")
            if [[ "$chnet" != 'YES' ]]; then
                netvm="$(identity.netvm)"
            fi
        fi
    fi

    _info "Setting network VM to $netvm"
    _run qvm-prefs "$vm" netvm "$netvm"
    _catch "Failed to set netvm"
fi

_run qvm-prefs "$vm" provides_network True

if [[ ${args['--set-default']} -eq 1 ]]; then
    identity.config_set NETVM_QUBE "${vm}"
    _info "Setting '$vm' as default NetVM for all future client qubes"
fi

# Enable autostart if asked to
[[ "${args['--enable']}" -eq 1 ]] && qube.enable "$vm"

_success "Successfully add $vm as identity gateway"
