
# proxy.vpn_create creates a new VPN gateway from a TemplateVM
function proxy.vpn_create ()
{
    local gw="${1}"
    local netvm="${2-$(config_get DEFAULT_NETVM)}"
    local gw_label="${3:=blue}"
    local template="${4:=$(config_get VPN_TEMPLATE)}"

    _info "New VPN qube"
    _info "Name:      $gw"
    _info "Netvm:     $netvm"
    _info "Template:  $template"

    _run qvm-create --property netvm="$netvm" --label "$gw_label" --template "$template"

    _info "Getting network from $netvm"

    # Tag the VM with its owner, and add the gateway to the list of proxies
    _run qvm-tags "$gw" set "$IDENTITY"
    echo "$gw" >> "${IDENTITY_DIR}/proxy_vms"
}

# proxy.vpn_clone creates a new VPN gateway from an existing VPN AppVM
function proxy.vpn_clone ()
{
    local gw="${1}"
    local netvm="${2-$(config_get DEFAULT_NETVM)}"
    local gw_label="${3:=blue}"
    local gw_clone="$4"

    # Create the VPN
    _info "New VPN qube"
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
    [[ "$disp_template" = "True" ]] && qvm-prefs "${gw}" template_for_dispvms False

    _info "Getting network from $netvm"
    _run qvm-prefs "$gw" netvm "$netvm"

    _verbose "Setting label to $gw_label"
    _run qvm-prefs "$gw" label "$gw_label"

    # Tag the VM with its owner, and add the gateway to the list of proxies
    _run qvm-tags "$gw" set "$IDENTITY"
    echo "$gw" >> "${IDENTITY_DIR}/proxy_vms"
}

# proxy.vpn_import_configs browses for one or more (as zip) VPN client configurations
# in another VM, import them in our VPN VM, and run the setup wizard if there is more 
# than one configuration to choose from.
# $1 - Name of VPN VM
# $2 - Name of VM in which to browse for configuration
# $3 - Path to the VPN client config to which one (only) should be copied, if not a zip file
function proxy.vpn_import_configs ()
{
    local name="$1"
    local config_vm="$2"
    local client_conf_path="$3"

    local config_path
    local new_path

    config_path=$(_run_exec "$config_vm" "zenity --file-selection --title='VPN configuration selection' 2>/dev/null")
    if [[ -z "$config_path" ]]; then
        _info "Canceling setup: no file selected in VM $config_vm"
    else
        _verbose "Copying file $config_path to VPN VM"
        _run_exec "$config_vm" qvm-copy-to-vm "$name" "$config_path"

        # Now our configuration is the QubesIncoming directory of our VPN,
        # so we move it where the VPN will look for when starting.
        new_path="/home/user/QubesIncoming/${config_vm}/$(basename "$config_path")"

        # If the file is a zip file, unzip it in the configs directory
        # and immediately run the setup prompt to choose one.
        if [[ $new_path:t:e == "zip" ]]; then
            local configs_dir="/rw/config/vpn/configs"
            _verbose "Unzipping files into $configs_dir"
            _run_exec "$name" mkdir -p "$configs_dir"
            _run_exec "$name" unzip -j -d "$configs_dir"
            _run_exec "$name" /usr/local/bin/setup_VPN
        else
            _verbose "Copying file directly to the VPN client config path"
            _run_exec "$name" mv "$new_path" "$client_conf_path"
        fi

        _info "Done transfering VPN client configuration to VM"
    fi

    # Add the gateway to the list of existing proxies for this identity
    echo "$gw" > "${IDENTITY_DIR}/proxy_vms"
}

# proxy.vpn_next_name returns a name for a new VPN VM, such as vpn-1,
# where the number is the next value after the ones found in existing
# VPN vms.
function proxy.vpn_next_name ()
{
    local base_name="$1"

    # First get the array of ProxyVMs names
    read -rA proxies < <(identity.proxy_qubes)

    local next_number=1

    for proxy in "${proxies[@]}"; do
        if contains "$proxy" "vpn-"; then
            next_number=$((next_number + 1))
        fi
    done

    print "$base_name-vpn-$next_number"
}

# proxy.fail_not_identity_proxy exits the program 
# if the VM is not listed as an identity proxy.
function proxy.fail_not_identity_proxy ()
{
    local name="$1"

    read -rA proxies < <(identity.proxy_qubes)
    for proxy in "${proxies[@]}" ; do
        if [[ $proxy == "$name" ]]; then
            found=true
        fi
    done

    if [[ ! $found ]]; then
        _info "VM $name is not listed as a VPN gateway. Aborting."
        exit 1
    fi
}
