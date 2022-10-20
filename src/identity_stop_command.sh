
# Else get the active identity
local active_identity
active_identity=$(_identity_active_or_specified)

_message "Stopping machines and identity $active_identity"

# First shut down all client VMs
read -ra client_vms "$(identity_client_vms)"
for vm in "${client_vms[@]}" ; do
    _message "Shutting down $vm"
    shutdown_vm "$vm"
done

# Do the same for proxyVMs
read -ra proxy_vms "$(identity_proxies)"
for vm in "${proxy_vms[@]}" ; do
    _message "Shutting down $vm"
    shutdown_vm "$vm"
done

_success "Done"
