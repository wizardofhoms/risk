
local block vm

block="${args['device']-$(config_get BACKUP_BLOCK)}"
vm="${args['vault_vm']-$(config_get VAULT_VM)}"

local error_invalid_vm error_device

# If the validations were not performed because
# we use a default environment variable for the
# vault VM, perform them again here.
error_invalid_vm=$(validate_vm_exists "$vm")
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
	sleep 15
fi

# finally attach the sdcard encrypted partition to the qube
qvm-block attach "${vm}" "${block}"
if [[ $? -eq 0 ]]; then
	_success "Block ${block} has been attached to ${vm}"
else
	_success "Block ${block} can not be attached to ${vm}"
fi

