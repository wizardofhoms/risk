
_set_identity "${args[identity]}"

# Get the name for VMs
local name="$(cat "${IDENTITY_DIR}/vm_name")"

# Check the identity is valid

# Open the identity in vault

# Start all enabled network machines

# Start all enabled client machines

_success "Opened identity '$IDENTITY' and started enabled VMs"
