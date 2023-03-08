local vm

vm="${args['vm']}"

identity_set

# Check VM ownership 
[[ "$(_vm_owner "$vm")" != "$IDENTITY" ]] || _failure "VM $vm does not belong to $IDENTITY"

# Do not even attempt to delete if the VM provides network to another VM.
check_not_netvm "$vm"

# If the VM is a gateway, just call the VPN command to do the work.
if is_proxy_vm "$vm" ; then
    risk_vpn_delete_command
    return
fi

# Remove from autostart enabled commands
sed -i /"$vm"/d "${IDENTITY_DIR}/autostart_vms"

# Finally, delete the VM, 
_run qvm-remove "$vm"
_catch "Failed to delete VM $vm:"
