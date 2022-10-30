
local name

name="${args[vm]}"

_set_identity 

# Check that the selected VM is indeed one of the identity
# proxy VMs, so that we don't accidentally delete another one.
check_vm_is_proxy "$name"

# Do not even attempt to delete if the VM provides network to another VM.
check_not_netvm "$vm"

_message "Deleting gateway VM $name"

# If the VPN was the default NetVM for the identity,
# update the NetVM to Whonix.
netvm="$(identity_default_netvm)"
if [[ $netvm == "$name" ]]; then
    _warning "Gateway $name is the default NetVM for identity clients !"

    # Check if we have a TOR gateway
    local tor_gw=$(identity_tor_gw)

    if [[ -n $tor_gw ]]; then
        _message -n "Updating the default identity NetVM to $tor_gw"
        echo "$tor_gw" > "${IDENTITY_DIR}/net_vm" 
    else
        _message -n "The identity has no default NetVM anymore, please set it."
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

_message "Deleted $name"
