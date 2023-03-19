local vm

vm="${args['vm']}"

identity.set

# Check VM ownership
[[ "$(qube.owner "$vm")" != "$IDENTITY" ]] || _failure "VM $vm does not belong to $IDENTITY"

# If already enabled, skip
if grep "^${vm}\$" < <(cat "${IDENTITY_DIR}"/autostart_vms) &>/dev/null; then
    _info "Qube ${vm} is already enabled for autostart"
    return
fi

qube.enable "$vm"
