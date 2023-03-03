
local sdcard_block vault_vm browser_vm

sdcard_block="$(config_get SDCARD_BLOCK)"
vault_vm="$(config_get VAULT_VM)"

_set_identity "${args['identity']}"

# 1 - Check that hush is mounted on vault
check_is_device_attached "${sdcard_block}" "${vault_vm}"

# 2 - Check that no identity is currently opened
# The second line should be empty, as opposed to being an encrypted coffin name
check_no_active_identity "$IDENTITY"

# 3 - Send commands to vault
_info "Opening identity $IDENTITY"
_qrun_term "$vault_vm" risks identity open "$IDENTITY"
_catch "Failed to open identity"

# Set the identity browser VM, if any, as the disposable VM of split-browser backend.
browser_vm=$(cat "${IDENTITY_DIR}/browser_vm" 2>/dev/null)
if [[ -n "${browser_vm}" ]]; then
    _info "Setting identity browser VM with split-browser"
    qvm-prefs "$(config_get SPLIT_BROWSER)" --set default_dispvm "${browser_vm}"
fi

_info "Identity $IDENTITY is active"
