
# ========================================================================================
# Identity setup / script values 
# ========================================================================================

# identity.set is used to propagate our various IDENTITY related variables
# so that all functions that will be subsequently called can access them.
# This function also takes care of checking if there is already an active
# identity that should be used, in case the argument is empty or none.
#
# $1 - The identity to use.
function identity.set ()
{
    local identity="$1"

    # This will throw an error if we don't have an identity from any source.
    IDENTITY=$(identity.active_or_specified "$identity")
    _catch "Command requires either an identity to be active or given as argument"

    # Other settings.
    IDENTITY_BOOKMARKS_FILE="/home/user/.tomb/mgmt/$(crypt.filename bookmarks.tsv)"
}

# identity.set_active sets the name as an ENV variable that we can use in further functions and commands.
# This function slightly differs from identity.set in that it does not set the active identity and its
# values in the script run itself: it only populates stuff that is to be used in other calls of risks.
#
# $1 - The name to use. If empty, just resets the identity.
function identity.set_active ()
{
    # If the identity is empty, wipe the identity file
    if [[ -z ${1} ]] && [[ -e ${RISK_IDENTITY_FILE} ]]; then
        identity=$(cat "${RISK_IDENTITY_FILE}")
        rm "${RISK_IDENTITY_FILE}" || _warning "Failed to wipe identity file !"

        _verbose "Identity '${identity}' is now inactive, (name file deleted)"
        _info "Identity '${identity}' is now INACTIVE"
        return
    fi


    # If we don't have a file containing the
    # identity name, populate it.
    if [[ ! -e ${RISK_IDENTITY_FILE} ]]; then
        print "$1" > "${RISK_IDENTITY_FILE}"
    fi

    _verbose "Identity '${1}' is now active (name file written)"
    _info "Identity '${1}' is now ACTIVE"
}

# identity.active returns the name of the vault active identity.
function identity.active ()
{
    qvm-run --pass-io "$VAULT_VM" 'risks identity active' 2>/dev/null
}

# identity.is_active returns 0 if an identity is unlocked, 1 if not.
function identity.is_active ()
{
    local active_identity

    active_identity=$(qvm-run --pass-io "$VAULT_VM" 'risks identity active' 2>/dev/null)
    if [[ -z "${active_identity}" ]]; then
        return 1
    fi

    return 0
}

# identity.active_or_specified checks that either an identity is active,
# or that the passed argument is not empty. If the identity is not empty
# it is echoed back to the caller.
#
# $1 - An identity name
#
# Returns:
# 0 - Identity is non-nil, provided either from arg or by the active
# 1 - None have been given
function identity.active_or_specified ()
{
    local active_identity

    if [[ -z "${1}" ]] ; then
        active_identity=$(qvm-run --pass-io "$VAULT_VM" 'risks identity active' 2>/dev/null)
        if [[ -z "${active_identity}" ]]; then
            return 1
        fi
    fi

    # Print the identity
    if [[ -n "${1}" ]]; then
        print "${1}" && return
    fi

    print "$active_identity"
}

# identity.get_args_name either returns the name given as parameter, or
# generates a random (burner) one and prints it to the screen.
function identity.get_args_name ()
{
    local name

    if [[ -z "${1}" ]] && [[ "${args['--burner']}" -eq 0 ]]; then
        _failure "Either an identity name is required, or the --burner flag"
    fi

    # Either use the provided one
    if [[ -n "${1}" ]]; then
        name="${1}"
    elif [[ "${args['--burner']}" -eq 1 ]]; then
        name="$(rig -m | head -n 1)"
        name="${name// /_}"
    fi

    print "${name}"
}

# identity.get_args_mail returns a correctly formatted mail given either a fully specified
# one as positional, or a generated/concatenated one from the username argument.
function identity.get_args_mail ()
{
    local name="$1"
    local email="$2"

    [[ -n "${email}" ]] && print "${email}" && return

    email="${args['--mail']}"

    if [[ -n "${email}" ]]; then
        # Return either the mail provider flag with the name
        print "${name}@${email}"
    else
        # Or the lowercase name without spaces
        print "${name// /_}"
    fi
}

# identity.get_args_expiry returns a correctly formatted expiry date for a GPG key.
# If no arguments are passed to the call, the expiry date is never.
function identity.get_args_expiry ()
{
    local expiry

    if [[ -z "${1}" ]]; then
        expiry_date="never"
    else
        expiry="${1}"
        expiry_date="$(date +"%Y-%m-%d" --date="${expiry}")"
    fi

    print "${expiry_date}"
}

# identity.delete_home_directory deletes the ~/.risk/identities/<identity> directory.
function identity.delete_home_directory ()
{
    if ! _identity_active ; then
        return
    fi
    if [[ -z "${IDENTITY_DIR}" ]]; then
        return
    fi

    _info "Deleting identiy ${IDENTITY} home directory"
    _run -rf "${IDENTITY_DIR}"
}


# ========================================================================================
# Identity failsafes / checks
# ========================================================================================

