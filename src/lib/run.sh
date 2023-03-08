
COMMAND_STDOUT=''           # Stores a command's stdout output.
COMMAND_STDERR=''           # Stores a command's stderr output.   

# do a command, splitting and storing stdout/stderr output and printing
# the former to screen only if the command is ran with verbose flag.
# Returns the command's exit code, so we can catch any errors and inform.
_run ()
{
    # The STDOUT/STDERR variables are populated, which
    # makes their content available to any subsequent call
    # to _failure, which needs STDERR output
    {
        IFS=$'\n' read -r -d '' COMMAND_STDERR;
        IFS=$'\n' read -r -d '' COMMAND_STDOUT;
        (IFS=$'\n' read -r -d '' _ERRNO_; exit "${_ERRNO_}");
    } < <((printf '\0%s\0%d\0' "$("$@")" "${?}" 1>&2) 2>&1)

    local ret="$?"

    # Output the command's result depending on the verbose mode
    # and if the command ran successfully. We check that either
    # stdout or stderr are non-empty: sometimes commands might
    # output to stderr, like wipe.
    if [[ $ret -eq 0 ]] && is_verbose_set ; then
        if [[ -n "$COMMAND_STDOUT" ]]; then
            _verbose "$COMMAND_STDOUT"
        fi
    fi

    # Return the command's exit code
    return $ret
}

# run a command in a qube
# $1 - Qube name
# $@ - Command string to run
_run_qube () 
{
    local vm="$1" ; shift
    local command="$*"
    local terminal shell shell_command full_command

    # Prepare the full command
    terminal="$(config_get VM_TERMINAL)"
    shell="$(config_get VM_SHELL)"
    # shell_command='zsh -c "'"$command"'"'
    shell_command="${shell} -c '$command'"
    full_command=(qvm-run --pass-io "$vm" "$shell_command")

    _verbose "Running command: ${full_command[*]}"

    # Split io like in _run, and store the return value
    # Note that we don't double quote the $full_command variable.
    {
        IFS=$'\n' read -r -d '' COMMAND_STDERR;
        IFS=$'\n' read -r -d '' COMMAND_STDOUT;
        (IFS=$'\n' read -r -d '' _ERRNO_; exit "${_ERRNO_}");
    } < <((printf '\0%s\0%d\0' "$( "${full_command[@]}" )" "${?}" 1>&2) 2>&1)

    local ret="$?"

    # Output the command's result depending on the verbose mode
    # and if the command ran successfully like in _run also.
    if [[ $ret -eq 0 ]] && is_verbose_set ; then
        if [[ -n "$COMMAND_STDOUT" ]]; then
            _verbose "$COMMAND_STDOUT"
        fi
    fi

    return $ret
}

# _run_exec is a simplified version of _run_qube, without stdout/err split & store.
_run_exec () 
{
    local vm="$1"
    shift
    local command="$*"

    # If we don't have any command arguments, we run the default terminal
    [[ -z "$command" ]] && command="$VM_TERMINAL"

    _verbose "Running command: ${command}"

    # Run the command raw, so that we get the output as it is.
    qvm-run --pass-io "$vm" "${command}"
}

# _run_qube_term spawns a terminal on a target qube, with an associated command to run.
_run_qube_term () 
{
    local vm="$1" ; shift
    local command="$*"
    local terminal shell shell_command

    # Prepare the full command
    terminal="$(config_get VM_TERMINAL)"
    shell="$(config_get VM_SHELL)"
    shell_command="${shell} -c '$command'"

    # Run the raw command, so that we get the output as it is.
    qvm-run --pass-io "$vm" "$terminal" -e "$shell_command"
}

# Checks the return code of a command, and if not successful,
# fails with the associated error message. Usage:
# catch $ret "hush" "Failed to execute this command"
function _catch ()
{
    local ret="$?" 

    if [[ ! $ret -eq 0 ]]; then
        _failure "$@"
    fi
}
