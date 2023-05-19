
identity.set

# Prepare some settings for this new VM
local name netvm clone template label

# Identity specific values.
name=$(identity.config_get QUBE_PREFIX)
if [[ -n "${args['vm']}" ]]; then
    name="${name}-${args['vm']}-vpn"
fi

label="${args['--label']:=$(identity.vm_label)}"

netvm="${args['--netvm']}"
if [[ -z "${netvm}" ]]; then
    netvm="$(identity.config_get NETVM_QUBE)"
fi
if [[ -z "${netvm}" ]]; then
    netvm="$(config_get DEFAULT_NETVM)"
fi

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
if [[ ${args['--enable']} -eq 1 ]]; then
    _verbose "Enabling VM to autostart"
    risk_vpn_enable_command
fi

_info "Done creating VPN gateway $name"
