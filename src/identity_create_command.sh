
# Variables setup ==========================================================

# Variables populated from command-line args/flags
name="${args['name']}"
name="$(identity.get_args_name "${name}")"
identity="${name// /_}"
expiry="$(identity.get_args_expiry "${args['expiry_date']}")"
email="$(identity.get_args_mail "${name}" "${args['email']}")"
pendrive="${args['--backup']}"

# Other variables
local vm_name           # Default prefix to use for newly created vm (eg. 'joe' => joe-vpn, joe-web)
local label             # Default label color to use for all VMs, varies if not specified
local other_args        # Other args/flags to pass to vault identity create command (backup/burner, etc)
local gw_netvm          # NetVM for the tor gateway
local web_netvm         # NetVM for the Web browser VM
local clone             # A variable that might be overritten several times, used to assign a VM to clone.

# Propagate the identity and its settings (in the script only)
identity.set "${identity}"

# Identity checks and basic setup ==========================================

# Check no active identity is here,
if _identity_active ; then
    _failure "Another identity ($IDENTITY) is active. Close/slam/stop it and rerun this command"
fi

# or that the one we want to create does not exists already
if identity.fail_unknown "$IDENTITY" ; then
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
config_get DEFAULT_NETVM > "${IDENTITY_DIR}/net_vm"

# Create identity in vault =================================================

# Simply pass the arguments to the vault
_in_section "identity" 8 && _info "Creating identity in vault"

if [[ -n "$pendrive" ]]; then
    other_args=(--backup "$pendrive")
fi
if [[ "${args['--burner']}" -eq 1 ]]; then
    other_args+=( --burner )
fi

# Create it
_run_qube_term "$VAULT_VM" risks identity create "$name" "$email" "$expiry" "${other_args[@]}"
_catch "Failed to create identity in vault"

# And open it, in case the last command backed up the identity, which closed it.
_run_qube_term "$VAULT_VM" risks identity open "$name"
_catch "Failed to open identity in vault"

# If the user only wanted to create the identity in the vault, exit.
if [[ ${args['--vault-only']} -eq 1 ]] ; then
    _success "Successfully created identity $IDENTITY"
    _info "Skipping infrastructure setup" && exit
fi

# Network VMs ==============================================================
_in_section "network" && _info "Creating network VMs:"
gw_netvm="$(cat "${IDENTITY_DIR}/net_vm")"

# 1 - Tor gateway, if not explicitly disabled
if [[ ${args['--no-gw']} -eq 0 ]]; then
    if [[ -n ${args['--clone-gw-from']} ]]; then
        clone="${args['--clone-gw-from']}"
        proxy.tor_clone "$vm_name" "$clone" "$gw_netvm" "$label"
    else
        proxy.tor_create "$vm_name" "$gw_netvm" "$label"
    fi
else
    _info "Skipping TOR gateway"
fi

# Browser VMs ==============================================================
_in_section "web" && _info "Creating browsing VMs:"
web_netvm="$(cat "${IDENTITY_DIR}/net_vm")"

# Browser VMs are disposable, but we make a template for this identity,
# since we might  either modify stuff in there, and we need them at least
# to have a different network route.
if [[ -n ${args['--clone-web-from']} ]]; then
    clone="${args['--clone-web-from']}"
    web.browser_clone "$vm_name" "$clone" "$web_netvm" "$label"
else
    web.browser_create "$vm_name" "$web_netvm" "$label"
fi

# Per-identity bookmarks file in vault management tomb.
web.bookmark_create_file

## All done ##
_success "Successfully initialized infrastructure for identity $IDENTITY"
