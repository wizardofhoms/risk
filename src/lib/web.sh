# ========================================================================================
# Client browser qubes 
# ========================================================================================

# web.client.create creates a web browsing VM from a template.
function web.client.create ()
{
    local web="${1}-web"
    local netvm="${2-$(identity.config_get NETVM_QUBE)}"
    local label="${3-orange}"

    local template template_disp
    template="$(config_get WHONIX_WS_TEMPLATE)"
    template_disp="$(qvm-prefs "${template}" template_for_dispvms 2>/dev/null)"

    # If the template used is a disposable_template,
    # this means we must create a named disposable VM.
    if [[ "${template_disp}" == True ]]; then
        _verbose "VM template is a disposable template, cloning it instead"
        web.client.clone "${1}" "${template}" "${netvm}" "${label}"
        return
    fi

    # Generate the VM
    _run qvm-create "${web}" --property netvm="$netvm" --label="$label" --template="$template"
    print_new_qube "${web}" "New client browser VM"

    if [[ $? -gt 0 ]]; then
        _warning "Failed to create browser VM $web" && return
    fi

    # Mark this VM as a disposable template, and tag it with our identity
    if [[ "${template_disp}" != True ]]; then
        qvm-prefs "${web}" template_for_dispvms True
    fi

    _run qvm-tags "$web" set "$IDENTITY"
    identity.config_set BROWSER_QUBE "${web}"
}

# web.client.clone clones a web browsing VM from an existing AppVM one.
function web.client.clone ()
{
    local web="${1}-web"
    local web_clone="$2"
    local netvm="${3-$(identity.config_get NETVM_QUBE)}"
    local label="${4-orange}"

    _run qvm-clone "${web_clone}" "${web}"
    if [[ $? -gt 0 ]] ; then
        _warning "Failed to clone browser VM $web" && return
    fi
    print_cloned_qube "${web}" "${web_clone}" "New client browser VM"

    _run qvm-prefs "$web" label "$label"
    _run qvm-prefs "$web" netvm "$netvm"

    # Only mark this VM as disposable template when it's not one already.
    if [[ "$(qvm-prefs "${web}" template_for_dispvms 2>/dev/null)" == False ]]; then
        _run qvm-prefs "${web}" template_for_dispvms True
    fi

    _run qvm-tags "$web" set "$IDENTITY"
    identity.config_set BROWSER_QUBE "${web}"
}

# web.client.skip returns 0 when there not enough information in the configuration
# file or in command flags for creating a new browser qube (no templates/clones 
# indicated, etc).
# Needs access to command-line flags
function web.client.skip ()
{
    local template clone netvm

    # Check qubes specified in config or flags.
    template="$(config_get WHONIX_WS_TEMPLATE)"
    [[ -n "${args['--clone-web-from']}" ]] && clone="${args['--clone-web-from']}"

    [[ -z ${template} && -z ${clone} ]] && \
        _info "Skipping browser qube: no TemplateVM/AppVM specified in config or flags" && return 0
}

# web.client.fail_invalid_config exits the program if risk lacks some information
# (which templates/clones to use) when attempting to create a browser qube.
function web.client.fail_invalid_config ()
{
    local template clone netvm

    # Check qubes specified in config or flags.
    template="$(config_get WHONIX_WS_TEMPLATE)"
    [[ -n "${args['--clone-web-from']}" ]] && clone="${args['--clone-web-from']}"

    # Check those qubes exist
    if [[ -n ${clone} ]]; then
        ! qube.exists "${clone}" && _failure "Qube to clone ${clone} does not exist"
    else
        ! qube.exists "${template}" && _failure "Qube template ${template} does not exist"
    fi
}

# web.client.update_tor_browser finds the active identity's browser qube template,
# or if not existing, the globally configured whonix workstation, and updates
# the Tor browser in it.
# Requires an identity to be active.
function web.client.update_tor_browser ()
{
    local browser_vm browser_template running

    # Either the identity browser, of the global config one, or return.
    browser_vm="$(identity.browser_qube)"
    [[ -z "${browser_vm}" ]] && browser_vm="$(config_get WHONIX_WS)"
    [[ -z "${browser_vm}" ]] && return

    # Get the template
    browser_template="$(qube.root_template "${browser_vm}")"

    _warning "Updating Tor browser in ${browser_template}"
    qube.is_running "${browser_template}"
    running=$?

    # Run the update and optionally shut it down if it was before.
    _run_qube_term "${browser_template}" sudo update-torbrowser
    [[ ${running} -eq 1 ]] && qube.shutdown "${browser_template}"
}

