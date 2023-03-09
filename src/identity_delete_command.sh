
local delete_vault_cmd

# First check the identity is valid
identity_set "${args['identity']}"
identity_check_exists

# Check access to hush device in vault
sdcard_block="$(config_get SDCARD_BLOCK)"
check_is_device_attached "${sdcard_block}" "${VAULT_VM}"

# Close the identity and all its running VMs
risk_identity_stop_command

_info "Deleting identity VMs"
vm_delete_identity

_info "Deleting identity in vault"
delete_vault_cmd=( risks identity delete "${IDENTITY}" )

# If a backup medium is mounted and backup 
# removal is asked, add the corresponding flags.
if device_backup_mounted_on "${VAULT_VM}"; then
    if [[ "${args['--backup']}" -eq 1 ]]; then
        delete_vault_cmd+=( --backup )
    fi
fi

_run_qubes_term "${VAULT_VM}" "${delete_vault_cmd[@]}"

# Finally, delete its dom0 directory.
identity_delete_directory

_success "Successfully deleted identity $IDENTITY"
