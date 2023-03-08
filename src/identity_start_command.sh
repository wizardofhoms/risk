
local active_identity enabled_vms

# Check the identity is valid, and open in vault if needed.
identity_set "${args['identity']}"
identity_check_exists

active_identity="$(identity_get_active)"
if [[ -n "${active_identity}" ]]; then
    if [[ "${active_identity}" != "${IDENTITY}" ]]; then
        identity_check_none_active "$IDENTITY"
    fi
    _info "Identity ${IDENTITY} already opened in vault"
else
    risk_identity_open_command
fi

# Start all enabled identity machines
read -rA enabled_vms < <(_identity_autostart_vms)
for vm in "${enabled_vms[@]}"; do
    if [[ -z "${vm}" ]]; then 
        continue 
    fi
    _info "Starting VM ${vm}"
    _run start_vm "${vm}"
done

_success "Opened identity '$IDENTITY' and started enabled VMs"
