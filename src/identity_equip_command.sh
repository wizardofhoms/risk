
local name="${args['identity']}"

# Other variables
local vm_name           # Default prefix to use for newly created vm (eg. 'joe' => joe-vpn, joe-web)
local label             # Default label color to use for all VMs, varies if not specified
local gw_netvm          # NetVM for the tor gateway
local web_netvm         # NetVM for the Web browser VM
local clone             # A variable that might be overritten several times, used to assign a VM to clone.

# 1 - Identity basic setup
identity.set "${name}"
identity.fail_unknown "$IDENTITY"

_in_section "risk" 8 && _info "Creating qubes for identity $IDENTITY"

identity.set_global_props
label=$(identity.config_get QUBE_LABEL)
vm_name=$(identity.config_get QUBE_PREFIX)

# 2 - Network VMs
_in_section "network" && echo && _warning "Creating network VMs"
gw_netvm="$(identity.config_get NETVM_QUBE)"

if ! proxy.skip_tor_create; then
    if [[ -n ${args['--clone-tor-from']} ]]; then
        clone="${args['--clone-tor-from']}"
        proxy.tor_clone "$vm_name" "$clone" "$gw_netvm" "$label"
    else
        proxy.tor_create "$vm_name" "$gw_netvm" "$label"
    fi
fi

# 3 - Browser VMs
_in_section "web" && echo && _warning "Creating browsing VMs"
web_netvm="$(identity.config_get NETVM_QUBE)"

# Browser client
if ! web.skip_browser_create; then
    if [[ -n ${args['--clone-web-from']} ]]; then
        clone="${args['--clone-web-from']}"
        web.browser_clone "$vm_name" "$clone" "$web_netvm" "$label"
    else
        web.browser_create "$vm_name" "$web_netvm" "$label"
    fi
fi

# Split-browser backend
if ! web.skip_split_create; then
    web.split_backend_create "${vm_name}" "${label}"
fi

# Per-identity bookmarks file in vault management tomb.
web.bookmark_create_file

## All done ##
echo && _in_section 'risk' && _success "Successfully initialized infrastructure for identity $IDENTITY"