# web.client.open_url attempts to a URL with the system browser of a qube.
# $1 - URL to open.
# $2 - Target qube.
function web.client.open_url ()
{
    local url="$1"
    local qube="$2"

    _info "Opening ${url} in ${qube}"
    _run qvm-run "${qube}" "x-www-browser ${url}" &
}


# ========================================================================================
# Backend browser qubes (split-browser) 
# ========================================================================================

# web.backend.create creates a split-browser backend qube from a template.
function web.backend.create ()
{
    local web web_label split_template

    web="${1}-split-web"
    web_label="${2-gray}"
    split_template="$(config_get SPLIT_BROWSER_TEMPLATE)"

    qvm-create --property netvm=None --label "$web_label" --template "$split_template"
    print_new_qube "${web}" "New split-browser backend"

    # Once created, set the configuration with this qube.
    config_set SPLIT_BROWSER "${web}"

    # And write the required qrexec services.
    echo && _info "Writing split-bookmark RPC services/policies"
    web.backend.setup_policy "${web}"
    web.backend.setup_policy_dom0 "${web}"
}

# web.backend.clone clones an existing split-browser backend qube.
function web.backend.clone ()
{
    local web="${1}-split-web"
    local web_clone="$2"
    local web_label="${3-gray}"

    qvm-clone "${web_clone}" "${web}"
    qvm-prefs "$web" label "$web_label"
    qvm-prefs "$web" netvm None

    print_cloned_qube "${web}" "${web_clone}" "New split-browser backend"

    # Once created, set the configuration with this qube.
    config_set SPLIT_BROWSER "${web}"

    # And write the required qrexec services.
    echo && _info "Writing split-bookmark RPC services/policies"
    web.backend.setup_policy "${web}"
    web.backend.setup_policy_dom0 "${web}"
}

# web.backend.skip returns 0 when there not enough information in the configuration
# file or in command flags for creating a new split-browser backend qube (no templates
# or clones indicated, etc).
# Needs access to command-line flags
function web.backend.skip ()
{
    [[ ${args['--no-split-browser']} -eq 1 ]] && return 0

    local template clone

    template="$(config_get SPLIT_BROWSER_TEMPLATE)"
    clone="$(config_get SPLIT_BROWSER)"

    [[ -z ${template} && -z ${clone} ]] && \
        _info "Skipping split-browser backend: no TemplateVM/AppVM specified in config" && return 0

    [[ -n ${clone} ]] && return 0

    return 1
}

# web.backend.fail_invalid_config exits the program if risk lacks some information
# (which templates/clones to use) when attempting to create a split-browser qube.
function web.backend.fail_invalid_config ()
{
    local template clone

}

# web.backend.setup_policy writes two RPC policy scripts to the split-browser backend, that 
# are used either to read the bookmarks file from vault, or send it back and delete it.
# $1 - split-browser backend qube name.
function web.backend.setup_policy ()
{
    local vm="$1"

    # Prepare the script to write as the backend qrexec service.
    read -r -d '' QREXEC_SPLIT_BOOKMARK_BACKUP <<'EOF'
#!/bin/sh
bookmarks_split_file="/home/user/.local/share/split-browser/bookmarks.tsv"

# Print the bookmarks file or return
[[ -e "${bookmarks_split_file}" ]] || return
cat "${bookmarks_split_file}"

# And delete it
shred -uzf "${bookmarks_split_file}"
EOF
    
    # Write the script to the target path and make it executable.
    local qrexec_backup_path="/usr/local/etc/qubes-rpc/risk.SplitBookmarkBackup"
    qvm-run -q "${vm}" "echo '${QREXEC_SPLIT_BOOKMARK_BACKUP}' | sudo tee ${qrexec_backup_path}"
    [[ $? -ne 0 ]] && _warning "Failed to write risk.SplitBookmarkBackup policy to ${vm}"
    qvm-run -q "${vm}" "sudo chmod +x ${qrexec_backup_path}"

    # Prepare the second script, which will read that same file from the vault.
    read -r -d '' QREXEC_SPLIT_BOOKMARK <<'EOF'
#!/bin/sh
bookmarks_split_file="/home/user/.local/share/split-browser/bookmarks.tsv"
# Read the bookmarks file contents.
while IFS= read -r bookmark; do
    echo "${bookmark}" >> "${bookmarks_split_file}"
done
EOF

    # Write the script
    local qrexec_path="/usr/local/etc/qubes-rpc/risk.SplitBookmark"
    qvm-run -q "${vm}" "echo '${QREXEC_SPLIT_BOOKMARK}' | sudo tee ${qrexec_path}"
    [[ $? -ne 0 ]] && _warning "Failed to write risk.SplitBookmark policy to ${vm}"
    qvm-run -q "${vm}" "sudo chmod +x ${qrexec_path}"
}

