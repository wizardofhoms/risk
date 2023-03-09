
local name="${args['identity']}"

# Other variables
local vm_name           # Default prefix to use for newly created vm (eg. 'joe' => joe-vpn, joe-web)
local label             # Default label color to use for all VMs, varies if not specified
local gw_netvm          # NetVM for the tor gateway
local web_netvm         # NetVM for the Web browser VM
local clone             # A variable that might be overritten several times, used to assign a VM to clone.

# Propagate the identity and its settings (in the script only)
identity_set "${args['identity']}"

# Identity checks and basic setup ==========================================

identity_check_exists "$IDENTITY"

_in_section "identity" 8 && _info "Creating infrastructure for identity $IDENTITY"

# Make a directory for this identity, and store the associated VM name
[[ -e ${IDENTITY_DIR} ]] || mkdir -p "$IDENTITY_DIR"

# If the user wants to use a different vm_name for the VMs
vm_name="${args['--prefix']-$IDENTITY}"
_info "Using '$name' as VM prefix"
echo "$vm_name" > "${IDENTITY_DIR}/vm_name" 

label="${args['--label']-orange}"
_info "Using label '$label' as VM default label"
echo "$vm_name" > "${IDENTITY_DIR}/vm_label" 

# Prepare the root NetVM for this identity
config_get DEFAULT_NETVM > "${IDENTITY_DIR}/net_vm" 

# Network VMs ==============================================================
_in_section "network" && _info "Creating network VMs"
gw_netvm="$(cat "${IDENTITY_DIR}/net_vm")"

# 1 - Tor gateway, if not explicitly disabled
if [[ ${args['--no-gw']} -eq 0 ]]; then
    if [[ -n ${args['--clone-gw-from']} ]]; then
        clone="${args['--clone-gw-from']}"
        tor_gateway_clone "$vm_name" "$clone" "$gw_netvm" "$label"
    else
        tor_gateway_create "$vm_name" "$gw_netvm" "$label"
    fi
else
    _info "Skipping TOR gateway"
fi

# Browser VMs ==============================================================
_in_section "web" && _info "Creating browsing VMs"
web_netvm="$(cat "${IDENTITY_DIR}/net_vm")"

# Browser VMs are disposable, but we make a template for this identity,
# since we might  either modify stuff in there, and we need them at least 
# to have a different network route.
if [[ -n ${args['--clone-web-from']} ]]; then
    clone="${args['--clone-web-from']}"
    web_clone_browser_vm "$vm_name" "$clone" "$web_netvm" "$label"
else
    web_create_browser_vm "$vm_name" "$web_netvm" "$label"
fi

# Per-identity bookmarks file in vault management tomb.
web_create_identity_bookmarks

## All done ##
_success "Successfully initialized infrastructure for identity $IDENTITY"
