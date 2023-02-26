local block vm

block="${args['device']:-$(config_get BACKUP_BLOCK)}"
vm="${args['vault_vm']-$(config_get VAULT_VM)}"

# Always umount first
_info "Locking/unmounting backup device before detaching"
_qrun "$vm" risks backup umount
_catch "Failed to unmount backup device ($block)"

# detach the backup device
if qvm-block detach "${vm}" "${block}" ; then
	_success "Block ${block} has been detached from to ${vm}"
else
	_failure "Block ${block} can not be detached from ${vm}"
fi