# web.backend.setup_policy_dom0 creates two RPC policy files in Dom0, which are used to
# allow the vault qube to copy/read and delete the bookmarks file in the split-backend qube.
# $1 - split-browser backend qube name.
function web.backend.setup_policy_dom0 ()
{
    local split_backend="$1"

    # Echo both permission lines to their appropriate policy files.
    local bookmarks_policy="${VAULT_VM}    ${split_backend}    allow"

    _info "Writing split-bookmark policies to dom0"

    local split_bookmark_policy_path="/etc/qubes-rpc/policy/risk.SplitBookmark"
    local split_bookmark_backup_policy_path="/etc/qubes-rpc/policy/risk.SplitBookmarkBackup"

    if ! grep "${bookmarks_policy}" "${split_bookmark_policy_path}" &>/dev/null; then
        echo "${bookmarks_policy}" | sudo tee -a "${split_bookmark_policy_path}" &>/dev/null
    fi

    if ! grep "${bookmarks_policy}" "${split_bookmark_backup_policy_path}" &>/dev/null; then
        echo "${bookmarks_policy}" | sudo tee -a "${split_bookmark_backup_policy_path}" &>/dev/null
    fi
}

# web.backend.set_client updates the default disposable VM
# used by the split backend to use the active identity's one.
function web.backend.set_client ()
{
    local browser_vm split_backend filename copy_command

    # Set browser qubes
    split_backend="$(config_get SPLIT_BROWSER)"
    browser_vm=$(identity.config_get BROWSER_QUBE)

    [[ -z "${browser_vm}" ]] && return

    # Use this browser as the split dispVM
    _info "Setting split-browser: $browser_vm"
    qvm-prefs "${split_backend}" default_dispvm "${browser_vm}"

    # And copy identity bookmarks. 
    web.backend.read_bookmarks "${split_backend}"
}

# web.backend.unset_client removes the dispvm setting of the
# tor split backend if it is set to the identity browser VM.
function web.backend.unset_client ()
{
    local browser_vm split_backend filename backup_command

    browser_vm=$(identity.config_get BROWSER_QUBE)
    split_backend="$(config_get SPLIT_BROWSER)"

    [[ -z "${browser_vm}" ]] && return

    # Unset the browser as the split-backend dispVM
    if [[ "$(qvm-prefs "${split_backend}" default_dispvm)" == "${browser_vm}" ]]; then
        qvm-prefs "${split_backend}" default_dispvm ''
    fi

    # And backup the bookmarks file. 
    web.backend.save_bookmarks "${split_backend}"
}

# web.backend.open_url attempts to open a URL with the split-browser backend.
function web.backend.open_url ()
{
    local url="$1"
    local qube
    qube="$(config_get SPLIT_BROWSER)"

    _info "Opening ${url} in ${qube}"
    _run qvm-run "${qube}" "split-browser ${url}" &
}

# web.backend.save_bookmarks asks the vault qube to make use of an RPC 
# call to read the bookmarks file from the split backend and save it. 
# The split-browser backend then deletes the bookmark file.
function web.backend.save_bookmarks ()
{
    local split_backend="$1"
    local bookmarks_split_file bookmarks_file

    # Prepare the encrypted bookmark filename
    filename="$(crypt.filename "bookmarks.tsv")"
    bookmarks_file="/home/user/.tomb/mgmt/${filename}"

    # Test for the file, and if not empty, otherwise
    # we risk doing dangerous and unwanted things.
    bookmarks="$(qvm-run --pass-io "${split_backend}" "cat ${bookmarks_split_file}")"
    if [[ $? -ne 0 ]] || [[ -z "${bookmarks}" ]] ; then
         return
    fi

    _info "Backing up bookmarks"
    backup_command="qrexec-client-vm ${split_backend} risk.SplitBookmarkBackup > ${bookmarks_file}"
    qvm-run -q "${VAULT_VM}" "${backup_command}"
    [[ $? -ne 0 ]] && _warning "Failed to backup bookmarks"
}

# web.backend.read_bookmarks asks the vault to make use of an RPC call 
# to send the identity's bookmarks file to the split-backend qube.
function web.backend.read_bookmarks ()
{
    local split_backend="$1"

    # Prepare the encrypted bookmark filename
    filename="$(crypt.filename "bookmarks.tsv")"
    local bookmarks_file="/home/user/.tomb/mgmt/${filename}"

    _info "Copying bookmarks"
    copy_command="cat ${bookmarks_file} | qrexec-client-vm ${split_backend} risk.SplitBookmark"
    qvm-run -q "${VAULT_VM}" "${copy_command}"
    [[ $? -ne 0 ]] && _warning "Failed to send bookmarks"

}


# ========================================================================================
# Bookmarks management 
# ========================================================================================

