
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

    # Set the identity directory
    IDENTITY_DIR="${RISK_IDENTITIES_DIR}/${IDENTITY}"
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

# identity.delete_home_director deletes the ~/.risk/identities/<identity> directory.
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

# identity.fail_none_active exits the program if there is no identity active or specified with args.
function identity.fail_none_active ()
{
    active_identity=$(qvm-run --pass-io "$VAULT_VM" 'risks identity active' 2>/dev/null)
    if [[ -n $active_identity ]]; then
        # It might be the same
        if [[ $active_identity == "$1" ]]; then
            _info "Identity $1 is already active"
            exit 0
        fi

        _failure "Identity $active_identity is active. Close/slam/fold it and rerun this command"
    fi
}

# identity.fail_unknown exits the program if an identity does not exist in the vault VM. 
# $1 - Identity name
function identity.fail_unknown ()
{
    # Get the resulting encrypted name
    local encrypted_identity
    encrypted_identity="$(_encrypt_filename "${IDENTITY}")"

    # And check the directory exists
    _run_exec "$VAULT_VM" "stat /home/user/.graveyard/$encrypted_identity &>/dev/null"
    _catch "Invalid identity: $1 does not exists in ${VAULT_VM}"
}

# Returns the name of the identity to which a VM belongs.
_vm_owner ()
{
    print "$(qvm-tags "$1" "$RISK_VM_OWNER_TAG" 2>/dev/null)"
}

# Returns the default network VM for the active identity
_identity_default_netvm ()
{
    cat "${IDENTITY_DIR}/netvm" 2>/dev/null
}

# Get the default VM label/color for an identity
_identity_default_vm_label ()
{
    cat "${IDENTITY_DIR}/vm_label" 2>/dev/null
}

# Get the TOR gateway for the identity
_identity_tor_gateway ()
{
    cat "${IDENTITY_DIR}/tor_gw" 2>/dev/null
}

# Get the browser VM for the identity
_identity_browser_vm ()
{
    cat "${IDENTITY_DIR}/browser_vm" 2>/dev/null
}

# _identity_proxies returns an array of proxy VMs
# (VPNs and TOR gateways for the current identity)
_identity_proxies ()
{
    [[ -f "${IDENTITY_DIR}/proxy_vms" ]] || return
    read -d '' -r -A proxies <"${IDENTITY_DIR}/proxy_vms"
    echo "${proxies[@]}"
}

# returns all identity VMs that are not gateways/proxies,
# but are potentially (most of the time) accessing network
# from one or more of these gateways.
_identity_client_vms ()
{
    [[ -f "${IDENTITY_DIR}/client_vms" ]] || return
    read -d '' -r -A clients <"${IDENTITY_DIR}/client_vms"
    echo "${clients[@]}"
}

# returns all identity VMs that are not gateways/proxies,
# but are potentially (most of the time) accessing network
# from one or more of these gateways.
_identity_autovm_starts ()
{
    [[ -f "${IDENTITY_DIR}/autovm_starts" ]] || return
    read -d '' -r -A clients <"${IDENTITY_DIR}/autovm_starts"
    echo "${clients[@]}"
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

    # Return either the mail flag with the name
    [[ -n "${email}" ]] && print "${name}@${email}"
    # Or the lowercase name without spaces
    print "${name// /_}"
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
