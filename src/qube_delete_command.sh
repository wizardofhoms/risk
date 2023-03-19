local vm

vm="${args['vm']}"

identity.set
identity.fail_unknown "$IDENTITY"

# Check VM ownership
if [[ "$(qube.owner "$vm")" != "$IDENTITY" ]]; then
    _info "VM $vm does not belong to $IDENTITY"
    return
fi

# Do not even attempt to delete if the VM provides network to another VM.
network.fail_networked_qube "$vm"

# If the VM is a gateway, just call the VPN command to do the work.
if qube.is_identity_proxy "$vm" ; then
    risk_vpn_delete_command
    return
fi

# Remove from autostart enabled commands
_info "Deleting qube ${vm}"
sed -i /^"$vm"\$/d "${IDENTITY_DIR}/autostart_vms" 2>/dev/null
sed -i /^"$vm"\$/d "${IDENTITY_DIR}/proxy_vms" 2>/dev/null
sed -i /^"$vm"\$/d "${IDENTITY_DIR}/client_vms" 2>/dev/null

# Finally, delete the VM,
qvm-remove "$vm"
_catch "Failed to delete VM $vm:"

_info "Deleted qube ${vm}"
