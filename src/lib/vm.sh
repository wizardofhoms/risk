
# Returns the name of the identity to which a VM belongs.
get_vm_owner ()
{
    print "$(qvm-tags "$1" "$RISK_VM_OWNER_TAG" 2>/dev/null)"
}

# Enables a VM to autostart
enable_vm_autostart ()
{
    local name="$1"
    local autostart_vms=( "$(_identity_autostart_vms)" )

    # Check if the VM is already marked autostart
    for vm in "${autostart_vms[@]}" ; do
        if [[ $vm == "$name" ]]; then
            already_enabled=true
        fi
    done

    if [[ ! $already_enabled ]]; then
        _message "Enabling VM ${name} to autostart"
        echo "$name" >> "${IDENTITY_DIR}/autostart_vms"
    else
        _message "VM ${name} is already enabled"
    fi
}

# Disables a VM to autostart
disable_vm_autostart ()
{
    local name="$1"
    _message "Disabling VM $name"
    sed -i /"$name"/d "${IDENTITY_DIR}/autostart_vms"
}
