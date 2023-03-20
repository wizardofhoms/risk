
name="${args['identity']}"
name="$(identity.get_args_name "${name}")"
identity="${name// /_}"
email="$(identity.get_args_mail "${name}" "${args['email']}")"
pendrive="${args['--backup']}"

local other_args

# 0 - Safety checks --------------------------------------------------------------

# The identity should not exist, and none other should be active.
identity.set "${identity}"
identity.fail_other_active
identity.fail_exists

# 1 - Create identity in vault ---------------------------------------------------
_in_section "identity" 8 && _info "Creating identity in vault"

[[ -n "${args['expiry_date']}" ]] && other_args+=( "${args['expiry_date']}" )
[[ -n "$pendrive" ]] && other_args=(--backup "$pendrive")
[[ "${args['--burner']}" -eq 1 ]] && other_args+=( --burner )

_run_qube_term "$VAULT_VM" risks identity create "'$name'" "$email" "${other_args[@]}"
_catch "Failed to create identity in vault"

_run_qube_term "$VAULT_VM" risks identity open "$identity"
_catch "Failed to open identity in vault"

# If the user only wanted to create the identity in the vault, exit.
if [[ ${args['--vault-only']} -eq 1 ]] ; then
    _info "Skipping infrastructure setup"
    _success "Successfully created identity $identity"
    exit
fi

# 2 - Create all default qubes ---------------------------------------------------
risk_identity_equip_command
