
local url               # URL link to open
local split_vm          # The split-browser backend qube.
local active_vm         # Qube of the focused window.

identity.set

url="${args['url']}"
split_vm="$(config_get SPLIT_BROWSER)"
active_vm="$(qubes.focused_qube)"

# Get the bookmark entry from either split-browser file, args, or user-input in prompt.
if [[ -z "${url}" ]]; then
    if ! web.bookmarks_file_is_empty; then
        _info "No URL argument, starting dmenu with bookmarks list in ${split_vm}"
        url="$( web.bookmark_select | awk '{print $2}' )"
    else
        _info "Bookmark file is empty, and no URL argument was given." && return
    fi
fi

# We either have an entry, or some information to build one, otherwise abort.
if [[ -z "${url}" ]]; then
    _info "No bookmark entry or URL selected or entered, aborting." && return
fi

# And open the link in the appropriate qube.
# If the focused VM is a disposable browser, do not go through split-browser to open it.
# Else, pass the URL as a split-browser command argument.
if qube.is_browser_instance "${active_vm}"; then
    web.bookmark_open_in "${url}" "${active_vm}"
else
    web.bookmark_open_split "${url}"
fi
