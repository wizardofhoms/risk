
# Else get the active identity
local active_identity
active_identity=$(_identity_active_or_specified)

_info "Stopping machines of identity $active_identity"
vm_shutdown_identity

_info "Closing identity in vault"
risk_identity_close_command