# Command to spawn split-browser dmenu with bookmarks, and select one (written to file '~/bookmark').
# shellcheck disable=2016
SPLIT_BROWSER_QUERY_COMMAND='export SB_CMD_INPUT=bookmark; touch $SB_CMD_INPUT; split-browser-bookmark get'

# web.bookmark.create_user_file writes a file to store per-user 
# bookmarks, and obfuscates its name. If the file already exists, 
# nothing will happen (except modified touch timestamp).
function web.bookmark.create_user_file ()
{
    local filename bookmarks_path

    filename="$(crypt.filename "bookmarks.tsv")"
    bookmarks_path="/home/user/.tomb/mgmt/${filename}"
    _run_exec "$VAULT_VM" "touch ${bookmarks_path}"
}

# web.bookmark.file_is_empty returns 0 if no bookmark
# file exists in split-browser or if it is empty.
function web.bookmark.file_is_empty ()
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

# web.bookmark.prompt_command returns a command string
# to use as the dmenu displayer of a bookmarks file.
function web.bookmark.prompt_command ()
{
    # This command will not work if qubes-split-browser is not installed in the split-browser VM
    local window_focus_command='_NET_WM_NAME="Split Browser" x11-unoverride-redirect stdbuf -oL'

    if [[ -n "$(config_get BOOKMARKS_DMENU_COMMAND)" ]]; then
        echo "${window_focus_command} $(config_get BOOKMARKS_DMENU_COMMAND)"
    else
        echo "${window_focus_command} dmenu -i -l 20 -b -p 'RISKS Bookmark'"
    fi
}

# web.bookmark.prompt_select prompts the user with bookmarks,
# and returns the URL extracted from the selection.
function web.bookmark.prompt_select ()
{
    # bookmark_prompt=( $(web.bookmark.prompt_command) )
    qvm-run "${vm}" "${SPLIT_BROWSER_QUERY_COMMAND}"
    qvm-run --pass-io "${vm}" cat bookmark | awk '{print $2}'
}

# web.bookmark.prompt_pop prompts the user with bookmarks, returns the URL
# extracted from the selection and deletes the line in the file.
# Returns the complete bookmark entry.
function web.bookmark.prompt_pop ()
{
    local result bookmark_line vm
    bookmark_file=".local/share/split-browser/bookmarks.tsv"
    vm="$(config_get SPLIT_BROWSER)"

    # Get the URL
    qvm-run "${vm}" "${SPLIT_BROWSER_QUERY_COMMAND}"
    result=$( qvm-run --pass-io "${vm}" cat bookmark | awk '{print $2}')
    qvm-run "${vm}" "rm bookmark"

    # Get the entire line, with the title and timestamp.
    bookmark_line="$(qvm-run --pass-io "${vm}" "cat ${bookmark_file}")"
    line="$(echo "${bookmark_line}" | grep "${result}")"

    # Abort if the user did not select anything
    [[ -z "${result}" ]] && return

    # Remove the line from the file.
    remove_command="sed -i '\#${result}#d' .local/share/split-browser/bookmarks.tsv"
    qvm-run "${vm}" "${remove_command}"

    print "${line}"
}

# web.bookmark.prompt_create opens a zenity prompt in the focused 
# qube for the user to enter a URL and an optional page title.
function web.bookmark.prompt_create ()
{
    local zenity_prompt result active_vm
    active_vm="$(qubes.focused_qube)"

    zenity_prompt="zenity --text 'URL Bookmark' --forms --add-entry='URL' --add-entry='Page Title' --separator=\$'\t'"
    qvm-run --pass-io "${active_vm}" "${zenity_prompt}"
}

# web.bookmark.url_bookmarked returns 0 if the bookmark 
# is found in the user bookmarks file, or 1 if not.
# $1 - Bookmark URL path.
function web.bookmark.url_bookmarked ()
{
    local url="${1}"

    qvm-run --pass-io "${VAULT_VM}" "cat ${IDENTITY_BOOKMARKS_FILE} | grep ${url}" &>/dev/null
}

# web.bookmark.url_save writes a bookmark in split-browser 
# format to the identity's bookmarks file.
# $1 - Bookmark entry
function web.bookmark.url_save ()
{
    local bookmark_entry="$1"
    qvm-run --pass-io "${VAULT_VM}" "echo '${bookmark_entry}' >> ${IDENTITY_BOOKMARKS_FILE}"
}



# ========================================================================================
# Other functions 
# ========================================================================================


# web.bookmark_create_system writes and encrypts a file for blacklisted links.
function web.blacklist_create_file ()
{
    echo
}

# web.no_split_backend returns 0 if there is no split-browser backend 
# qube specified in the configuration/flags, or 1 if one is found.
function web.no_split_backend ()
{
    echo -n
}
