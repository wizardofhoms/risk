
local active_identity enabled_vms

# Check the identity is valid, and open in vault if needed.
identity.set "${args['identity']}"
identity.fail_other_active
risk_identity_open_command

# Start all enabled identity machines
read -rA enabled_vms < <(identity.enabled_qubes)
for vm in "${enabled_vms[@]}"; do
    if [[ -z "${vm}" ]]; then
        continue
    fi
    _info "Starting VM ${vm}"
    _run qube.start "${vm}"
done

_in_section 'risk' && _success "Opened identity '$IDENTITY' and started enabled VMs"
