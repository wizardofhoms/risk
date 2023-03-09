
# If no active identity to slam, nothing to do except umounting the hush device
if ! _identity_active ; then
    _info "No active identity, only detaching hush and backup devices"
    risk_hush_detach_command
    risk_backup_detach_command
    exit 0
fi

# Else get the active identity, and propagate values to the script
local active_identity
active_identity=$(_identity_active_or_specified)
identity_set "$active_identity"

_info "Slamming infrastructure, vault and devices: identity $active_identity"

# First shut down all client VMs
read -rA client_vms < <(identity_client_vms)
for vm in "${client_vms[@]}" ; do
    _info "Shutting down $vm"
    vm_shutdown "$vm"
done

# Do the same for proxyVMs
read -rA proxy_vms < <(identity_proxies)
for vm in "${proxy_vms[@]}" ; do
    _info "Shutting down $vm"
    vm_shutdown "$vm"
done

# Close the identity in the vault, unmount hush and backup
risk_identity_close_command
risk_hush_detach_command
risk_backup_detach_command

_success "Done"
