
local name="${args[identity]}"

# Other variables
local vm_name           # Default prefix to use for newly created vm (eg. 'joe' => joe-vpn, joe-web)
local label             # Default label color to use for all VMs, varies if not specified
local netvm             # Entry NetVM for the identity
local gw_netvm          # NetVM for the tor gateway
local web_netvm         # NetVM for the Web browser VM
local clone             # A variable that might be overritten several times, used to assign a VM to clone.

# Propagate the identity and its settings (in the script only)
_set_identity "${args[identity]}"

# Identity checks and basic setup ==========================================

check_identity_exists "$IDENTITY"

_message "Creating infrastructure for identity $IDENTITY"

# Make a directory for this identity, and store the associated VM name
[[ -e ${IDENTITY_DIR} ]] || mkdir -p "$IDENTITY_DIR"

# If the user wants to use a different vm_name for the VMs
vm_name="${args[--prefix]-$IDENTITY}"
echo "$vm_name" > "${IDENTITY_DIR}/vm_name" 
_message "Using vm_name '$name' as VM base name"

label="${args[--label]}"
echo "$vm_name" > "${IDENTITY_DIR}/vm_label" 
_message "Using label '$label' as VM default label"

# Prepare the root NetVM for this identity
netvm="${DEFAULT_NETVM}"

# Network VMs ==============================================================
_in_section "network" && _message "Creating network VMs:"

# 1 - Tor gateway, if not explicitly disabled
if [[ ${args[--no-gw]} -eq 0 ]]; then
    gw_netvm="$netvm"

    # We either clone the gateway from an existing one,
    # or we create it from a template.
    if [[ -n ${args[--clone-gw-from]} ]]; then
        clone="${args[--clone-gw-from]}"
        clone_tor_gateway "$vm_name" "$clone" "$gw_netvm" "$label"
    else
        create_tor_gateway "$vm_name" "$gw_netvm" "$label"
    fi

    # Set it as the netvm for this identity, and for the rest of the VMs
    echo "$vm_name" > "${IDENTITY_DIR}/net_vm" 
else
    _message "Skipping TOR gateway"
fi

# At this point we should know the vm_name of the VM to be used as NetVM
# for the subsquent machines, such as web browsing and messaging VMs.

# Browser VMs ==============================================================
_in_section "web" && _message "Creating browsing VMs:"

# Browser VMs are disposable, but we make a template for this identity,
# since we might  either modify stuff in there, and we need them at least 
# to have a different network route.
if [[ -n ${args[--clone-web-from]} ]]; then
    web_netvm="$(cat "${IDENTITY_DIR}/net_vm")"

    clone="${args[--clone-web-from]}"
    clone_browser_vm "$vm_name" "$clone" "$web_netvm" "$label"
else
    create_browser_vm "$vm_name" "$web_netvm" "$label"
fi

# Split-browser has its own dispVMs and bookmarks
local split_web="${vm_name}-split-web"
if [[ -n ${args[--clone-split-from]} ]]; then
    clone="${args[--clone-split-from]}"
    clone_split_browser_vm "$split_web" "$clone" "$label"
else
    create_split_browser_vm "$split_web" "$label"
fi


## All done ##
_success "Successfully initialized infrastructure for identity $IDENTITY"