# identity.fail_none_active exits the program if there is no identity active or specified with args.
function identity.fail_none_active ()
{
    active_identity=$(qvm-run --pass-io "$VAULT_VM" 'risks identity active' 2>/dev/null)
    [[ -z "${active_identity}" ]] && _failure "No active identity in vault"
}

# identity.fail_other_active exits the program if another identity is already active (opened in vault).
function identity.fail_other_active ()
{
    active_identity=$(qvm-run --pass-io "$VAULT_VM" 'risks identity active' 2>/dev/null)

    if [[ -n $active_identity ]]; then
        if [[ $active_identity == "$IDENTITY" ]]; then
            return
        fi

        _failure "Identity $active_identity is active. Close/slam/fold it and rerun this command"
    fi
}

# identity.fail_unknown exits the program if an identity does not exist in the vault VM. 
# $1 - Identity name
function identity.fail_unknown ()
{
    # Attempt to resolve the coffin with the name
    encrypted_identity="$(qvm-run --pass-io "${VAULT_VM}" "risks resolve coffin ${IDENTITY}")"

    # And check the directory exists
    _run_exec "$VAULT_VM" "stat ${encrypted_identity} &>/dev/null"
    _catch "Invalid identity: $IDENTITY does not exists in ${VAULT_VM}"
}

# identity.fail_exists exits the program if the given identity name already exists in the vault.
function identity.fail_exists ()
{
    # Get the resulting encrypted name
    local encrypted_identity
    encrypted_identity="$(crypt.filename "${IDENTITY}")"

    # And check the directory exists
    qvm-run --pass-io "$VAULT_VM" "stat /home/user/.graveyard/$encrypted_identity &>/dev/null"
    [[ $? -eq 0 ]] && _failure "Identity ${IDENTITY} already exists in ${VAULT_VM}"
}


# ========================================================================================
# Identity configuration values 
# ========================================================================================

# identity.set_global_props analyzes the command-line flags and uses some of them
# to configure stuff about the identity's qubes, such as their colors/prefixes/netvms, etc.
# Requires access to command-line flags, and needs $IDENTITY to be set.
function identity.set_global_props ()
{
    [[ -z "${IDENTITY}" ]] && return

    local prefix label

    _warning "Global identity qubes settings"

    # Qube name prefix
    prefix="${args['--prefix']-$IDENTITY}"
    _info "VM prefix:    $prefix"
    identity.config_set QUBE_PREFIX "${prefix}"

    # Qube labels (colors)
    label="${args['--label']-orange}"
    _info "Label:        $label"
    identity.config_set QUBE_LABEL "${label}"

    # Default network VM
    identity.config_set NETVM_QUBE "$(config_get DEFAULT_NETVM)"
}

# identity.config_set uses 'risks kv set' in vault to store a key-value pair.
function identity.config_set ()
{
    identity.is_active || return

    local key="${1}"
    shift
    local value="$*"

    [[ -z "${key}" || -z "${value}" ]] && return

    _run_qube "$VAULT_VM" risks kv set "${key}" "${value}"
}

# identity.config_get uses 'risks kv get' in vault to retrieve a key-value pair.
function identity.config_get ()
{
    identity.is_active || return

    local key="${1}"
    [[ -z "${key}" ]] && return

    _run_exec "$VAULT_VM" risks kv get "${key}"
}

# identity.config_unset uses 'risks kv unset' in vault to delete a key-value pair.
function identity.config_unset ()
{
    identity.is_active || return

    local key="${1}"
    [[ -z "${key}" ]] && return

    _run_qube "$VAULT_VM" risks kv unset "${key}"
}

# identity.config_append uses 'risks kv set' and 'risks kv get' to append a value
# to an existing key-value pair (as an array), or creates it if does not exist yet.
function identity.config_append ()
{
    identity.is_active || return

    local key="${1}"
    shift
    local value="$*"

    [[ -z "${key}" || -z "${value}" ]] && return

    _run_qube "$VAULT_VM" risks kv append "${key}" "${value}"
}

# identity.config_reduce uses 'risks kv get', 'risks kv get' and 'sed' to remove a 
# value from an existing key-value pair (as an array) in the vault key-value store.
function identity.config_reduce ()
{
    identity.is_active || return

    local key="${1}"
    shift
    local values=("$@")

    [[ -z "${key}" || -z "${values[*]}" ]] && return

    _run_qube "$VAULT_VM" risks kv filter "${key}" "${values[@]}"
}

# identity.config_clear uses 'risks kv clean' in vault to clear all key-value pairs.
function identity.config_clear ()
{
    identity.is_active || return

    _run_qube "$VAULT_VM" risks kv clean
}


# ========================================================================================
# Virtual machines / equipment functions
# ========================================================================================

# identity.netvm returns the default network VM for the active identity
function identity.netvm ()
{
    identity.config_get NETVM_QUBE 2>/dev/null
}

# identity.vm_label returns the default VM label/color for an identity
function identity.vm_label ()
{
    identity.config_get QUBE_LABEL 2>/dev/null
}

