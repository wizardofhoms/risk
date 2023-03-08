
local name="${args['vm']}"

_info "Starting gateway $name in the background"

# First check all the network VMs that will be started
# actually belong to the identity, otherwise we fail.
network_check_identity_chain "$name"

# Then start the VM, which will start all dependent ones.
vm_start "$name"
_catch "Failed to start $name"

_info "Started VM $name"
