
local block vm
local error_invalid_vm error_device
local must_mount

vm="${args['vault_vm']-$(config_get VAULT_VM)}"
block="${args['device']-$(config_get SDCARD_BLOCK)}"
device="$(device.get_block "${block}")"

# If the validations were not performed because
# we use a default environment variable for the
# vault VM, perform them again here.
error_invalid_vm=$(validate_valid_vaultvm "$vm")
if [[ -n "$error_invalid_vm" ]]; then
    _failure "$error_invalid_vm"
fi

# Do the same for the hush device
error_device=$(validate_device "$block")
if [[ -n "$error_device" ]]; then
    _failure "$error_device"
fi

# is the vm running?
qvm-ls | grep Running | awk {'print $1'} | grep '^'"${vm}"'$' &> /dev/null
if [ "$?" != "0" ]; then
    _verbose "Starting VM $vm"
    qvm-start "${vm}"
	sleep 5
fi

# finally attach the sdcard encrypted partition to the qube
qvm-block attach "${vm}" "${device}"
if [[ $? -eq 0 ]]; then
	_success "Block ${device} has been attached to ${vm}"
else
	_failure "Block ${device} can not be attached to ${vm}"
fi

# If user wants to mount it now, do it
if [[ ${args['--mount']} -eq 1 ]]; then
    must_mount=1
elif [[ "$(config_get AUTO_MOUNT_HUSH)" == True ]]; then
    must_mount=1
elif [[ "$(config_get AUTO_MOUNT_HUSH)" == true ]]; then
    must_mount=1
elif [[ "$(config_get AUTO_MOUNT_HUSH)" == yes ]]; then
    must_mount=1
elif [[ "$(config_get AUTO_MOUNT_HUSH)" == 1 ]]; then
    must_mount=1
fi

if [[ "${must_mount}" -eq 1 ]]; then
    _info "Mounting hush device"
    _run_qube_term "$vm" risks hush mount
fi
