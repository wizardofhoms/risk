
# ========================================================================================
# Virtual machines / equipment functions
# ========================================================================================

# Create a web browsing VM from a template
function web.browser_create ()
{
    local web="${1}-web"
    local web_netvm="${2-$(config_get DEFAULT_NETVM)}"
    local web_label="${3-orange}"
    local ws_template="$(config_get WHONIX_WS_TEMPLATE)"
    local template_disp="$(qvm-prefs "${ws_template}" template_for_dispvms 2>/dev/null)"

    _info "Creating web browsing VM (name: $web / netvm: $web_netvm / template: $ws_template)"
    local create_command=(qvm-create "${web}" --property netvm="$web_netvm" --label="$web_label" --template="$ws_template")

    # If the template used is a disposable_template,
    # this means we must create a named disposable VM.
    if [[ "${template_disp}" == True ]]; then
        create_command+=(--class DispVM)
    fi

    # Generate the VM
    "${create_command[@]}"
    if [[ $? -gt 0 ]]; then
        _warning "Failed to create browser VM $web" && return
    fi

    # Mark this VM as a disposable template, and tag it with our identity
    if [[ "${template_disp}" != True ]]; then
        qvm-prefs "${web}" template_for_dispvms True
    fi

    _run qvm-tags "$web" set "$IDENTITY"
    echo "${web}" > "${IDENTITY_DIR}/browser_vm"
}

# Clone a web browsing VM from an existing one
function web.browser_clone ()
{
    local web="${1}-web"
    local web_clone="$2"
    local netvm="${3-$(config_get DEFAULT_NETVM)}"
    local web_label="${4-orange}"

    _info "Cloning web browsing VM (name: $web / netvm: $netvm / template: $web_clone)"
    _run qvm-clone "${web_clone}" "${web}"
    if [[ $? -gt 0 ]] ; then
        _warning "Failed to clone browser VM $web" && return
    fi

    _run qvm-prefs "$web" label "$web_label"
    _run qvm-prefs "$web" netvm "$netvm"

    # Only mark this VM as disposable template when it's not one already.
    if [[ "$(qvm-prefs "${ws_template}" template_for_dispvms 2>/dev/null)" == False ]]; then
        _run qvm-prefs "${web}" template_for_dispvms True
    fi

    _run qvm-tags "$web" set "$IDENTITY"
    echo "${web}" > "${IDENTITY_DIR}/browser_vm"
}

# Create a split-browser VM from a template
function web.split_backend_create ()
{
    local web="${1}-split-web"
    local web_label="${2-gray}"
    local split_template="$(config_get SPLIT_BROWSER_TEMPLATE)"

    _info "Creating split-browser (name: $web / netvm: $netvm / template: $split_template)"
    qvm-create --property netvm=None --label "$web_label" --template "$split_template"

    qvm-tags "$web" set "$IDENTITY"
    echo "${web}" > "${IDENTITY_DIR}/browser_vm"
}

# Clone an existing split-browser VM, and change its dispvms
function web.split_backend_clone ()
{
    local web="${1}-split-web"
    local web_clone="$2"
    local web_label="${3-gray}"

    _info "Cloning split-browser VM (name: $web / netvm: $netvm / template: $web_clone)"
    qvm-clone "${web_clone}" "${web}"

    qvm-prefs "$web" label "$web_label"
    qvm-prefs "$web" netvm None

    qvm-tags "$web" set "$IDENTITY"
}

# web.browser_set_split_dispvm updates the default disposable VM
# used by the split browser backend to use the active identity's one.
function web.browser_set_split_dispvm ()
{
    local browser_vm
    browser_vm=$(cat "${IDENTITY_DIR}/browser_vm" 2>/dev/null)

    if [[ -n "${browser_vm}" ]]; then
        _info "Setting identity browser VM with split-browser"
        qvm-prefs "$(config_get SPLIT_BROWSER)" default_dispvm "${browser_vm}"
    fi
}

# web.browser_unset_split_dispvm removes the dispvm setting of the
# tor split-browser backend if it is set to the identity browser VM.
function web.browser_unset_split_dispvm ()
{
    local browser_vm
    browser_vm=$(cat "${IDENTITY_DIR}/browser_vm" 2>/dev/null)

    if [[ -z "${browser_vm}" ]]; then
        return
    fi

    if [[ "$(qvm-prefs "$(config_get SPLIT_BROWSER)" default_dispvm)" == "${browser_vm}" ]]; then
        qvm-prefs "$(config_get SPLIT_BROWSER)" default_dispvm ''
    fi
}

