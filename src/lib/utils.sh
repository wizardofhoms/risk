
# Return 0 if is set, 1 otherwise
option_is_set() {
	local -i r	 # the return code (0 = set, 1 = unset)

	[[ -n ${(k)OPTS[$1]} ]];
	r=$?

	[[ $2 == "out" ]] && {
		[[ $r == 0 ]] && { print 'set' } || { print 'unset' }
	}

	return $r;
}

# Retrieves the value of a variable first by looking in the risk
# config file, and optionally overrides it if the flag is set.
# $1 - Flag argument
# $2 - Key name in config
config_or_flag ()
{
    local value config_value

    config_value=$(config_get $2)   # From config
    value="${1:=$config_value}"      # overriden by flag if set

    print $value
}

# contains(string, substring)
#
# Returns 0 if the specified string contains the specified substring,
# otherwise returns 1.
contains() {
    string="$1"
    substring="$2"
    if test "${string#*$substring}" != "$string"
    then
        return 0    # $substring is in $string
    else
        return 1    # $substring is not in $string
    fi
}

# prompt_question asks the user to answer a question prompt.
# $@ - A question string.
prompt_question ()
{
    printf >&2 '%s ' "$*" 
    read -r ans
    echo "${ans}"
}

# print_new_qube is used to display the properties of a newly created qube.
# $1 - Name
# $2 - Message to display above properties
print_new_qube ()
{
    local name="$1"
    local template netvm

    qvm-ls "${name}" &>/dev/null || return

    template=$(qvm-prefs "${name}" template)
    netvm=$(qvm-prefs "${name}" netvm)

    [[ -n "${2}" ]] && _info "${2}"
    _info "Name:       ${fg_bold[white]} $name ${reset_color}"
    _info "Netvm:      ${fg_bold[white]} $netvm ${reset_color}"
    _info "Template:   ${fg_bold[white]} $template ${reset_color}"
}

# print_new_qube is used to display the properties of a newly cloned qube.
# $1 - Name
# $2 - Clone name
# $2 - Message to display above properties
print_cloned_qube ()
{
    local name="$1"
    local clone="$2"
    local netvm

    qvm-ls "${name}" &>/dev/null || return

    netvm=$(qvm-prefs "${name}" netvm)

    [[ -n "${3}" ]] && _info "${3}"
    _info "Name:          ${fg_bold[white]} $name ${reset_color}"
    _info "Netvm:         ${fg_bold[white]} $netvm ${reset_color}"
    _info "Cloned from:   ${fg_bold[white]} $clone ${reset_color}"
}
