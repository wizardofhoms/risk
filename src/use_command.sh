
local vm arguments

# Note that we concatenate all command arguments in a string (with *), to be passed to qvm-run
vm="${args['vm']}"
arguments="${other_args[@]}"

local owner active_identity
owner=$(_vm_owner "$vm")
active_identity="$(_identity_active_or_specified)"

# If the VM does not belong to any identity, then we don't have
# to interact with any of them, and this branch is skipped.
#
# However if the VM does not belong the active identity, we must:
if [[ -n "$owner" ]] && [[ $owner != "$active_identity" ]]; then
    # Close the active identity
    _info "Closing identity $active_identity"
    risk_identity_close_command

    # Open the new one
    args['identity']="$owner"
    risk_identity_open_command
fi

# At this point everything identity-related should be cleared and done.
_run_exec "$vm" "${arguments[@]}"
_catch "Failed to execute command in $vm:"
