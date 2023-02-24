
_set_identity "${args['identity']}"

# First check the identity is valid

# Check access to hush device in vault

# Close the identity

# Close all machines belonging to the identity

# Delete these machines

# Delete the identity data in the vault

# And delete the identity directory in dom0.

_success "Successfully deleted identity $IDENTITY"
