
# Else get the active identity
local active_identity
active_identity=$(_identity_active_or_specified)

_info "Stopping machines of identity $active_identity"
shutdown_identity_vms

_info "Closing identity in vault"
risk_identity_close_command

_success "Done"
