
device.fail_not_attached_to "$(config_get SDCARD_BLOCK)" "${VAULT_VM}"

identity.set "${args['identity']}"
identity.fail_other_active

# Send commands to vault
_info "Opening identity $IDENTITY"
_run_qube_term "$VAULT_VM" risks identity open "$IDENTITY"
identity.is_active || _failure "Failed to open identity $IDENTITY"

# Set the identity browser VM, if any, as the disposable VM of split-browser backend.
_in_section "web"
web.browser_set_split_dispvm

_in_section "risk" && _info "Identity $IDENTITY is active"
