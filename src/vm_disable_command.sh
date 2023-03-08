local vm 

vm="${args['vm']}"

identity_set

# Check VM ownership 
[[ "$(_vm_owner "$vm")" != "$IDENTITY" ]] || _failure "VM $vm does not belong to $IDENTITY"

disable_vm_autostart "$vm"
