# Analyze the arguments and extract all VMs
# corresponding to those names/groups.
read -rA vms < <(qube.command_args "${args['vms']}" "${other_args[@]}")

# Update matching VMs.
if [[ -n "${vms[*]}" ]]; then
    _info "Updating following VMs:"
    for template in "${vms[@]}"; do
            _info "$template"
    done

    printf -v targets '%s,' "${vms[@]}"
    _run sudo qubesctl --skip-dom0 --targets "${targets%,}" state.apply update.qubes-vm
fi

# Update dom0 if required
if [[ ${args['vms']} == dom0 ]] || [[ ${other_args[(r)dom0]} == dom0 ]]; then
    _info "Updating dom0"
    sudo qubes-dom0-update
fi

# If torbrowser update is required, get identity browsing VM template and update
# We need to know for which identity to update, so we need one active.
if [[ ${args['vms']} == torbrowser ]] || [[ ${other_args[(r)torbrowser]} == torbrowser ]]; then
    identity.set 

    local browser_vm browser_template
    browser_vm="$(identity.browser_qube)"

    if [[ -n "${browser_vm}" ]]; then
        browser_template="$(qube.root_template "${browser_vm}")"
        _info "Updating Tor browser in ${browser_template}"
        _run_qube_term "${browser_template}" sudo update-torbrowser
    fi
fi
