# Analyze the arguments and extract all VMs
# corresponding to those names/groups.
local vms=()
read -rA vms <<< $(_vm_args "${args['vms']}" "${other_args[@]}")

# Otherwise use templates of identity VMs
# if [[ "${args['--identity']}" -eq 1 ]]; then
# fi

# Update VMs
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
