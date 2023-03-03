
# Creates a new TOR Whonix gateway AppVM.
# $1 - Name to use for new VM
# $2 - Netvm for this gateway
# $3 - Label
create_tor_gateway ()
{
    local gw="${1}-gw"
    local netvm="${2-$(config_get DEFAULT_NETVM)}"
    local gw_label="${3-yellow}"

    local gw_template="$(config_get WHONIX_GW_TEMPLATE)"

    _info "Creating TOR gateway VM (name: $gw / netvm: $netvm / template: $gw_template)"
    _run qvm-create "${gw}" --property netvm="$netvm" --label "$gw_label" --template "$gw_template"
    _run qvm-prefs "$gw" provides_network true 

    # Tag the VM with its owner, and save as identity tor gateway
    _run qvm-tags "$gw" set "$IDENTITY"
    echo "$gw" > "${IDENTITY_DIR}/tor_gw"
    echo "$gw" > "${IDENTITY_DIR}/net_vm"
}

# very similar to create_tor_gateway, except that we clone an existing
# gateway AppVM instead of creating a new one from a Template.
clone_tor_gateway ()
{
    local gw="${1}-gw"
    local gw_clone="$2"
    local netvm="${3-$(config_get DEFAULT_NETVM)}"
    local gw_label="${4-yellow}"

    _info "Cloning TOR gateway VM (name: $gw / netvm: $netvm / template: $gw_clone)"
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
