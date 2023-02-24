
local name="${args['vm']}"

_info "Shutting down gateway $name"
shutdown_vm "$name"
_catch "Failed to shutdown $name"
_info "Shut down $name"
