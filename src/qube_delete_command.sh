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
sed -i /"$vm"/d "${IDENTITY_DIR}/autostart_vms"

# Finally, delete the VM,
_run qvm-remove "$vm"
_catch "Failed to delete VM $vm:"
