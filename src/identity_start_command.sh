
local active_identity enabled_vms

# Check the identity is valid, and open in vault if needed.
identity.set "${args['identity']}"
identity.fail_unknown

active_identity="$(identity.active)"
if [[ -n "${active_identity}" ]]; then
    if [[ "${active_identity}" != "${IDENTITY}" ]]; then
        identity.fail_none_active "$IDENTITY"
    fi
    _info "Identity ${IDENTITY} already opened in vault"
else
    risk_identity_open_command
fi

# Start all enabled identity machines
read -rA enabled_vms < <(identity.enabled_qubes)
for vm in "${enabled_vms[@]}"; do
    if [[ -z "${vm}" ]]; then
        continue
    fi
    _info "Starting VM ${vm}"
    _run qube.start "${vm}"
done

_success "Opened identity '$IDENTITY' and started enabled VMs"
