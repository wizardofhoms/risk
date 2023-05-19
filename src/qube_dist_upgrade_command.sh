
local vm version
local template dist running

vm="${args['vm']}"
version="${args['version']}"

# Determine if the VM is a Fedora or Debian,
# and fail if the distribution fits with the provided argument.
template="$(qube.root_template "${vm}")"
running="$(qube.assert_running "${template}")"
dist="$(qube.distribution "${template}")"

if [[ "${dist}" != "fedora" ]] && [[ "${dist}" != "debian" ]]; then
    _failure "Distribution upgrade currently not supported for ${dist} qubes."
elif [[ ! "${version}" =~ ^[0-9]+$ ]] && [[ ${dist} == "fedora" ]] ; then
    _failure "Template is Fedora linux, but got non-number version ${version}."
elif [[ "${version}" =~ ^[0-9]+$ ]] && [[ ${dist} != "fedora" ]] ; then
    _failure "Template is ${dist} linux, but got number version ${version}."
fi

# Start updating
if [[ "${template}" == "${vm}" ]]; then
    _info "Trying to upgrade ${vm}"
else
    _info "Trying to upgrade ${template} (template for ${vm})"
fi

_warning "You might be prompted for confirmations to import repo keys:"
_warning "Please attend the upgrade process."

qube.dist_upgrade "${template}" "${dist}" "${version}"

_info "Done upgrading."

if ! ${running}; then
    _info "Shutting down qube"
    qube.shutdown "${template}"
fi
