
local vm
local tor_gw

vm="${args['vm']}"

identity.set

# Fail if either the VM does not belong to the identity,
# or if it provides network to some of the identity qubes.
proxy.fail_not_identity_proxy "$vm"
network.fail_networked_qube "$vm"

_info "Deleting gateway VM $vm"

# If the VPN was the default NetVM for the identity,
# update the NetVM to Whonix.
netvm="$(identity.netvm)"
if [[ $netvm == "$vm" ]]; then
    _warning "Gateway $vm is the default NetVM for identity clients !"

    # Check if we have a TOR gateway
    tor_gw=$(identity.tor_gateway)
    if [[ -n $tor_gw ]]; then
        _info "Updating the default identity NetVM to $tor_gw"
        identity.config_set TOR_QUBE "${tor_gw}"
    else
        _info "The identity has no default NetVM anymore, please set it."
    fi
fi

# Delete without asking to confirm
echo "y" | _run qvm-remove "$vm"
_catch "Failed to delete (fully or partially) VM $vm"

# Remove this VM name from the relevant files.
identity.config_reduce AUTOSTART_QUBES "${vm}"
identity.config_reduce PROXY_QUBES "${vm}"

_info "Deleted $vm"
