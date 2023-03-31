
identity.set

# Prepare some settings for this new VM
local name netvm clone template label

# Identity specific values.
name=$(identity.config_get QUBE_PREFIX)
label="${args['--label']:=$(identity.vm_label)}"
netvm="$(config_or_flag "${args['--netvm']}" "$(identity.config_get NETVM_QUBE)")"

# Global config
clone="$(config_or_flag "${args['--from']}" VPN_VM)"
template="$(config_or_flag "${args['--template']}" VPN_TEMPLATE)"

_warning "Starting VPN qube creation"

# Get the name to use for this qube, from flags/args or defaults.
if [[ -z "${args['vm']}" ]]; then
    name="$(proxy.vpn_next_name "$name")"
fi


# Create or clone the qube.
if [[ "${args['--clone']}" -eq 1 ]]; then
    proxy.vpn_clone "$name" "$netvm" "$label" "$clone"
else
    proxy.vpn_create "$name" "$netvm" "$label" "$template"
fi


# Run the setup command, which will reuse all required flags.
echo
args['vm']="$name"
risk_vpn_setup_command

# If the VM is marked autostart
if [[ -n ${args['--enable']} ]]; then
    _verbose "Enabling VM to autostart"
    risk_vpn_enable_command
fi

_info "Done creating VPN gateway $name"
