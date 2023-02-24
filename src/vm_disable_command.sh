local vm 

vm="${args['vm']}"

_set_identity

# Check VM ownership 
[[ "$(get_vm_owner "$vm")" != "$IDENTITY" ]] || _failure "VM $vm does not belong to $IDENTITY"

disable_vm_autostart "$vm"
