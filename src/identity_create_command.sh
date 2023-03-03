
# Variables setup ==========================================================

# Variables populated from command-line args/flags
local name="${args['identity']}"
local email="${args['email']}"
local expiry="${args['expiry_date']}"
local pendrive="${args['--backup']}" 

# Other variables
local vm_name           # Default prefix to use for newly created vm (eg. 'joe' => joe-vpn, joe-web)
local label             # Default label color to use for all VMs, varies if not specified
local netvm             # Entry NetVM for the identity
local backup_args       # If identity is to be immediately backed up, this is the flag + the /dev/path in vault
local gw_netvm          # NetVM for the tor gateway
local web_netvm         # NetVM for the Web browser VM
local clone             # A variable that might be overritten several times, used to assign a VM to clone.

# Propagate the identity and its settings (in the script only)
_set_identity "${args['identity']}"


# Identity checks and basic setup ==========================================

# Check no active identity is here,
if _identity_active ; then
    _failure "Another identity ($IDENTITY) is active. Close/slam/stop it and rerun this command"
fi

# or that the one we want to create does not exists already
if check_identity_exists "$IDENTITY" ; then
    _failure "Identity $IDENTITY already exists"
fi

# We're good to go
_info "Creating identity $IDENTITY and infrastructure"

# Make a directory for this identity, and store the associated VM name
[[ -e ${IDENTITY_DIR} ]] || mkdir -p "$IDENTITY_DIR"

# If the user wants to use a different vm_name for the VMs
vm_name="${args['--prefix']-$IDENTITY}"
echo "$vm_name" > "${IDENTITY_DIR}/vm_name" 
_info "Using vm_name ${fg_bold[green]}'$name'${reset_color} as VM base name"

label="${args['--label']}"
echo "$vm_name" > "${IDENTITY_DIR}/vm_label" 
_info "Using label ${fg_bold[green]}'$label'${reset_color} as VM default label"

# Prepare the root NetVM for this identity
netvm="${DEFAULT_NETVM}"


# Create identity in vault =================================================

# Simply pass the arguments to the vault
_info "Creating identity in vault"

if [[ -n "$pendrive" ]]; then
    backup_args=(--backup "$pendrive")
fi

# Create it
_qrun_term "$VAULT_VM" risks identity create "$name" "$email" "$expiry" "${backup_args[@]}" 
_catch "Failed to create identity in vault"

# And open it, in case the last command backed up the identity, which closed it.
_qrun_term "$VAULT_VM" risks open identity "$name"
_catch "Failed to open identity in vault"

# If the user only wanted to create the identity in the vault, exit.
if [[ ${args['--vault-only']} -eq 1 ]] ; then
    _success "Successfully created identity $IDENTITY"
    _info "Skipping infrastructure setup" && exit
fi

# Network VMs ==============================================================
_in_section "network" && _info "Creating network VMs:"

# 1 - Tor gateway, if not explicitly disabled
if [[ ${args['--no-gw']} -eq 0 ]]; then
    gw_netvm="$netvm"

    # We either clone the gateway from an existing one,
    # or we create it from a template.
    if [[ -n ${args['--clone-gw-from']} ]]; then
        clone="${args['--clone-gw-from']}"
        clone_tor_gateway "$vm_name" "$clone" "$gw_netvm" "$label"
    else
        create_tor_gateway "$vm_name" "$gw_netvm" "$label"
    fi

    # Set it as the netvm for this identity, and for the rest of the VMs
    echo "$vm_name" > "${IDENTITY_DIR}/net_vm" 
else
    _info "Skipping TOR gateway"
fi

# Browser VMs ==============================================================
_in_section "web" && _info "Creating browsing VMs:"

# Browser VMs are disposable, but we make a template for this identity,
# since we might  either modify stuff in there, and we need them at least 
# to have a different network route.
if [[ -n ${args['--clone-web-from']} ]]; then
    web_netvm="$(cat "${IDENTITY_DIR}/net_vm")"

    clone="${args['--clone-web-from']}"
    clone_browser_vm "$vm_name" "$clone" "$web_netvm" "$label"
else
    create_browser_vm "$vm_name" "$web_netvm" "$label"
fi

# Split-browser has its own dispVMs and bookmarks
local split_web="${vm_name}-split-web"
if [[ -n ${args['--clone-split-from']} ]]; then
    clone="${args['--clone-split-from']}"
    clone_split_browser_vm "$split_web" "$clone" "$label"
else
    create_split_browser_vm "$split_web" "$label"
fi

# Per-identity bookmarks file in vault management tomb.
create_bookmark_user_file

## All done ##
_success "Successfully initialized infrastructure for identity $IDENTITY"
