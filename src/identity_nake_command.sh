
# First check the identity is valid
identity.set "${args['identity']}"
identity.fail_unknown

# Close the identity and all its running VMs
_info "Stopping machines of identity $IDENTITY"
identity.shutdown_qubes

# If the identity browser VM is used with the split-browser backend.
web.browser_unset_split_dispvm

_info "Deleting identity VMs"
identity.delete_qubes

_success "Successfully deleted VMs of identity $IDENTITY"
