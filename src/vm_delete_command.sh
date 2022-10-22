local vm 

vm="${args[vm]}"

_set_identity

# Check VM ownership 
[[ "$(get_vm_owner "$vm")" != "$IDENTITY" ]] || _failure "VM $vm does not belong to $IDENTITY"

# Check if the VM is the default NetVM for identity

# Check if it provides network to any VM, and if yes, fail.

# Check if the VM is among netVMs, which is true if it provides network.
