
## Variables ##

# If the user wants to log command output to a file.
risk_log_file=""

# Section is set either by functions or simple calls,
# so that logging can inform on the component working.
section='risk'

# When multiple sections are used within a single risks
# operation, we padd them, for clearer/better aesthetics.
section_padding=6

# Last log level used. Inline logging uses this.
last_level="message"

# maps levels to their display color
declare -A log_colors
log_colors=(
    [verbose]="blue"
    [message]="default"
    [warning]="yellow"
    [success]="green"
    [failure]="red"
)

# maps levels to notice characters.
declare -A log_chars
log_chars=(
    [inline]=" > "
    [verbose]="[D]"
    [message]=" . "
    [warning]="[W]"
    [success]="(*)"
    [failure]="[E]"
)

## Functions ##

# _init_log_file creates the log file if does not exist,
# and exits the script in case of failure, or if the file
# is not writable.
function _init_log_file ()
{
    risk_log_file="${args['--log-file']}"
    [[ -z "${risk_log_file}" ]] && return

    # Ensure not a directory, and if exists, is writable.
    if [[ -d "${risk_log_file}" ]] ; then
        risk_log_file=''
        _failure "Log file ${risk_log_file} is a directory"
    elif [[ -e "${risk_log_file}" ]] && [[ ! -w "${risk_log_file}" ]]; then
        risk_log_file=''
        _failure "Log file ${risk_log_file} is not writable"
    fi

    # Create the file if not existing, or fail.
    if [[ ! -e "${risk_log_file}" ]]; then
        _run touch "${risk_log_file}"
        _catch "Failed to create log file ${risk_log_file}"
        _info "Logging command output to file ${risk_log_file}"
    fi
}

# Simple way of setting the section and to update the padding
_in_section ()
{
    section="$1"
    if [[ "${#1}" -gt "${section_padding}" ]]; then
        section_padding="${#1}"
    fi

    if [[ -n "${2}" ]]; then
        section_padding="$2"
    fi
}

function is_verbose_set () 
{
    if [[ "${args['--verbose']}" -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

# Messaging function with pretty coloring
function _msg ()
{
    # Check if we have been provided a section name,
    # and if not, that the section is set to a default.
    if [[ ${#@} -lt 3 ]]; then
        local progname="$section"
        if [[ -z "$progname" ]]; then
            progname='risk'
        fi
        local msg="$2"
    else
        local progname="$2"
        local msg="$3"
    fi

    # Padd the program/section name
    progname="$(printf %"${section_padding}"s "${progname}")"

    # Apply any translation for non-english users
	# local i
	# command -v gettext 1>/dev/null 2>/dev/null && msg="$(gettext -s "$3")"
	# for i in {3..${#}}; do
	# 	msg=${(S)msg//::$(($i - 2))*::/$*[$i]}
	# done

    # Apply log chars & color
    local pcolor=${log_colors[$1]}
    local pchars=${log_chars[$1]}

    # Use the display of last message when inline
    [[ "$1" == "inline" ]] && { pcolor=${log_colors[$last_level]}; pchars=${log_chars[inline]} }
    last_level="$1"

	local command="print -P"
	local fd=2
	local -i returncode

	case "$1" in
		inline)
			command+=" -n"
			;;
		failure)
			returncode=1
			;;
		print)
			progname=""
			fd=1
			;;
		# *)
		# 	pchars="[F]"; pcolor="red"
		# 	msg="Developer oops!  Usage: _msg MESSAGE_TYPE \"MESSAGE_CONTENT\""
		# 	returncode=127
			# ;;
	esac

	[[ -n $_MSG_FD_OVERRIDE ]] && fd=$_MSG_FD_OVERRIDE

    # If there is a log-file specified, write the output to it. 
    if [[ -n "${risk_log_file}" ]]; then
        ${=command} "${progname}" "${pchars}" "${msg}" >> "$risk_log_file"
    fi

    # Else, print to stdout, with colors
	if [[ -t $fd ]]; then
       [[ -n "$progname" ]] && progname="${fg[magenta]}$progname$reset_color"
       [[ -n "$pchars" ]] && pchars="${fg_bold[$pcolor]}$pchars$reset_color"
       msg="$fg[$pcolor]$msg$reset_color"
	fi

    ${=command} "${progname}" "${pchars}" "${msg}" >&"$fd"
	return $returncode
}

function _info () 
{
	local notice="message"
	[[ "$1" = "-n" ]] && shift && notice="inline"
    option_is_set -q || _msg "$notice" "$@"
	return 0
}

function _verbose () 
{
    is_verbose_set && _msg verbose "$@"
	return 0
}

function _success() 
{
    option_is_set -q || _msg success "$@"
	return 0
}

function _warning () 
{
    option_is_set -q || _msg warning "$@"
	return 1
}

# failure first prints the message we have passed following the catch
# of an error exit code, and then looks at the contents of erroring
# command's stderr buffer, which is printed just below our message.
# We then exit the program.
function _failure ()
{
	typeset -i exitcode=${exitv:-1}

    _msg failure "$@"

    # Trim the message from any risks/risq header and print
    if [[ -n "$COMMAND_STDERR" ]]; then
        stderr=$(sed -r 's/^(risks|risq) \[[^][]*\]//' <<< "${COMMAND_STDERR}")
        stderr=$(sed -r 's/^(risks|risq)[ ]{1,}>//' <<< "${stderr}")
        stderr=$(sed -r 's/^[ ]{1,}//' <<< "${stderr}")

        _msg inline "$stderr"
    fi

	# Be sure we forget the secrets we were told
    exit "$exitcode"
}

# function _failure() {
# 	typeset -i exitcode=${exitv:-1}
#     option_is_set -q || _msg failure "$@"
# 	# be sure we forget the secrets we were told
#     exit "$exitcode"
# }

function _print () 
{
    option_is_set -q || _msg print "$@"
	return 0
}

