
# Else get the active identity
local active_identity
active_identity=$(identity.active_or_specified)

_info "Stopping machines of identity $active_identity"
identity.shutdown_qubes

_info "Closing identity in vault"
risk_identity_close_command
