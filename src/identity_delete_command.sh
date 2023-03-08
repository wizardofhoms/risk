
# First check the identity is valid
identity_set "${args['identity']}"
identity_check_exists

# Check access to hush device in vault
sdcard_block="$(config_get SDCARD_BLOCK)"
check_is_device_attached "${sdcard_block}" "${VAULT_VM}"

# Close the identity and all its running VMs
risk_identity_stop_command

# Delete all VMs belonging to the identity.
_info "Deleting identity VMs"
delete_identity_vms

# Delete the identity data in the vault

# And delete the identity directory in dom0.

_success "Successfully deleted identity $IDENTITY"
