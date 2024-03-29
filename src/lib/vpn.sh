
# proxy.vpn_create creates a new VPN gateway from a TemplateVM
function proxy.vpn_create ()
{
    local gw="${1}"
    local netvm="${2}"
    local gw_label="${3-blue}"
    local template="${4:=$(config_get VPN_TEMPLATE)}"

    _run qvm-create "${gw}" --property netvm="$netvm" --label "$gw_label" --template "$template"
    _catch "Failed to create VPN qube"

    _run qvm-prefs "${gw}" provides_network True
    print_new_qube "${gw}" "New VPN qube"

    # Tag the VM with its owner, and add the gateway to the list of proxies
    _run qvm-tags "$gw" set "$IDENTITY"
    identity.config_append PROXY_QUBES "${gw}"
}

# proxy.vpn_clone creates a new VPN gateway from an existing VPN AppVM
function proxy.vpn_clone ()
{
    local gw="${1}"
    local netvm="${2}"
    local gw_label="${3-blue}"
    local gw_clone="$4"

    _run qvm-clone "${gw_clone}" "${gw}"
    _catch "Failed to clone VM ${gw_clone}"

    # For now disposables are not allowed, since it would create too many VMs,
    # and complicate a bit the setup steps for VPNs. If the clone is a template
    # for disposables, unset it
    local disp_template
    disp_template=$(qvm-prefs "${gw}" template_for_dispvms)
    [[ "$disp_template" = "True" ]] && qvm-prefs "${gw}" template_for_dispvms False

    _run qvm-prefs "${gw}" provides_network True

    print_cloned_qube "${gw}" "${gw_clone}" "New VPN qube"

    # Tag the VM with its owner, and add the gateway to the list of proxies
    _run qvm-tags "$gw" set "$IDENTITY"
    identity.config_append PROXY_QUBES "${gw}"
}

# proxy.fail_config_vpn exits the program if risk lacks some information
# (which templates/clones to use) when attempting to create a VPN qube.
function proxy.fail_config_vpn ()
{
    local template clone netvm

    # Check qubes specified in config or flags.
    template="$(config_get VPN_TEMPLATE)"
    if [[ ${args['--clone']} -eq 1 ]]; then
        [[ -n ${args['--from']} ]] && clone=${args['--from']} || clone=$(config_get VPN_VM)
    fi

    # Check those qubes exist
    if [[ -n ${clone} ]]; then
        ! qube.exists "${clone}" && _failure "Qube to clone ${clone} does not exist"
    else
        ! qube.exists "${template}" && _failure "Qube template ${template} does not exist"
    fi
}

# proxy.skip_vpn_create returns 0 when there not enough information in the configuration
# file or in command flags for creating a new VPN qube (no templates/clones indicated, etc).
# Needs access to command-line flags
function proxy.skip_vpn_create ()
{
    local template clone netvm

    # Check qubes specified in config or flags.
    template="$(config_get VPN_TEMPLATE)"
    if [[ ${args['--clone']} -eq 1 ]]; then
        [[ -n ${args['--from']} ]] && clone=${args['--from']} || clone=$(config_get VPN_VM)
    fi

    [[ -z ${template} && -z ${clone} ]] && \
        _info "Skipping VPN qube: no TemplateVM/AppVM specified in config or flags" && return 0

    return 1
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

    # Select the file, return if empty
    config_path=$(_run_exec "$config_vm" "zenity --file-selection --title='VPN configuration selection' 2>/dev/null")
    [[ -z "$config_path" ]] && _info "Canceling setup: no file selected in VM $config_vm" && return

    _verbose "Copying file $config_path to VPN VM"
    qvm-run "$config_vm" "qvm-copy-to-vm $name $config_path" &>/dev/null

    # Now our configuration is the QubesIncoming directory of our VPN,
    # so we move it where the VPN will look for when starting.
    new_path="/home/user/QubesIncoming/${config_vm}/$(basename "$config_path")"

    # If the file is a zip file, unzip it in the configs directory
    # and immediately run the setup prompt to choose one.
    if [[ ${new_path:e} == "zip" ]]; then
        local configs_dir="/rw/config/vpn/configs"
        _info "Unzipping VPN configuration files into $configs_dir"
        qvm-run "$name" "sudo mkdir -p $configs_dir" &>/dev/null
        qvm-run "$name" "sudo unzip -d $configs_dir ${new_path}" &>/dev/null
        _run_exec "$name" /usr/local/bin/setup_VPN
    else
        _info "Copying file directly to the VPN client config path"
        _run_exec "$name" sudo mv "$new_path" "$client_conf_path"
    fi

    _info "Done transfering VPN client configuration to VM"
}

# proxy.vpn_next_name returns a name for a new VPN VM, such as vpn-1, where 
# the number is the next value after the ones found in existing VPN qubes.
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
    local found=false

    read -rA proxies < <(identity.proxy_qubes)
    for proxy in "${proxies[@]}" ; do
        if [[ $proxy == "$name" ]]; then
            found=true
        fi
    done

    if [[ $found != true ]]; then
        _info "VM $name is not listed as a VPN gateway. Aborting."
        exit 1
    fi
}
