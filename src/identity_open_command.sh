
local sdcard_block="$(config_get SDCARD_BLOCK)"
local vault_vm="$(config_get VAULT_VM)"

_set_identity "${args[identity]}"

# 1 - Check that hush is mounted on vault
# TODO: change this, since it only checks for the default vault VM
check_is_device_attached "${sdcard_block}" "${vault_vm}"

# 2 - Check that no identity is currently opened
# The second line should be empty, as opposed to being an encrypted coffin name
check_no_active_identity "$IDENTITY"

# 3 - Send commands to vault
_message "Opening identity $IDENTITY"

_qrun "$vault_vm" risks open identity "$IDENTITY"
_catch "Failed to open identity"

_message "Identity $IDENTITY is active"
