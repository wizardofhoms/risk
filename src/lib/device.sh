
# device.fail_not_attached_to exits the program if a given block device
# (in QubesOS notation, ex. sys-usb:sda2) is not attached to a given VM.
# $1 - Device name
# $2 - Target qube VM
function device.fail_not_attached_to ()
{
    local block="$1"
    local vm="$2"
    local ovm

    ovm=$(qvm-block list | grep "${block}" | awk '{print $4}' | cut -d" " -f1)
    if [[ ${#ovm} -eq 0 ]] || [[ ${ovm} != "$vm" ]]; then
        _failure "Device block $block is not mounted on vault ${vm}"
    fi
}

# device.backup_mounted_on returns 0 if a backup is mounted in the target vault VM.
# $1 - Qube name (defaults to VAULT_VM)
function device.backup_mounted_on ()
{
    local vm="${1-$VAULT_VM}"
    local backup_status

    backup_status="$(qvm-run --pass-io "${vm}" 'risks backup status')"
    if [[ ${backup_status} =~ 'No backup device mounted' ]]; then
        return 1
    fi
}
