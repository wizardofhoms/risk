
# proxy.tor_create creates a new TOR Whonix gateway AppVM.
# $1 - Name to use for new VM
# $2 - Netvm for this gateway
# $3 - Label
function proxy.tor_create ()
{
    local gw="${1}-tor"
    local netvm="${2-$(config_get DEFAULT_NETVM)}"
    local gw_label="${3-yellow}"
    local gw_template="$(config_get WHONIX_GW_TEMPLATE)"

    _info "New TOR gateway qube"
    _info "Name:      $gw"
    _info "Netvm:     $netvm"
    _info "Template:  $gw_template"

    _run qvm-create "${gw}" --property netvm="$netvm" --label "$gw_label" --template "$gw_template"
    _run qvm-prefs "$gw" provides_network true

    # Tag the VM with its owner, and save as identity tor gateway
    _run qvm-tags "$gw" set "$IDENTITY"
    echo "$gw" > "${IDENTITY_DIR}/tor_gw"
    echo "$gw" > "${IDENTITY_DIR}/net_vm"
}

# proxy.tor_clone is similar to proxy.tor_create, except that we clone 
# an existing gateway AppVM instead of creating a new one from a Template.
function proxy.tor_clone ()
{
    local gw="${1}-tor"
    local gw_clone="$2"
    local netvm="${3-$(config_get DEFAULT_NETVM)}"
    local gw_label="${4-yellow}"

    _info "New TOR gateway qube"
    _info "Name:          $gw"
    _info "Netvm:         $netvm"
    _info "Cloned from:   $gw_clone"

    _run qvm-clone "${gw_clone}" "${gw}"
    _catch "Failed to clone VM ${gw_clone}"

    # For now disposables are not allowed, since it would create too many VMs,
    # and complicate a bit the setup steps for VPNs. If the clone is a template
    # for disposables, unset it
    local disp_template
    disp_template=$(qvm-prefs "${gw}" template_for_dispvms)
    if [[ "$disp_template" = "True" ]]; then
        qvm-prefs "${gw}" template_for_dispvms False
    fi

    _info "Getting network from $netvm"
    _run qvm-prefs "$gw" netvm "$netvm"

    _verbose "Setting label to $gw_label"
    _run qvm-prefs "$gw" label "$gw_label"

    # Tag the VM with its owner, and save as identity tor gateway
    _run qvm-tags "$gw" set "$IDENTITY"
    echo "$gw" > "${IDENTITY_DIR}/tor_gw"
    echo "$gw" > "${IDENTITY_DIR}/net_vm"
}

# proxy.fail_config_tor exits the program if risk lacks some information
# (which templates/clones to use) when attempting to create a Tor qube.
function proxy.fail_config_tor ()
{
    [[ ${args['--no-tor']} -eq 1 ]] && return

    local template clone netvm

    # Check qubes specified in config or flags.
    template="$(config_get WHONIX_GW_TEMPLATE)"
    [[ -n "${args['--clone-tor-from']}" ]] && clone="${args['--clone-tor-from']}"

    # Check those qubes exist
    if [[ -n ${clone} ]]; then
        ! qube.exists "${clone}" && _failure "Qube to clone ${clone} does not exist"
    else
        ! qube.exists "${template}" && _failure "Qube template ${template} does not exist"
    fi
}

# proxy.skip_tor_create returns 0 when there not enough information in the configuration
# file or in command flags for creating a new TOR qube (no templates/clones indicated, etc).
# Needs access to command-line flags
function proxy.skip_tor_create ()
{
    [[ ${args['--no-tor']} -eq 1 ]] && return 0

    local template clone netvm

    template="$(config_get WHONIX_GW_TEMPLATE)"
    [[ -n "${args['--clone-tor-from']}" ]] && clone="${args['--clone-tor-from']}"

    [[ -z ${template} && -z ${clone} ]] && \
        _info "Skipping TOR gateway: no TemplateVM/AppVM specified in config or flags" && return 0

    return 1
}

