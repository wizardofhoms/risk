
# proxy.tor_create creates a new TOR Whonix gateway AppVM.
# $1 - Name to use for new VM
# $2 - Netvm for this gateway
# $3 - Label
function proxy.tor_create ()
{
    local gw="${1}-gw"
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
    local gw="${1}-gw"
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
