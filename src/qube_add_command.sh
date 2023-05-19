
local vm owner               # Variables for the target VM
local netvm netvm_owner      # Variables for any netvm found/used.
local chown chnet            # Questions variable (ex. do you want to blablabla)

vm="${args['vm']}"

identity.set
identity.fail_unknown "$IDENTITY"

# Check VM ownership
owner=$(qube.owner "$vm")

# Check if the VM provides network. If yes we naturally consider
# it to be a gateway, and we add it to the list of proxy_vms.
if [[ "$(qvm-prefs "$vm" provides_network)" == 'True' ]]; then
    _info "VM '${vm}' provides network: treating it as a gateway qube."
    args['--set-default']=${args['--default-netvm']}
    risk_vpn_add_command
    return $?
fi

# If already belongs to an identity, ask for confirmation to update the settings.
if [[ -n "$owner" ]] && [[ "$owner" != "$IDENTITY" ]]; then
    _warning "VM $vm already belongs to $owner"
    chown=$(prompt_question "Do you really want to assign a new identity ($IDENTITY) to this qube ? (YES/n)")
    if [[ "$chown" != 'YES' ]]; then
        _info "Aborting qube owner change. Exiting"
        exit 0
    fi
fi

# Tag the VM with its owner
_run qvm-tags "$vm" set "$IDENTITY"
_catch "Failed to tag qube with identity"

# If the target qube is networked, change its network VM, either with
# the default for the identity, or with the netvm flag, which has precedence.
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

identity.config_append CLIENT_QUBES "${vm}"

# Enable autostart if asked to
[[ "${args['--enable']}" -eq 1 ]] && qube.enable "$vm"

_success "Successfully set qube $vm as belonging to identity $IDENTITY"
