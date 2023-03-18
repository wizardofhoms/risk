
local sdcard_block

sdcard_block="$(config_get SDCARD_BLOCK)"

identity.set "${args['identity']}"

device.fail_not_attached_to "${sdcard_block}" "${VAULT_VM}"
identity.fail_none_active "$IDENTITY"

# Send commands to vault
_info "Opening identity $IDENTITY"
_run_qube_term "$VAULT_VM" risks identity open "$IDENTITY"
_catch "Failed to open identity"

# Set the identity browser VM, if any, as the disposable VM of split-browser backend.
_in_section "web"
web.browser_set_split_dispvm

_in_section "risk" && _info "Identity $IDENTITY is active"
