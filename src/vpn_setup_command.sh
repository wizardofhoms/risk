
identity.set

local name config_vm client_conf_path netvm

name="${args['vm']}"
config_vm="${args['--config-in']}"
client_conf_path="$(config_or_flag "" DEFAULT_VPN_CLIENT_CONF)"
netvm="$(config_or_flag "${args['--netvm']}" "$(identity.config_get NETVM_QUBE)")"

# Set the netVM of this VPN if required.
if [[ -n "${netvm}" ]]; then
    _info "Getting network from $netvm"
    qvm-prefs "$name" netvm "$netvm"
fi

# Possibly set VPN to be the default NetVM for all client qubes (browsers, etc).
if [[ ${args['--set-default']} -eq 1 ]]; then
    _info "Setting '$name' as default NetVM for all client machines"
    identity.config_set NETVM_QUBE "${name}"

    # Find all existing client VMs (not gateways) and change their netVMs.
    read -rA clients < <(identity.client_qubes)
    for client in "${clients[@]}"; do
        if [[ -n "$client" ]]; then
            _verbose "Changing $client netVM"
            qvm-prefs "$client" netvm "$name"
        fi
    done
fi

# Client VPN Configurations
if [[ "${args['--choose']}" -eq 1 ]]; then
    # If we are asked to choose an existing configuration in the VM
    _run_exec "$name" /usr/local/bin/setup_VPN
elif [[ -n "${args['--config-in']}" ]]; then
    # Or if we are asked to browse one or more configuration files in another VM.
    proxy.vpn_import_configs "$name" "$config_vm" "$client_conf_path"
fi
