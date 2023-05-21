
local bookmark_entry    # Complete entry (date/url/title)
local url               # The URL to bookmark
local title             # The URL page title to use if/when prompting the user for input.
local split_vm          # The split-browser backend qube.

identity.set

url="${args['url']}"
title="${args['title']}"
split_vm="$(config_get SPLIT_BROWSER)"

# Get the bookmark entry from either split-browser file, args, or user-input in prompt.
if [[ -z "${url}" ]]; then
    if web.bookmark.file_is_empty; then
        _info "No bookmarks file in ${split_vm}, prompting user to enter it."
        result="$(web.bookmark.prompt_create)"
        url="$( echo "${result}" | cut -f 1 -d $'\t')"
        title="$( echo "${result}" | cut -f 2- -d $'\t')"
    # else
    #     _info "No URL argument, starting dmenu with bookmarks list in ${split_vm}"
    #     bookmark_entry="$(web.bookmark.prompt_pop)"
    #     url="$( echo "${bookmark_entry}" | awk '{print $2}' )"
    #     title="$( echo "${bookmark_entry}" | awk '{print $3}' )"
    fi
fi

# We either have an entry, or some information to build one, otherwise abort.
if [[ -z "${bookmark_entry}" ]] ; then
    if [[ -z "${url}" ]]; then
        _info "No bookmark entry or URL selected or entered, aborting." && return
    fi
    bookmark_entry="$(date --rfc-3339=seconds)"$'\t'"$url"$'\t'"$title"
fi

# Transfer the results to the vault's user bookmarks file.
_info "Transfering entry to vault bookmarks file."
if ! web.bookmark.url_bookmarked "${url}" ; then
    web.bookmark.url_save "${bookmark_entry}"
fi
