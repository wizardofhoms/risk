
# Create a web browsing VM from a template
create_browser_vm ()
{
    local web="${1}-web"
    local netvm="${2-$(config_get DEFAULT_NETVM)}"
    local web_label="${3-orange}"
    local ws_template="$(config_get WHONIX_WS_TEMPLATE)"
    local template_disp="$(qvm-prefs "${ws_template}" template_for_dispvms)"
    local class

    # Disposable settings
    # If the template used is a disposable_template,
    # this means we must create a named disposable VM.
    [[ "${template_disp}" == True ]] && class=(--class DispVM)
    
    # Generate the VM, regardess of it being a named disposable or not.
    _info "Creating web browsing VM (name: $web / netvm: $netvm / template: $ws_template)"
    qvm-create --property netvm="$netvm" --label "$web_label" --template "$ws_template" "${class[@]}"
    [[ ! $? -eq 0 ]] && _warning "Failed to create browser VM $web"

    # Mark this VM as a disposable template, and tag it with our identity
    [[ "${template_disp}" == False ]] || qvm-prefs "${web}" template_for_dispvms True

    qvm-tags "$web" set "$IDENTITY"
}

# Clone a web browsing VM from an existing one
clone_browser_vm ()
{
    local web="${1}-web"
    local web_clone="$2"
    local netvm="${3-$(config_get DEFAULT_NETVM)}"
    local web_label="${4-orange}"

    _info "Cloning web browsing VM (name: $web / netvm: $netvm / template: $web_clone)"
    qvm-clone "${web_clone}" "${web}"
    [[ ! $? -eq 0 ]] && _warning "Failed to clone browser VM $web" && return

    qvm-prefs "$web" label "$web_label"
    qvm-prefs "$web" netvm "$netvm"

    # Only mark this VM as disposable template when it's not one already.
    [[ "$(qvm-prefs "${ws_template}" template_for_dispvms)" == False ]] \
        && qvm-prefs "${web}" template_for_dispvms True
    
    qvm-tags "$web" set "$IDENTITY"
}

# Create a split-browser VM from a template
create_split_browser_vm ()
{
    local web="${1}-split-web"
    local web_label="${2-gray}"
    local split_template="$(config_get SPLIT_BROWSER_TEMPLATE)"

    _info "Creating split-browser (name: $web / netvm: $netvm / template: $split_template)"
    qvm-create --property netvm=None --label "$web_label" --template "$split_template"

    qvm-tags "$web" set "$IDENTITY"
}

# Clone an existing split-browser VM, and change its dispvms
clone_split_browser_vm ()
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

# create_bookmark_system_file writes and encrypts a file to store all-users bookmarks.
create_bookmark_system_file ()
{
    local filename="bookmarks.tsv"

    # A hush device should be mounted.
    
    # If the file exists, return
    
    # Ask for a password to use, or generate a random seed to use for the encryption.
    
    # Get an encrypted name for the file.
    
    # And create it.
}

# create_bookmark_system_file writes and encrypts a file to store per-user bookmarks.
create_bookmark_user_file ()
{
    local filename="$(encrypt_filename "bookmarks.tsv")"
    bookmarks_path="/home/user/.tomb/mgmt/${filename}"
    _qvrun "$VAULT_VM" "touch ${bookmarks_path}"
}

# create_bookmark_system_file writes and encrypts a file for blacklisted links.
create_links_blacklist_file ()
{
    echo
}

# bookmark_system_file_exists returns 0 if the file exists, or 1.
bookmark_system_file_exists ()
{
    echo
    # _qvrun "$VAULT" "ls /home/user/.graveyard/$encrypted_identity"
}

# bookmark_display_command returns a command string 
# to use as the dmenu displayer of a bookmarks file.
bookmark_display_command ()
{
    # This command will not work if qubes-split-browser is not installed in the split-browser VM 
    local window_focus_command='_NET_WM_NAME="Split Browser" x11-unoverride-redirect stdbuf -oL' 

    if [[ -n "$(config_get BOOKMARKS_DMENU_COMMAND)" ]]; then
        echo "${window_focus_command} $(config_get BOOKMARKS_DMENU_COMMAND)"
    else
        echo "${window_focus_command} dmenu -i -l 20 -b -p 'RISKS Bookmark'"
    fi
}

# split_bookmark_file_is_empty returns 0 if no bookmark 
# file exists in split-browser or if it is empty.
split_bookmark_file_is_empty ()
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
