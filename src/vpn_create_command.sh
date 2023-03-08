
identity_set 

# Prepare some settings for this new VM
local name netvm clone template label

name="${args['vm']:-$(cat "${IDENTITY_DIR}/vm_name" 2>/dev/null)}"
label="${args['--label']:=$(_identity_default_vm_label)}"
netvm="$(config_or_flag "${args['--netvm']}" DEFAULT_NETVM)"
clone="$(config_or_flag "${args['--from']}" VPN_VM)"
template="$(config_or_flag "${args['--template']}" VPN_TEMPLATE)"


# 0 - Last-time setup

# If the --name flag is empty, this means we are using a default one,
# either the configured default one, or the name of the identity. 
# In this case, we add 'vpn-1' to it (number varying).
if [[ -z "${args['vm']}" ]]; then
    name="$(vpn_next_vm_name "$name")"
fi

# 1 - Creation
#
# We either clone the gateway from an existing one,
# or we create it from a template.
if [[ "${args['--clone']}" -eq 1 ]]; then
    _info "Cloning VPN gateway (from VM $clone)"
    vpn_clone "$name" "$netvm" "$label" "$clone" 
else
    _info "Creating VPN gateway (from template $template)"
    vpn_create "$name" "$netvm" "$label" "$template"
fi

# Tag the VM with its owner
_run qvm-tags "$name" "$RISK_VM_OWNER_TAG" "$IDENTITY"
_catch "Failed to tag VM with identity"

# 2 - Setup
#
# Simply run the setup command, which has access to all the flags
# it needs to do its job. Tweak the args array for this to work.
args['vm']="$name"
risk_vpn_setup_command

# If the VM is marked autostart
if [[ -n ${args['--enable']} ]]; then 
    _verbose "Enabling VM to autostart"
    risk_vpn_enable_command
fi

_info "Done creating VPN gateway $name"
