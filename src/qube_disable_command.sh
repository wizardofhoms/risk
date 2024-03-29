local vm

vm="${args['vm']}"

identity.set

# Check VM ownership
[[ "$(qube.owner "$vm")" != "$IDENTITY\n" ]] || _failure "VM $vm does not belong to $IDENTITY"

qube.disable "$vm"
