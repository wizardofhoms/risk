local vm

vm="${args['vm']}"

identity.set

# Check VM ownership
[[ "$(qube.owner "$vm")" != "$IDENTITY" ]] || _failure "VM $vm does not belong to $IDENTITY"

qube.enable "$vm"
