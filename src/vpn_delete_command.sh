
local name

name="${args['vm']}"

identity.set

# Check that the selected VM is indeed one of the identity
# proxy VMs, so that we don't accidentally delete another one.
vpn_check_qube.is_identity_proxy "$name"

# Do not even attempt to delete if the VM provides network to another VM.
network.fail_networked_qube "$vm"

_info "Deleting gateway VM $name"

# If the VPN was the default NetVM for the identity,
# update the NetVM to Whonix.
netvm="$(identity.netvm)"
if [[ $netvm == "$name" ]]; then
    _warning "Gateway $name is the default NetVM for identity clients !"

    # Check if we have a TOR gateway
    local tor_gw=$(identity.tor_gateway)

    if [[ -n $tor_gw ]]; then
        _info -n "Updating the default identity NetVM to $tor_gw"
        echo "$tor_gw" > "${IDENTITY_DIR}/net_vm"
    else
        _info -n "The identity has no default NetVM anymore, please set it."
    fi
fi

# Check if there are some existing VMs that use this gateway as NetVM,
# and change their netVM to None: this is unpractical, especially for
# those that might be up, but it's better than assigning a new netVM
# despite this presenting a security risk.

# Delete without asking to confirm
echo "y" | _run qvm-remove "$name"
_catch "Failed to delete (fully or partially) VM $name"

# Remove from VMs marked autostart
sed -i /"$name"/d "${IDENTITY_DIR}/autostart_vms"
# And remove from proxy VMs
sed -i /"$name"/d "${IDENTITY_DIR}/proxy_vms"

# Finally, delete the VM,
_run qvm-remove "$name"
_catch "Failed to delete VM $name:"

_info "Deleted $name"
