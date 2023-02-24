local block vm

block="${args['device']:-$(config_get BACKUP_BLOCK)}"

# Always umount first
_qrun "$VAULT_VM" risks backup umount
_catch "Failed to unmount backup device ($block)"

# detach the backup device
qvm-block detach "${VAULT_VM}" "${block}"
if [[ $? -eq 0 ]]; then
	_success "Block ${block} has been detached from to ${VAULT_VM}"
else
	_success "Block ${block} can not be detached from ${VAULT_VM}"
fi

