
local active_identity

identity.set

# Check we have an active identity
active_identity="$(identity.active)"
if [[ -z $active_identity ]]; then
    _info "No active identity to close"
    return
fi

# If the identity browser VM is used with the split-browser backend.
_in_section "web" 4
web.backend.unset_client

_in_section "risk" && _info "Closing identity $active_identity"

_run_qube_term "${VAULT_VM}" risks identity close "$active_identity"
_catch "Failed to close identity $active_identity"

_info "Identity $active_identity is closed"