# ========================================================================================
# Browsing activities and data
# ========================================================================================
#
# web.bookmark_create_system writes and encrypts a file to store all-users bookmarks.
function web.bookmark_create_system ()
{
    local filename="bookmarks.tsv"

    # A hush device should be mounted.

    # If the file exists, return

    # Ask for a password to use, or generate a random seed to use for the encryption.

    # Get an encrypted name for the file.

    # And create it.
}

# web.bookmark_create_system writes and encrypts a file to store per-user bookmarks.
function web.bookmark_create_file ()
{
    local filename="$(crypt.filename "bookmarks.tsv")"
    bookmarks_path="/home/user/.tomb/mgmt/${filename}"
    _run_exec "$VAULT_VM" "touch ${bookmarks_path}"
}

# web.bookmark_create_system writes and encrypts a file for blacklisted links.
function web.blacklist_create_file ()
{
    echo
}

# web.bookmark_display_command returns a command string
# to use as the dmenu displayer of a bookmarks file.
function web.bookmark_display_command ()
{
    # This command will not work if qubes-split-browser is not installed in the split-browser VM
    local window_focus_command='_NET_WM_NAME="Split Browser" x11-unoverride-redirect stdbuf -oL'

    if [[ -n "$(config_get BOOKMARKS_DMENU_COMMAND)" ]]; then
        echo "${window_focus_command} $(config_get BOOKMARKS_DMENU_COMMAND)"
    else
        echo "${window_focus_command} dmenu -i -l 20 -b -p 'RISKS Bookmark'"
    fi
}

# web.bookmarks_file_is_empty returns 0 if no bookmark
# file exists in split-browser or if it is empty.
function web.bookmarks_file_is_empty ()
{
    local split_command contents
    split_command=( qvm-run --pass-io "$(config_get SPLIT_BROWSER)" "cat .local/share/split-browser/bookmarks.tsv" )
    if ! "${split_command[@]}" &>/dev/null; then
        return 0
    fi

    contents="$("${split_command[@]}")"
    if [[ -z "${contents}" ]]; then
        return 0
    fi

    return 1
}

# web.bookmarks_select prompts the user with bookmarks,
# and returns the URL extracted from the selection.
function web.bookmarks_select ()
{
    local bookmarks_command result

    # bookmark_prompt=( $(web.bookmark_display_command) )
    bookmarks_command='export SB_CMD_INPUT=bookmark; touch $SB_CMD_INPUT; split-browser-bookmark get'
    qvm-run --pass-io "${vm}" "${bookmarks_command}"
    result="$(qvm-run --pass-io "${vm}" cat bookmark)"
    print "$result" | awk '{print $2}'
}

# web.bookmark_pop prompts the user with bookmarks, returns the URL
# extracted from the selection and deletes the line in the file.
# Returns the complete bookmark entry.
function web.bookmark_pop ()
{
    local bookmarks_command result bookmark_line vm
    bookmark_file=".local/share/split-browser/bookmarks.tsv"
    vm="$(config_get SPLIT_BROWSER)"

    # Get the URL
    bookmarks_command='export SB_CMD_INPUT=bookmark; touch $SB_CMD_INPUT; split-browser-bookmark get'
    qvm-run --pass-io "${vm}" "${bookmarks_command}"
    result=$( qvm-run --pass-io "${vm}" cat bookmark | awk '{print $2}')
    qvm-run --pass-io "${vm}" "rm bookmark"

    # Get the entire line, with the title and timestamp.
    bookmark_line="$(qvm-run --pass-io "${vm}" "cat ${bookmark_file}")"
    line="$(echo "${bookmark_line}" | grep "${result}")"

    # Abort if the user did not select anything
    [[ -z "${result}" ]] && return

    # Remove the line from the file.
    remove_command="sed -i '\#${result}#d' .local/share/split-browser/bookmarks.tsv"
    qvm-run --pass-io "${vm}" "${remove_command}"

    print "${line}"
}

# get_browser_vm_from requires a VM name to be passed as argument.
# If this VM is a disposable based on the identity's browser VM,
# the argument is returned, otherwise the identity's browser VM.
get_browser_vm_from ()
{
    echo
}

