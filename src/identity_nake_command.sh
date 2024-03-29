
# First check the identity is valid
identity.set "${args['identity']}"
identity.fail_unknown
identity.fail_none_active
identity.fail_other_active

# Close the identity and all its running VMs
_warning "Stopping machines of identity $IDENTITY"
identity.shutdown_qubes

# If the identity browser VM is used with the split-browser backend.
web.backend.unset_client

echo && _warning "Deleting identity VMs"
identity.delete_qubes

echo && _warning "Deleting identity settings"
identity.config_unset QUBE_LABEL
identity.config_unset QUBE_PREFIX
identity.config_unset NETVM_QUBE


echo && _success "Successfully deleted qubes of identity $IDENTITY"