# identity.tor_gateway returns the TOR gateway for the identity
function identity.tor_gateway ()
{
    identity.config_get TOR_QUBE 2>/dev/null
}

# identity.browser_qube returns the browser VM for the identity
function identity.browser_qube ()
{
    identity.config_get BROWSER_QUBE 2>/dev/null
}

# identity.proxy_qubes returns an array of proxy VMs
# (VPNs and TOR gateways for the current identity)
function identity.proxy_qubes ()
{
    local proxy_qubes
    proxy_qubes=$(identity.config_get PROXY_QUBES)
    [[ -n "${proxy_qubes}" ]] || return

    read -d '' -rA proxies <<< "${proxy_qubes}"
    echo "${proxies[@]}"
}

# identity.client_qubes returns all identity VMs that are not gateways/proxies,
# but are potentially (most of the time) accessing network from one or more of 
# these gateways.
function identity.client_qubes ()
{
    local client_qubes
    client_qubes=$(identity.config_get CLIENT_QUBES)
    [[ -n "${client_qubes}" ]] || return

    read -d '' -rA clients <<< "${client_qubes}"
    echo "${clients[@]}"
}

# identity.enabled_qubes returns all identity VMs that are 
# not gateways/proxies, but are potentially (most of the time) 
# accessing network from one or more of these gateways.
function identity.enabled_qubes ()
{
    local autostart_qubes
    autostart_qubes=$(identity.config_get AUTOSTART_QUBES)
    [[ -n "${autostart_qubes}" ]] || return

    read -d '' -rA clients <<< "${autostart_qubes}"
    echo "${clients[@]}"
}

# identity.shutdown_qubes powers off all running VMs belonging to the identity.
function identity.shutdown_qubes ()
{
    local clients proxies tor_gateway browser_vm other_vms

    # Client VMs
    read -rA clients < <(identity.client_qubes)
    for vm in "${clients[@]}" ; do
        [[ $(qube.is_running "${vm}") -gt 0 ]] && continue

        [[ -z "${vm}" ]] && continue

        _info "Shutting down $vm"
        qube.shutdown "$vm"
    done

    # Browser VMs (disposables to find from template/tag)
    browser_vm="$(identity.browser_qube)"
    if [[ -n "${browser_vm}" ]]; then
        if qube.is_running "${browser_vm}"; then
            _info "Shutting down $browser_vm"
            qube.shutdown "$browser_vm"
        fi
    fi

    # Proxy VMs
    read -rA proxies < <(identity.proxy_qubes)
    for vm in "${proxies[@]}" ; do
        [[ -z "${vm}" ]] && continue
        [[ $(qube.is_running "${vm}") -gt 0 ]] && continue

        _info "Shutting down $vm"
        qube.shutdown "$vm"
    done

    # Tor gateway.
    tor_gateway="$(identity.tor_gateway)"
    if [[ -n "${tor_gateway}" ]]; then
        if qube.is_running "${tor_gateway}"; then
            _info "Shutting down $tor_gateway"
            qube.shutdown "$tor_gateway"
        fi
    fi

    # Other VMs that are tagged with the identity.
    read -rA other_vms < <(qubes.list_all)
    for vm in "${other_vms[@]}" ; do
        [[ -z "${vm}" ]] && continue

        if qube.is_running "${vm}"; then
            if [[ "$(qube.owner "${vm}")" == "${IDENTITY}" ]]; then
                _info "Shutting down $vm"
                qube.shutdown "$vm"
            fi
        fi
    done
}

# identity.delete_qubes deletes all VMs belonging to an identity.
function identity.delete_qubes ()
{
    local clients proxies tor_gateway browser_vm other_vms

    # Client VMs
    read -rA clients < <(identity.client_qubes)
    for client in "${clients[@]}"; do
        qube.delete "${client}" CLIENT_QUBES
    done
    identity.config_unset CLIENT_QUBES

    # Browser VM
    browser_vm="$(identity.browser_qube)"
    if [[ -n "${browser_vm}" ]]; then
        qube.delete "${browser_vm}" BROWSER_QUBE
        identity.config_unset BROWSER_QUBE
    fi

    # Proxy VMs
    read -rA proxies < <(identity.proxy_qubes)
    for proxy in "${proxies[@]}"; do
        qube.delete "${proxy}" PROXY_QUBES
    done
    identity.config_unset PROXY_QUBES

    # Tor gateway.
    tor_gateway="$(identity.tor_gateway)"
    if [[ -n "${tor_gateway}" ]]; then
        qube.delete "${tor_gateway}" TOR_QUBE
        identity.config_unset TOR_QUBE
    fi

    # Other VMs that are tagged with the identity.
    read -rA other_vms < <(qubes.list_all)
    for vm in "${other_vms[@]}"; do
        if [[ "$(qube.owner "${vm}")" == "${IDENTITY}" ]]; then
            qube.delete "${vm}"
        fi
    done
}

