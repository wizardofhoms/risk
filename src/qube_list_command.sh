
local clients proxies

identity.set

# Defaults
_warning "Global values and defaults:"
[[ -n "$(identity.netvm)" ]] && _info "${fg[blue]}Default netVM${fg[white]}: $(identity.netvm)"
[[ -n "$(identity.tor_gateway)" ]] && _info "${fg[blue]}Tor gateway${fg[white]}: \t$(identity.tor_gateway)"
[[ -n "$(identity.browser_qube)" ]] && _info "${fg[blue]}Browser qube${fg[white]}: \t$(identity.browser_qube)"

# Network VMs
read -rA proxies < <(identity.proxy_qubes)
if [[ -n "${proxies[*]}" ]]; then
    echo && _warning "Proxy qubes:"
    for proxy in "${proxies[@]}"; do
        printf "\t\t%s" "${proxy}"
    done
fi

# Client VMs
read -rA clients < <(identity.client_qubes)
if [[ -n "${clients[*]}" ]]; then
    echo && _warning "Client qubes:"
    for client in "${clients[@]}"; do
        printf "\t\t%s" "${client}"
    done
fi
