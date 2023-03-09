
# Checks that a given device is attached to a given VM
check_is_device_attached ()
{
    local block="$1"
    local vm="$2"

    local ovm=$(qvm-block list | grep "${block}" | awk {'print $4'} | cut -d" " -f1)
    if [[ ${#ovm} -eq 0 ]] || [[ ${ovm} != "$vm" ]]; then
        _failure "Device block $block is not mounted on vault ${vm}"
    fi
}

# device_backup_mounted_on returns 0 if a backup is mounted in the target vault VM.
device_backup_mounted_on ()
{
    local vm="${1-$VAULT_VM}"
    local backup_status

    backup_status="$(qvm-run --pass-io "${vm}" 'risks backup status')"
    if [[ ${backup_status} =~ 'No backup device mounted' ]]; then
        return 1
    fi
}
