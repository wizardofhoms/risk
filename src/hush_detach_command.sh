
local block vm

block="${args['device']-$(config_get SDCARD_BLOCK)}"
vm="${args['vault_vm']-$(config_get VAULT_VM)}"

# First unmount the hush device in vault
_info "Unmounting hush device before detaching"
_qrun "$vm" risks hush umount
_catch "Failed to unmount hush device ($block)"

# detach the sdcard encrypted partition to the qube
if qvm-block detach "${vm}" "${block}" &>/dev/null ; then
	_success "Block ${block} has been detached from ${vm}"
else
	_failure "Block ${block} can not be detached from ${vm}"
fi

