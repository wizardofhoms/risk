
local sdcard_block

sdcard_block="$(config_get SDCARD_BLOCK)"

identity.set "${args['identity']}"

# 1 - Check that hush is mounted on vault
device.fail_not_attached_to "${sdcard_block}" "${VAULT_VM}"

# 2 - Check that no identity is currently opened
# The second line should be empty, as opposed to being an encrypted coffin name
identity.fail_none_active "$IDENTITY"

# 3 - Send commands to vault
_info "Opening identity $IDENTITY"
_run_qube_term "$VAULT_VM" risks identity open "$IDENTITY"
_catch "Failed to open identity"

# Set the identity browser VM, if any, as the disposable VM of split-browser backend.
web_set_identity_split_browser

_info "Identity $IDENTITY is active"
