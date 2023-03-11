
local active_vm         # The VM owning the focused window
local bookmark_entry    # Complete entry (date/url/title)
local url               # The URL to bookmark
local title             # The URL page title to use if/when prompting the user for input.

identity.set ""

url="${args['url']}"
split_vm="$(config_get SPLIT_BROWSER)"
active_vm="$(_vm_focused)"

## 1 - Get the bookmark entry from either split-browser file, args, or user-input in prompt.
if [[ -z "${url}" ]]; then
    if _web_bookmarks_empty; then
        _info "No bookmarks file in ${split_vm}, prompting user to enter it."
        zenity_prompt="zenity --text 'URL Bookmark' --forms --add-entry='URL' --add-entry='Page Title' --separator=\$'\t'"
        result="$(qvm-run --pass-io "${active_vm}" "${zenity_prompt}")"
        url="$( echo "${result}" | cut -f 1 -d $'\t')"
        title="$( echo "${result}" | cut -f 2- -d $'\t')"
    else
        _info "No URL argument, starting dmenu with bookmarks list in ${split_vm}"
        bookmark_entry="$(web_pop_identity_bookmark)"
        url="$( echo "${bookmark_entry}" | awk '{print $2}' )"
        title="$( echo "${bookmark_entry}" | awk '{print $3}' )"
    fi
fi

# We either have an entry, or some information to build one, otherwise abort.
if [[ -z "${bookmark_entry}" ]] ; then
    if [[ -z "${url}" ]]; then
        _info "No bookmark entry or URL selected or entered, aborting." && return
    fi
    bookmark_entry="$(date --rfc-3339=seconds)"$'\t'"$url"$'\t'"$title"
fi

## 2 - Transfer the results to the vault's user bookmarks file.
_info "Transfering entry to vault bookmarks file."
bookmarks_path="/home/user/.tomb/mgmt/$(_encrypt_filename 'bookmarks.tsv')"

if ! qvm-run --pass-io "${VAULT_VM}" "cat ${bookmarks_path} | grep ${url}" &>/dev/null; then
# grep -m 1 -F -- \$'\t'${url}\$'\t'"
    qvm-run --pass-io "${VAULT_VM}" "echo '${bookmark_entry}' >> ${bookmarks_path}"
fi
