
# Variables setup ==========================================================

# Default settings that are always defined in the config.
local vault_vm="$(config_get VAULT_VM)"
local default_netvm="$(config_get DEFAULT_NETVM)"

# Variables populated from command-line args/flags
local name="${args[identity]}"
local email="${args[email]}"
local expiry="${args[expiry_date]}"
local pendrive="${args[--backup]}" 
local backup_args

# Other variables
local vm_name           # Default prefix to use for newly created vm (eg. 'joe' => joe-vpn, joe-web)
local label             # Default label color to use for all VMs, varies if not specified
local netvm             # Entry NetVM for the identity
local backup_args       # If identity is to be immediately backed up, this is the flag + the /dev/path in vault
local gw_netvm          # NetVM for the tor gateway
local vpn_netvm         # NetVM for the VPN gateway
local web_netvm         # NetVM for the Web browser VM
local clone             # A variable that might be overritten several times, used to assign a VM to clone.

# Propagate the identity and its settings
_set_identity "${args[identity]}"


# Identity checks and basic setup ==========================================

# First open the identity, because we might need its credentials and stuff
# The identity argument is here, so this command has the arguments it needs
active_identity=$(qvm-run --pass-io "$vault_vm" 'cat .identity' 2>/dev/null)
if [[ -n $active_identity ]]; then
    # It might be the same
    if [[ $active_identity != "$IDENTITY" ]]; then
        _failure "Another identity ($IDENTITY) is active. Close/slam/stop it and rerun this command"
    fi
else
    risk_open_identity_command
    _catch "Failed to open identity $IDENTITY"
fi

# Make a directory for this identity, and store the associated VM name
[[ -e ${IDENTITY_DIR} ]] || mkdir -p "$IDENTITY_DIR"

# Else we're good to go
_message "Creating identity $IDENTITY and infrastructure"

# If the user wants to use a different vm_name for the VMs
vm_name="${args[--name]-$IDENTITY}"
echo "$vm_name" > "${IDENTITY_DIR}/vm_name" 
_message "Using vm_name '$name' as VM base name"

label="${args[--label]}"
echo "$vm_name" > "${IDENTITY_DIR}/vm_label" 
_message "Using label '$label' as VM default label"

# Prepare the root NetVM for this identity
netvm="${default_netvm}"

# Create identity in vault =================================================

# Simply pass the arguments to the vault
_message "Creating identity in vault"

if [[ -n "$pendrive" ]]; then
    backup_args=(--backup "$pendrive")
fi

_qrun "$vault_vm" risks create identity "$name" "$email" "$expiry" "${backup_args[@]}" 
_catch "Failed to create identity in vault"

# Then, open it
_qrun "$vault_vm" risks open identity "$name"
_catch "Failed to open identity in vault"

# Network VMs ==============================================================
_message "Creating network VMs:"

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


# 2 - VPNs, if not explicitly disabled
if [[ ${args[--no-vpn]} -eq 0 ]]; then
    local vpn_netvm="$(cat "${IDENTITY_DIR}/net_vm" )"

    # We either clone the gateway from an existing one,
    # or we create it from a template.
    if [[ -n ${args[--clone-vpn-from]} ]]; then
        clone="${args[--clone-vpn-from]}"
        clone_vpn_gateway "$vm_name" "$clone" "$vpn_netvm" "$label"
    else
        create_vpn_gateway "$vm_name" "$vpn_netvm" "$label"
    fi

    # Set it as the netvm for this identity
    echo "$vm_name" > "${IDENTITY_DIR}/net_vm" 
else
    _message "Skipping VPN gateway"
fi

# At this point we should know the vm_name of the VM to be used as NetVM
# for the subsquent machines, such as web browsing and messaging VMs.

# Message VMs ==============================================================
_message "Creating messaging VMs:"

# if [[ ${args[--no-messenger]} -eq 0 ]]; then
#     local msg="${vm_name}-msg"
# else
#     _message "Skipping messaging VM"
# fi


# Browser VMs ==============================================================
_message "Creating web VMs:"

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
    clone_split_browser_vm "$vm_name" "$clone" "$label"
else
    create_split_browser_vm "$vm_name" "$label"
fi


## All done ##
_success "Successfully initialized infrastructure for identity $IDENTITY"
