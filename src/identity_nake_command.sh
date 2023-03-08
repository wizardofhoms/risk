
# First check the identity is valid
identity_set "${args['identity']}"
identity_check_exists

# Close the identity and all its running VMs
_info "Stopping machines of identity $IDENTITY"
shutdown_identity_vms

# If the identity browser VM is used with the split-browser backend.
web_unset_identity_split_browser

_info "Deleting identity VMs"
delete_identity_vms

_success "Successfully deleted VMs of identity $IDENTITY"
